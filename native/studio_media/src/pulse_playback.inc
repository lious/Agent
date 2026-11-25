// Local PulseAudio asynchronous service adapter. No wall-clock interpolation or
// submitted-sample clock. Own mainloop thread; fixed ring and bounded server
// queue.
struct PulsePlayback {
  static constexpr size_t ring_frames = 8192;
  J recipe;
  std::atomic<bool> paused{false}, stopping{false};
  std::thread worker;
  std::mutex snapshot_mutex;
  J snapshot;
  int fd = -1;
  int64_t total = 0, base = 0, read_frames = 0, submitted = 0, presented = 0;
  uint64_t epoch, updates = 0, underflows = 0, latency_usec = 0;
  bool latency_valid = false, latency_negative = false;
  size_t head = 0, size = 0, high = 0;
  std::array<float, ring_frames * 2> ring{};
  pa_mainloop *loop = nullptr;
  pa_context *context = nullptr;
  pa_stream *stream = nullptr;
  std::chrono::steady_clock::time_point last_timing{}, cork_started{};
  bool timing_valid = false, cork_pending = false, drain_pending = false,
       drained = false;
  std::string fault, actual_sink;
  explicit PulsePlayback(const J &r, uint64_t gen) : recipe(r), epoch(gen) {
    if (!r.at("sampleCount").is_number_integer() ||
        (r.contains("startSample") && !r["startSample"].is_number_integer()))
      throw Error("PLAYBACK_RANGE");
    const auto path = r.at("path").get<std::string>();
    total = r.at("sampleCount").get<int64_t>();
    base = r.value("startSample", int64_t{0});
    if (total < 1 || total > 120 * 48000 || base < 0 || base >= total)
      throw Error("PLAYBACK_RANGE");
    auto sink = r.value("sink", std::string{});
    if (sink.size() > 128 ||
        sink.find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTU"
                               "VWXYZ0123456789._-") != std::string::npos)
      throw Error("AUDIO_SINK_NAME");
    if (!std::filesystem::path(path).is_absolute())
      throw Error("LOCAL_FILE_REQUIRED");
    paused.store(r.value("paused", false));
    presented = base;
    snapshot = {{"state", "connecting"},
                {"epoch", epoch},
                {"presentedSample", base},
                {"clockValid", false}};
    fd = ::open(path.c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    struct stat st {};
    if (fd < 0 || fstat(fd, &st) || !S_ISREG(st.st_mode) ||
        st.st_size != total * 8) {
      if (fd >= 0)
        ::close(fd);
      throw Error("PLAYBACK_PCM_FILE");
    }
    try {
      worker = std::thread([this] { run(); });
    } catch (...) {
      ::close(fd);
      throw;
    }
  }
  ~PulsePlayback() {
    stopping.store(true);
    if (worker.joinable())
      worker.join();
    if (fd >= 0)
      ::close(fd);
  }
  J status() {
    std::lock_guard guard(snapshot_mutex);
    return snapshot;
  }
  void publish(const std::string &state) {
    const auto *attr = stream ? pa_stream_get_buffer_attr(stream) : nullptr;
    J j = {{"state", state},
           {"epoch", epoch},
           {"presentedSample", presented},
           {"sampleCount", total},
           {"submittedSamples", submitted},
           {"baseSample", base},
           {"clockValid", timing_valid},
           {"clockSource", "pulse-service-noninterpolated"},
           {"timingUpdates", updates},
           {"lastServiceLatencyUsec", latency_usec},
           {"serviceLatencyValid", latency_valid},
           {"serviceLatencyNegative", latency_negative},
           {"ringFrames", size},
           {"ringCapacityFrames", ring_frames},
           {"ringHighWaterFrames", high},
           {"serverMaxBytes", attr ? attr->maxlength : 0},
           {"underruns", underflows},
           {"discontinuity", !fault.empty()},
           {"reason", fault},
           {"unconfirmedTailSamples",
            fault.empty() ? 0 : base + submitted - presented},
           {"sink", actual_sink},
           {"physicalPresentationVerified", false}};
    std::lock_guard guard(snapshot_mutex);
    snapshot = std::move(j);
  }
  static void timing(pa_stream *s, int success, void *p) {
    auto &self = *static_cast<PulsePlayback *>(p);
    pa_usec_t us = 0;
    const auto *info = pa_stream_get_timing_info(s);
    if (!success || !info || info->read_index_corrupt ||
        pa_stream_get_time(s, &us) < 0) {
      self.timing_valid = false;
      return;
    }
    const auto frames = static_cast<int64_t>(us / 1000000) * 48000 +
                        static_cast<int64_t>(us % 1000000) * 48000 / 1000000;
    const auto candidate = self.base + std::min(frames, self.submitted);
    if (candidate < self.presented) {
      self.fault = "clock-discontinuity";
      return;
    }
    int negative = 0;
    pa_usec_t latency = 0;
    self.latency_valid = pa_stream_get_latency(s, &latency, &negative) == 0;
    if (self.latency_valid) {
      self.latency_usec = latency;
      self.latency_negative = negative != 0;
    }
    self.presented = std::min(self.total, candidate);
    self.timing_valid = true;
    self.last_timing = std::chrono::steady_clock::now();
    ++self.updates;
  }
  static void corked(pa_stream *, int success, void *p) {
    auto &s = *static_cast<PulsePlayback *>(p);
    s.cork_pending = false;
    if (!success)
      s.fault = "cork-failed";
  }
  static void drain(pa_stream *, int success, void *p) {
    auto &s = *static_cast<PulsePlayback *>(p);
    if (success)
      s.drained = true;
    else
      s.fault = "drain-failed";
  }
  static void underflow(pa_stream *, void *p) {
    auto &s = *static_cast<PulsePlayback *>(p);
    if (s.base + s.submitted < s.total) {
      ++s.underflows;
      s.fault = "underrun";
    }
  }
  static void suspended(pa_stream *stream, void *p) {
    if (pa_stream_is_suspended(stream) > 0)
      static_cast<PulsePlayback *>(p)->fault = "device-lost";
  }
  static void moved(pa_stream *, void *p) {
    static_cast<PulsePlayback *>(p)->fault = "device-moved";
  }
  void run() noexcept {
    try {
      const char *configured = std::getenv("PULSE_SERVER"),
                 *runtime = std::getenv("XDG_RUNTIME_DIR");
      const std::string server =
          configured ? configured
          : runtime  ? std::string("unix:") + runtime + "/pulse/native"
                     : "";
      if (!server.starts_with("unix:/") ||
          server.find_first_of("\n\r \t;{},") != std::string::npos ||
          server.find(':', 5) != std::string::npos)
        throw Error("LOCAL_AUDIO_SERVICE_REQUIRED");
      loop = pa_mainloop_new();
      if (!loop)
        throw Error("AUDIO_ALLOCATION");
      context =
          pa_context_new(pa_mainloop_get_api(loop), "Studio local timeline");
      if (!context)
        throw Error("AUDIO_ALLOCATION");
      if (pa_context_connect(context, server.c_str(), PA_CONTEXT_NOAUTOSPAWN,
                             nullptr) < 0)
        throw Error("AUDIO_SERVICE_UNAVAILABLE");
      auto deadline =
               std::chrono::steady_clock::now() + std::chrono::seconds(5),
           next_update = std::chrono::steady_clock::now();
      while (!stopping.load()) {
        int rc = 0;
        if (pa_mainloop_iterate(loop, 0, &rc) < 0)
          throw Error("AUDIO_SERVICE_LOST");
        auto cs = pa_context_get_state(context);
        if (!PA_CONTEXT_IS_GOOD(cs))
          throw Error("AUDIO_SERVICE_LOST");
        if (cs == PA_CONTEXT_READY && !stream) {
          pa_sample_spec spec{PA_SAMPLE_FLOAT32LE, 48000, 2};
          stream = pa_stream_new(context, "Timeline PCM", &spec, nullptr);
          if (!stream)
            throw Error("AUDIO_STREAM_CREATE");
          pa_stream_set_underflow_callback(stream, underflow, this);
          pa_stream_set_suspended_callback(stream, suspended, this);
          pa_stream_set_moved_callback(stream, moved, this);
          pa_buffer_attr attr{4096 * 8, 2048 * 8, 1024 * 8, 1024 * 8,
                              static_cast<uint32_t>(-1)};
          const auto sink = recipe.value("sink", std::string{});
          if (pa_stream_connect_playback(
                  stream, sink.empty() ? nullptr : sink.c_str(), &attr,
                  static_cast<pa_stream_flags_t>(
                      PA_STREAM_START_CORKED | PA_STREAM_AUTO_TIMING_UPDATE |
                      PA_STREAM_ADJUST_LATENCY | PA_STREAM_DONT_MOVE),
                  nullptr, nullptr) < 0)
            throw Error("AUDIO_SINK_UNAVAILABLE");
        }
        if (stream && pa_stream_get_state(stream) == PA_STREAM_READY) {
          const auto *attr = pa_stream_get_buffer_attr(stream);
          if (!attr || attr->maxlength > 4096 * 8)
            throw Error("AUDIO_QUEUE_LIMIT");
          auto name = pa_stream_get_device_name(stream);
          if (name)
            actual_sink = name;
          if (!fault.empty())
            throw Error(fault);
          if (updates == 0 && std::chrono::steady_clock::now() > deadline)
            throw Error("CLOCK_TIMING_UNAVAILABLE");
          if (cork_pending && std::chrono::steady_clock::now() - cork_started >
                                  std::chrono::seconds(2))
            throw Error("AUDIO_CORK_TIMEOUT");
          if (updates > 0 && std::chrono::steady_clock::now() - last_timing >
                                 std::chrono::milliseconds(500))
            throw Error("clock-stale");
          if (drained) {
            presented = total;
            timing_valid = true;
            publish("finished");
            break;
          }
          while (size < ring_frames && base + read_frames < total) {
            const size_t tail = (head + size) % ring_frames,
                         n = std::min(
                             {size_t(1024), ring_frames - size,
                              ring_frames - tail,
                              static_cast<size_t>(total - base - read_frames)});
            const auto got = pread(fd, ring.data() + tail * 2, n * 8,
                                   (base + read_frames) * 8);
            if (got != static_cast<ssize_t>(n * 8))
              throw Error("PLAYBACK_PCM_READ");
            for (size_t i = 0; i < n * 2; ++i)
              if (!std::isfinite(ring[tail * 2 + i]))
                throw Error("NONFINITE_PCM");
            read_frames += n;
            size += n;
            high = std::max(high, size);
          }
          for (int batch = 0; batch < 4 && size; batch++) {
            const auto avail = pa_stream_writable_size(stream);
            if (avail == static_cast<size_t>(-1))
              throw Error("AUDIO_WRITE_SIZE");
            const size_t n =
                std::min({size_t(1024), size, ring_frames - head, avail / 8});
            if (!n)
              break;
            if (pa_stream_write(stream, ring.data() + head * 2, n * 8, nullptr,
                                0, PA_SEEK_RELATIVE) < 0)
              throw Error("AUDIO_WRITE");
            head = (head + n) % ring_frames;
            size -= n;
            submitted += n;
          }
          if (!cork_pending &&
              (pa_stream_is_corked(stream) > 0) != paused.load()) {
            cork_pending = true;
            cork_started = std::chrono::steady_clock::now();
            auto *op =
                pa_stream_cork(stream, paused.load() ? 1 : 0, corked, this);
            if (!op)
              throw Error("AUDIO_CORK");
            pa_operation_unref(op);
          }
          if (base + submitted == total && !drain_pending && !paused.load()) {
            drain_pending = true;
            auto *op = pa_stream_drain(stream, drain, this);
            if (!op)
              throw Error("AUDIO_DRAIN");
            pa_operation_unref(op);
          }
          if (std::chrono::steady_clock::now() >= next_update) {
            auto *op = pa_stream_update_timing_info(stream, timing, this);
            if (op)
              pa_operation_unref(op);
            next_update = std::chrono::steady_clock::now() +
                          std::chrono::milliseconds(20);
          }
          publish(cork_pending                      ? "transition"
                  : pa_stream_is_corked(stream) > 0 ? "paused"
                                                    : "playing");
        } else if (stream && !PA_STREAM_IS_GOOD(pa_stream_get_state(stream)))
          throw Error("AUDIO_DEVICE_LOST");
        else if (std::chrono::steady_clock::now() > deadline)
          throw Error("AUDIO_CONNECT_TIMEOUT");
        std::this_thread::sleep_for(std::chrono::milliseconds(
            2)); // Pump scheduling ONLY; never project clock.
      }
    } catch (const std::exception &e) {
      fault = e.what();
      timing_valid = false;
      publish("interrupted");
    }
    if (stream) {
      pa_stream_disconnect(stream);
      pa_stream_unref(stream);
      stream = nullptr;
    }
    if (context) {
      pa_context_disconnect(context);
      pa_context_unref(context);
      context = nullptr;
    }
    if (loop) {
      pa_mainloop_free(loop);
      loop = nullptr;
    }
  }
};
