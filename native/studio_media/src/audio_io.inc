// Included inside the native adapter's anonymous namespace. Linux development
// adapter only. No device presentation clock is inferred from these file
// samples.
struct PcmFile {
  std::string path;
  FILE *file = nullptr;
  bool committed = false;
  explicit PcmFile(const std::string &p) : path(p) {
    if (!std::filesystem::path(p).is_absolute())
      throw Error("LOCAL_FILE_REQUIRED");
    const int fd =
        ::open(p.c_str(), O_CREAT | O_EXCL | O_NOFOLLOW | O_RDWR, 0600);
    if (fd < 0)
      throw Error("PCM_OUTPUT_MUST_BE_NEW");
    file = fdopen(fd, "w+b");
    if (!file) {
      ::close(fd);
      ::unlink(p.c_str());
      throw Error("PCM_OPEN_FAILED");
    }
  }
  ~PcmFile() {
    if (file)
      fclose(file);
    if (!committed)
      ::unlink(path.c_str());
  }
  void write(const float *p, size_t frames) {
    if (fwrite(p, sizeof(float) * 2, frames, file) != frames)
      throw Error("PCM_WRITE_FAILED");
  }
};
J decode_audio(Engine &engine, const J &r) {
  keys(r, {"path", "outputPath", "streamIndex", "startSample", "sampleCount"});
  if (!r["path"].is_string() || !r["outputPath"].is_string())
    throw Error("RECIPE_TYPE");
  const auto count = integer(r, "sampleCount", 1, 48000 * 120);
  const auto requested =
      integer(r, "startSample", -48000LL * 86400, 48000LL * 86400);
  const auto epoch = engine.epoch.load();
  auto check = [&] {
    if (engine.epoch.load() != epoch)
      throw Error("CANCELED");
  };
  Input in;
  in.open(r["path"].get<std::string>());
  const int index = integer(r, "streamIndex", 0, 63);
  if (static_cast<unsigned>(index) >= in.format->nb_streams)
    throw Error("AUDIO_STREAM_REQUIRED");
  auto *st = in.format->streams[index];
  auto *par = st->codecpar;
  if (par->codec_type != AVMEDIA_TYPE_AUDIO)
    throw Error("AUDIO_STREAM_REQUIRED");
  if (par->codec_id != AV_CODEC_ID_AAC &&
      par->codec_id != AV_CODEC_ID_PCM_S16LE &&
      par->codec_id != AV_CODEC_ID_PCM_F32LE &&
      par->codec_id != AV_CODEC_ID_FLAC)
    throw Error("AUDIO_CODEC_NOT_QUALIFIED");
  const AVChannelLayout mono = AV_CHANNEL_LAYOUT_MONO,
                        stereo = AV_CHANNEL_LAYOUT_STEREO;
  // WAV often declares only a count. Standard mono/stereo have an explicit
  // default mapping; never infer/downmix an unspecified surround layout.
  if (par->ch_layout.order == AV_CHANNEL_ORDER_UNSPEC &&
      (par->ch_layout.nb_channels == 1 || par->ch_layout.nb_channels == 2))
    av_channel_layout_default(&par->ch_layout, par->ch_layout.nb_channels);
  if (av_channel_layout_compare(&par->ch_layout, &mono) != 0 &&
      av_channel_layout_compare(&par->ch_layout, &stereo) != 0)
    throw Error("AUDIO_LAYOUT_UNSUPPORTED");
  int64_t stream_start = st->start_time;
  if (stream_start == AV_NOPTS_VALUE &&
      std::string(in.format->iformat->name) == "wav" &&
      (par->codec_id == AV_CODEC_ID_PCM_S16LE ||
       par->codec_id == AV_CODEC_ID_PCM_F32LE))
    stream_start = 0;
  if (stream_start == AV_NOPTS_VALUE || st->duration == AV_NOPTS_VALUE ||
      st->duration <= 0 || st->time_base.num <= 0 || st->time_base.den <= 0)
    throw Error("AUDIO_TIMESTAMP_METADATA_REQUIRED");
  if (par->sample_rate < 8000 || par->sample_rate > 192000)
    throw Error("AUDIO_RATE_UNSUPPORTED");
  if (stream_start > INT64_MAX - st->duration)
    throw Error("AUDIO_TIMESTAMP_RANGE");
  const int64_t content_end =
      av_rescale_q_rnd(stream_start + st->duration, st->time_base,
                       AVRational{1, 48000}, AV_ROUND_NEAR_INF);
  const int64_t content_start = av_rescale_q_rnd(
      stream_start, st->time_base, AVRational{1, 48000}, AV_ROUND_NEAR_INF);
  if (content_start < -48000LL * 86400 || content_start > 48000LL * 86400 ||
      content_end < content_start || content_end > 48000LL * (86400 + 600))
    throw Error("AUDIO_TIMESTAMP_RANGE");
  in.decoder = avcodec_alloc_context3(avcodec_find_decoder(par->codec_id));
  if (!in.decoder)
    throw Error("DECODER_UNAVAILABLE");
  ok(avcodec_parameters_to_context(in.decoder, par));
  in.decoder->pkt_timebase = st->time_base;
  in.decoder->thread_count = 1;
  ok(avcodec_open2(in.decoder, avcodec_find_decoder(par->codec_id), nullptr));
  in.packet = av_packet_alloc();
  if (!in.packet)
    throw Error("OUT_OF_MEMORY");
  auto free_frame = [](AVFrame *p) { av_frame_free(&p); };
  std::unique_ptr<AVFrame, decltype(free_frame)> frame(av_frame_alloc(),
                                                       free_frame);
  if (!frame)
    throw Error("OUT_OF_MEMORY");
  SwrContext *raw_swr = nullptr;
  auto free_swr = [](SwrContext *p) { swr_free(&p); };
  std::unique_ptr<SwrContext, decltype(free_swr)> swr(nullptr, free_swr);
  PcmFile output(r["outputPath"].get<std::string>());
  const float silence[2048] = {};
  for (int64_t n = 0; n < count; n += 1024) {
    check();
    output.write(silence, std::min<int64_t>(1024, count - n));
  }
  int64_t first = AV_NOPTS_VALUE, first_input = 0, input_samples = 0,
          produced = 0, written = 0;
  bool draining = false, ended = false;
  int packets = 0, first_format = -1;
  auto consume = [&](const float *p, int samples) {
    check();
    if (first == AV_NOPTS_VALUE)
      throw Error("AUDIO_EMPTY");
    for (int64_t i = 0; i < static_cast<int64_t>(samples) * 2; ++i)
      if (!std::isfinite(p[i]))
        throw Error("AUDIO_PCM_INVALID");
    const int64_t begin = first + produced,
                  end = std::min<int64_t>(begin + samples, content_end);
    const int64_t a = std::max(begin, requested),
                  b = std::min(end, requested + count);
    if (a < b) {
      if (fseeko(output.file, (a - requested) * 8, SEEK_SET) != 0)
        throw Error("PCM_SEEK_FAILED");
      output.write(p + (a - begin) * 2, b - a);
      written += b - a;
    }
    produced += samples;
    if (produced > 48000LL * 600)
      throw Error("AUDIO_DECODE_WINDOW_LIMIT");
  };
  while (!ended) {
    check();
    const int got = avcodec_receive_frame(in.decoder, frame.get());
    if (got == AVERROR_EOF)
      break;
    if (got == AVERROR(EAGAIN)) {
      if (draining)
        throw Error("AUDIO_DRAIN_PROTOCOL");
      for (;;) {
        check();
        if (++packets > 2000000)
          throw Error("PACKET_LIMIT");
        const int read = av_read_frame(in.format, in.packet);
        if (read == AVERROR_EOF) {
          ok(avcodec_send_packet(in.decoder, nullptr));
          draining = true;
          break;
        }
        ok(read);
        if (in.packet->stream_index == index) {
          const int sent = avcodec_send_packet(in.decoder, in.packet);
          av_packet_unref(in.packet);
          ok(sent);
          break;
        }
        av_packet_unref(in.packet);
      }
      continue;
    }
    ok(got);
    if (frame->ch_layout.order == AV_CHANNEL_ORDER_UNSPEC &&
        (frame->ch_layout.nb_channels == 1 ||
         frame->ch_layout.nb_channels == 2))
      av_channel_layout_default(&frame->ch_layout,
                                frame->ch_layout.nb_channels);
    if (frame->nb_samples < 1 || frame->nb_samples > 65536 ||
        frame->sample_rate != par->sample_rate ||
        av_channel_layout_compare(&frame->ch_layout, &par->ch_layout) != 0)
      throw Error("AUDIO_FORMAT_CHANGED");
    const auto pts = frame->best_effort_timestamp;
    if (pts == AV_NOPTS_VALUE)
      throw Error("AUDIO_MISSING_PTS");
    const auto at = av_rescale_q_rnd(
        pts, st->time_base, AVRational{1, par->sample_rate}, AV_ROUND_NEAR_INF);
    if (at < -static_cast<int64_t>(par->sample_rate) * 86400 ||
        at > static_cast<int64_t>(par->sample_rate) * (86400 + 600))
      throw Error("AUDIO_TIMESTAMP_RANGE");
    if (first == AV_NOPTS_VALUE) {
      first_format = frame->format;
      first = av_rescale_q_rnd(pts, st->time_base, AVRational{1, 48000},
                               AV_ROUND_NEAR_INF);
      first_input = at;
      if (first < -48000LL * 86400 || first > 48000LL * 86400)
        throw Error("AUDIO_TIMESTAMP_RANGE");
      ok(swr_alloc_set_opts2(&raw_swr, &stereo, AV_SAMPLE_FMT_FLT, 48000,
                             &frame->ch_layout,
                             static_cast<AVSampleFormat>(frame->format),
                             frame->sample_rate, 0, nullptr));
      swr.reset(raw_swr);
      ok(swr_init(swr.get()));
    }
    if (frame->format != first_format)
      throw Error("AUDIO_FORMAT_CHANGED");
    if (std::abs(at - first_input - input_samples) > 1)
      throw Error("AUDIO_PTS_DISCONTINUITY");
    input_samples += frame->nb_samples;
    const int capacity = swr_get_out_samples(swr.get(), frame->nb_samples);
    if (capacity < 0 || capacity > 262144)
      throw Error("RESAMPLE_BLOCK_LIMIT");
    std::vector<float> block(static_cast<size_t>(capacity) * 2);
    uint8_t *dst[] = {reinterpret_cast<uint8_t *>(block.data())};
    const int n = swr_convert(
        swr.get(), dst, capacity,
        const_cast<const uint8_t **>(frame->extended_data), frame->nb_samples);
    ok(n);
    consume(block.data(), n);
    av_frame_unref(frame.get());
    if (first + produced >= requested + count)
      ended = true;
  }
  if (!ended && swr) {
    // Drain the real resampler delay, never guess a constant AAC priming count.
    for (int attempts = 0;; ++attempts) {
      check();
      if (attempts > 256)
        throw Error("RESAMPLE_DRAIN_LIMIT");
      float block[8192];
      uint8_t *dst[] = {reinterpret_cast<uint8_t *>(block)};
      const int n = swr_convert(swr.get(), dst, 4096, nullptr, 0);
      ok(n);
      if (n == 0)
        break;
      consume(block, n);
    }
  }
  if (first == AV_NOPTS_VALUE)
    throw Error("AUDIO_EMPTY");
  const auto expected =
      std::max<int64_t>(0, std::min(content_end, requested + count) -
                               std::max(content_start, requested));
  if (written != expected)
    throw Error("AUDIO_TRUNCATED");
  if (fflush(output.file) != 0)
    throw Error("PCM_WRITE_FAILED");
  check();
  output.committed = true;
  return J{{"sampleRate", 48000},
           {"channels", 2},
           {"sampleCount", count},
           {"writtenSamples", written},
           {"firstDecodedSample", first},
           {"resampledSamples", produced},
           {"contentEndSample", content_end},
           {"inputSamples", input_samples}};
}
struct AudioEncoder {
  AVFormatContext *format = nullptr;
  AVCodecContext *encoder = nullptr;
  AVStream *stream = nullptr;
  AVFrame *frame = nullptr;
  AVPacket *packet = nullptr;
  std::ifstream pcm;
  int64_t samples = 0, sent = 0;
  std::function<void()> check = [] {};
  ~AudioEncoder() {
    av_packet_free(&packet);
    av_frame_free(&frame);
    avcodec_free_context(&encoder);
  }
  void open(AVFormatContext *f, const J &r) {
    keys(r, {"path", "sampleCount"});
    if (!r["path"].is_string())
      throw Error("RECIPE_TYPE");
    samples = integer(r, "sampleCount", 1, 48000 * 120);
    format = f;
    const auto path = r["path"].get<std::string>();
    local_file(path);
    if (std::filesystem::file_size(path) != static_cast<uint64_t>(samples) * 8)
      throw Error("PCM_LENGTH_MISMATCH");
    pcm.open(path, std::ios::binary);
    if (!pcm)
      throw Error("PCM_OPEN_FAILED");
    const auto *codec = avcodec_find_encoder(AV_CODEC_ID_AAC);
    if (!codec)
      throw Error("AAC_ENCODER_UNAVAILABLE");
    encoder = avcodec_alloc_context3(codec);
    if (!encoder)
      throw Error("OUT_OF_MEMORY");
    encoder->sample_rate = 48000;
    encoder->sample_fmt = AV_SAMPLE_FMT_FLTP;
    encoder->time_base = AVRational{1, 48000};
    encoder->bit_rate = 192000;
    encoder->profile = AV_PROFILE_AAC_LOW;
    const AVChannelLayout layout = AV_CHANNEL_LAYOUT_STEREO;
    ok(av_channel_layout_copy(&encoder->ch_layout, &layout));
    if (format->oformat->flags & AVFMT_GLOBALHEADER)
      encoder->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    ok(avcodec_open2(encoder, codec, nullptr));
    if (encoder->frame_size < 1 || encoder->frame_size > 8192 ||
        !(codec->capabilities & AV_CODEC_CAP_SMALL_LAST_FRAME))
      throw Error("AAC_FRAME_POLICY_UNSUPPORTED");
    stream = avformat_new_stream(format, nullptr);
    if (!stream)
      throw Error("OUT_OF_MEMORY");
    stream->time_base = encoder->time_base;
    ok(avcodec_parameters_from_context(stream->codecpar, encoder));
    frame = av_frame_alloc();
    packet = av_packet_alloc();
    if (!frame || !packet)
      throw Error("OUT_OF_MEMORY");
    frame->format = encoder->sample_fmt;
    frame->sample_rate = 48000;
    frame->nb_samples = encoder->frame_size;
    ok(av_channel_layout_copy(&frame->ch_layout, &layout));
    ok(av_frame_get_buffer(frame, 0));
  }
  void drain() {
    for (;;) {
      check();
      const int got = avcodec_receive_packet(encoder, packet);
      if (got == AVERROR_EOF || got == AVERROR(EAGAIN))
        return;
      ok(got);
      av_packet_rescale_ts(packet, encoder->time_base, stream->time_base);
      packet->stream_index = stream->index;
      const int wrote = av_interleaved_write_frame(format, packet);
      av_packet_unref(packet);
      ok(wrote);
    }
  }
  void until(int64_t end) {
    while (sent < std::min(samples, end)) {
      check();
      ok(av_frame_make_writable(frame));
      const int n = std::min<int64_t>(encoder->frame_size, samples - sent);
      std::vector<float> block(static_cast<size_t>(n) * 2);
      pcm.read(reinterpret_cast<char *>(block.data()), n * 8);
      if (pcm.gcount() != n * 8)
        throw Error("PCM_READ_FAILED");
      for (int i = 0; i < n; ++i)
        for (int c = 0; c < 2; ++c) {
          const auto v = block[i * 2 + c];
          if (!std::isfinite(v))
            throw Error("AUDIO_PCM_INVALID");
          reinterpret_cast<float *>(frame->data[c])[i] = v;
        }
      frame->nb_samples = n;
      frame->pts = sent;
      ok(avcodec_send_frame(encoder, frame));
      sent += n;
      drain();
    }
  }
  void finish() {
    until(samples);
    ok(avcodec_send_frame(encoder, nullptr));
    drain();
  }
};
