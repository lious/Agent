#include "studio_media.h"
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libavutil/pixdesc.h>
#include <libswscale/swscale.h>
}
#include <algorithm>
#include <atomic>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <functional>
#include <limits>
#include <map>
#include <memory>
#include <mutex>
#include <nlohmann/json.hpp>
#include <set>
#include <stdexcept>
#include <string>
#include <vector>
using J = nlohmann::json;
namespace {
struct Error : std::runtime_error {
  using std::runtime_error::runtime_error;
};
void ok(int result) {
  if (result < 0) {
    char message[AV_ERROR_MAX_STRING_SIZE];
    av_strerror(result, message, sizeof(message));
    throw Error(std::string("FFMPEG_ERROR:") + message);
  }
}
char *encode(const J &j) {
  const auto s = j.dump();
  auto *b = static_cast<char *>(std::malloc(s.size() + 1));
  if (!b)
    return nullptr;
  std::memcpy(b, s.c_str(), s.size() + 1);
  return b;
}
template <class F> char *boundary(F action) {
  try {
    return encode(J{{"ok", true}, {"value", action()}});
  } catch (const std::exception &e) {
    return encode(J{{"ok", false}, {"code", e.what()}});
  } catch (...) {
    return encode(J{{"ok", false}, {"code", "NATIVE_EXCEPTION"}});
  }
}
struct Engine {
  std::string ns;
  std::mutex busy;
  std::atomic<uint64_t> epoch{0};
  explicit Engine(std::string n) : ns(std::move(n)) {}
};
std::mutex registry_lock;
std::map<uint64_t, std::shared_ptr<Engine>> engines;
uint64_t next_handle = 1;
std::shared_ptr<Engine> engine(uint64_t id, const char *ns) {
  std::lock_guard guard(registry_lock);
  auto it = engines.find(id);
  if (it == engines.end())
    throw Error("INVALID_HANDLE");
  if (!ns || it->second->ns != ns)
    throw Error("NAMESPACE_MISMATCH");
  return it->second;
}
void local_file(const std::string &path) {
  auto p = std::filesystem::path(path);
  if (!p.is_absolute() || !std::filesystem::is_regular_file(p) ||
      std::filesystem::is_symlink(p))
    throw Error("LOCAL_FILE_REQUIRED");
}
struct Input {
  AVFormatContext *format = nullptr;
  AVCodecContext *decoder = nullptr;
  AVPacket *packet = nullptr;
  AVFrame *current = nullptr;
  AVFrame *next = nullptr;
  int video = -1;
  bool drained = false;
  int packets = 0;
  std::function<void()> check = [] {};
  Input() = default;
  Input(const Input &) = delete;
  Input &operator=(const Input &) = delete;
  ~Input() {
    av_frame_free(&current);
    av_frame_free(&next);
    av_packet_free(&packet);
    avcodec_free_context(&decoder);
    avformat_close_input(&format);
  }
  void open(const std::string &path) {
    local_file(path);
    AVDictionary *options = nullptr;
    av_dict_set(&options, "protocol_whitelist", "file", 0);
    av_dict_set(&options, "format_whitelist",
                "mov,matroska,webm,avi,wav,mp3,flac,ogg", 0);
    av_dict_set(&options, "enable_drefs", "0", 0);
    av_dict_set(&options, "use_absolute_path", "0", 0);
    const int ret = avformat_open_input(&format, ("file:" + path).c_str(),
                                        nullptr, &options);
    av_dict_free(&options);
    ok(ret);
    ok(avformat_find_stream_info(format, nullptr));
    if (format->nb_streams > 64)
      throw Error("STREAM_LIMIT");
    video = av_find_best_stream(format, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
  }
  void prepare() {
    if (video < 0)
      throw Error("VIDEO_STREAM_REQUIRED");
    auto *st = format->streams[video];
    if (st->codecpar->width < 2 || st->codecpar->height < 2 ||
        st->codecpar->width > 8192 || st->codecpar->height > 8192)
      throw Error("FRAME_SIZE_LIMIT");
    const auto *codec = avcodec_find_decoder(st->codecpar->codec_id);
    if (!codec)
      throw Error("DECODER_UNAVAILABLE");
    decoder = avcodec_alloc_context3(codec);
    if (!decoder)
      throw Error("OUT_OF_MEMORY");
    ok(avcodec_parameters_to_context(decoder, st->codecpar));
    decoder->thread_count = 2;
    ok(avcodec_open2(decoder, codec, nullptr));
    packet = av_packet_alloc();
    if (!packet)
      throw Error("OUT_OF_MEMORY");
  }
  AVFrame *decode() {
    auto *frame = av_frame_alloc();
    if (!frame)
      throw Error("OUT_OF_MEMORY");
    try {
      for (;;) {
        check();
        const int r = avcodec_receive_frame(decoder, frame);
        if (r == 0)
          return frame;
        if (r == AVERROR_EOF) {
          av_frame_free(&frame);
          return nullptr;
        }
        if (r != AVERROR(EAGAIN))
          ok(r);
        if (drained)
          throw Error("DECODE_DRAIN_PROTOCOL");
        bool fed = false;
        while (!fed) {
          check();
          if (++packets > 2000000)
            throw Error("PACKET_LIMIT");
          const int result = av_read_frame(format, packet);
          if (result == AVERROR_EOF) {
            ok(avcodec_send_packet(decoder, nullptr));
            drained = true;
            fed = true;
          } else {
            ok(result);
            if (packet->stream_index == video) {
              const int sent = avcodec_send_packet(decoder, packet);
              av_packet_unref(packet);
              ok(sent);
              fed = true;
            } else
              av_packet_unref(packet);
          }
        }
      }
    } catch (...) {
      av_frame_free(&frame);
      throw;
    }
  }
  int64_t pts(const AVFrame *frame) const {
    if (frame->best_effort_timestamp == AV_NOPTS_VALUE)
      throw Error("MISSING_PTS");
    return frame->best_effort_timestamp;
  }
  AVFrame *at(int64_t target) {
    if (!current) {
      current = decode();
      if (!current)
        throw Error("EMPTY_VIDEO");
      if (format->streams[video]->start_time == AV_NOPTS_VALUE ||
          pts(current) != format->streams[video]->start_time)
        throw Error("START_PTS_POLICY_REQUIRED");
      next = decode();
    }
    if (pts(current) > target)
      throw Error("SOURCE_BEFORE_FIRST_FRAME");
    while (next && pts(next) <= target) {
      if (pts(next) <= pts(current))
        throw Error("NON_MONOTONIC_PTS");
      av_frame_free(&current);
      current = next;
      next = decode();
    }
    if (!next) {
      auto duration = current->duration;
      if (duration <= 0) {
        auto fps = av_guess_frame_rate(format, format->streams[video], nullptr);
        if (fps.num > 0 && fps.den > 0)
          duration =
              av_rescale_q(1, av_inv_q(fps), format->streams[video]->time_base);
      }
      if (duration <= 0 ||
          static_cast<__int128>(target) - pts(current) >= duration)
        throw Error("SOURCE_AFTER_LAST_FRAME");
    }
    return current;
  }
};
int64_t integer(const J &v, const char *field, int64_t min, int64_t max) {
  if (!v.contains(field) || !v[field].is_number_integer())
    throw Error("RECIPE_TYPE");
  const auto n = v[field].get<int64_t>();
  if (n < min || n > max)
    throw Error("RECIPE_RANGE");
  return n;
}
void keys(const J &v, std::initializer_list<const char *> names) {
  if (!v.is_object() || v.size() != names.size())
    throw Error("RECIPE_FIELDS");
  for (auto n : names)
    if (!v.contains(n))
      throw Error("RECIPE_FIELDS");
}
J parse_recipe(const char *text) {
  std::vector<std::set<std::string>> objects;
  return J::parse(text, [&](int depth, J::parse_event_t event, J &value) {
    if (depth > 64)
      throw Error("RECIPE_DEPTH_LIMIT");
    if (event == J::parse_event_t::object_start)
      objects.emplace_back();
    if (event == J::parse_event_t::key &&
        !objects.back().insert(value.get<std::string>()).second)
      throw Error("RECIPE_DUPLICATE_KEY");
    if (event == J::parse_event_t::object_end)
      objects.pop_back();
    return true;
  });
}
J probe(Input &in) {
  J streams = J::array();
  for (unsigned i = 0; i < in.format->nb_streams; i++) {
    auto *st = in.format->streams[i];
    auto *p = st->codecpar;
    if (p->codec_type != AVMEDIA_TYPE_VIDEO &&
        p->codec_type != AVMEDIA_TYPE_AUDIO)
      continue;
    const auto fps = av_guess_frame_rate(in.format, st, nullptr);
    int64_t ticks = st->duration;
    AVRational duration_tb = st->time_base;
    if (ticks == AV_NOPTS_VALUE || st->start_time == AV_NOPTS_VALUE)
      throw Error("STREAM_TIMESTAMP_METADATA_UNAVAILABLE");
    if (ticks == AV_NOPTS_VALUE || ticks <= 0 || st->time_base.num <= 0 ||
        st->time_base.den <= 0)
      throw Error("DURATION_UNAVAILABLE");
    const auto *desc =
        av_pix_fmt_desc_get(static_cast<AVPixelFormat>(p->format));
    const auto *profile = avcodec_profile_name(p->codec_id, p->profile);
    char layout[256] = {};
    if (p->codec_type == AVMEDIA_TYPE_AUDIO &&
        av_channel_layout_describe(&p->ch_layout, layout, sizeof(layout)) < 0)
      throw Error("CHANNEL_LAYOUT_UNAVAILABLE");
    streams.push_back(J{
        {"index", i},
        {"type", p->codec_type == AVMEDIA_TYPE_VIDEO ? "video" : "audio"},
        {"codec", avcodec_get_name(p->codec_id)},
        {"profile", profile ? J(profile) : J(nullptr)},
        {"channelLayout",
         p->codec_type == AVMEDIA_TYPE_AUDIO ? J(layout) : J(nullptr)},
        {"width", p->width},
        {"height", p->height},
        {"pixelFormat",
         p->codec_type == AVMEDIA_TYPE_VIDEO &&
                 av_get_pix_fmt_name(static_cast<AVPixelFormat>(p->format))
             ? av_get_pix_fmt_name(static_cast<AVPixelFormat>(p->format))
             : "unknown"},
        {"timeBase", {{"n", st->time_base.num}, {"d", st->time_base.den}}},
        {"startPTS",
         std::to_string(st->start_time == AV_NOPTS_VALUE ? 0 : st->start_time)},
        {"durationTicks", std::to_string(ticks)},
        {"durationTimeBase", {{"n", duration_tb.num}, {"d", duration_tb.den}}},
        {"fps", {{"n", fps.num}, {"d", fps.den}}},
        {"sampleRate", p->sample_rate},
        {"channels", p->ch_layout.nb_channels},
        {"primaries", av_color_primaries_name(p->color_primaries)
                          ? av_color_primaries_name(p->color_primaries)
                          : "unspecified"},
        {"transfer", av_color_transfer_name(p->color_trc)
                         ? av_color_transfer_name(p->color_trc)
                         : "unspecified"},
        {"matrix", av_color_space_name(p->color_space)
                       ? av_color_space_name(p->color_space)
                       : "unspecified"},
        {"range", p->color_range == AVCOL_RANGE_JPEG
                      ? "full"
                      : (p->color_range == AVCOL_RANGE_MPEG ? "limited"
                                                            : "unspecified")},
        {"bitDepth", desc ? desc->comp[0].depth : 8},
        {"hasAlpha",
         desc == nullptr || (desc->flags & AV_PIX_FMT_FLAG_ALPHA) != 0},
        {"rotation",
         av_packet_side_data_get(p->coded_side_data, p->nb_coded_side_data,
                                 AV_PKT_DATA_DISPLAYMATRIX) != nullptr}});
  }
  if (in.video >= 0) {
    in.prepare();
    int64_t previous = AV_NOPTS_VALUE, delta = 0;
    bool variable = false;
    int frames = 0;
    while (auto *frame = in.decode()) {
      const auto timestamp = in.pts(frame);
      av_frame_free(&frame);
      if (frames == 0 && timestamp != in.format->streams[in.video]->start_time)
        throw Error("START_PTS_POLICY_REQUIRED");
      if (++frames > 120000)
        throw Error("PROBE_FRAME_LIMIT");
      if (previous != AV_NOPTS_VALUE) {
        const auto interval = timestamp - previous;
        if (interval <= 0)
          throw Error("NON_MONOTONIC_PTS");
        if (delta != 0 && interval != delta)
          variable = true;
        delta = interval;
      }
      previous = timestamp;
    }
    for (auto &stream : streams) {
      stream["variableFrameRate"] =
          stream["type"] == "video" ? (stream["index"].get<int>() != in.video ||
                                       variable || frames < 2)
                                    : false;
    }
  }
  return J{{"streams", streams}, {"videoIndex", in.video}};
}
struct Output {
  AVFormatContext *format = nullptr;
  AVCodecContext *encoder = nullptr;
  AVStream *stream = nullptr;
  AVFrame *frame = nullptr;
  AVPacket *packet = nullptr;
  SwsContext *scaler = nullptr;
  ~Output() {
    sws_freeContext(scaler);
    av_packet_free(&packet);
    av_frame_free(&frame);
    avcodec_free_context(&encoder);
    if (format) {
      if (format->pb)
        avio_closep(&format->pb);
      avformat_free_context(format);
    }
  }
  void open(const std::string &path, int w, int h, AVRational fps) {
    // Creation must not overwrite any existing file. Publication is a separate
    // host transaction.
    if (!std::filesystem::path(path).is_absolute() ||
        std::filesystem::exists(path))
      throw Error("OUTPUT_MUST_BE_NEW_LOCAL_PATH");
    ok(avformat_alloc_output_context2(&format, nullptr, "mp4", nullptr));
    const auto *codec = avcodec_find_encoder_by_name("libx264");
    if (!codec)
      throw Error("ENCODER_UNAVAILABLE");
    encoder = avcodec_alloc_context3(codec);
    if (!encoder)
      throw Error("OUT_OF_MEMORY");
    encoder->width = w;
    encoder->height = h;
    encoder->pix_fmt = AV_PIX_FMT_YUV420P;
    encoder->time_base = av_inv_q(fps);
    encoder->framerate = fps;
    encoder->thread_count = 2;
    encoder->gop_size = 30;
    encoder->max_b_frames = 0;
    encoder->color_primaries = AVCOL_PRI_BT709;
    encoder->color_trc = AVCOL_TRC_BT709;
    encoder->colorspace = AVCOL_SPC_BT709;
    encoder->color_range = AVCOL_RANGE_MPEG;
    if (format->oformat->flags & AVFMT_GLOBALHEADER)
      encoder->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    AVDictionary *options = nullptr;
    av_dict_set(&options, "preset", "ultrafast", 0);
    av_dict_set(&options, "crf", "18", 0);
    const int r = avcodec_open2(encoder, codec, &options);
    av_dict_free(&options);
    ok(r);
    stream = avformat_new_stream(format, nullptr);
    if (!stream)
      throw Error("OUT_OF_MEMORY");
    stream->time_base = encoder->time_base;
    ok(avcodec_parameters_from_context(stream->codecpar, encoder));
    ok(avio_open2(&format->pb, ("file:" + path).c_str(), AVIO_FLAG_WRITE,
                  nullptr, nullptr));
    ok(avformat_write_header(format, nullptr));
    frame = av_frame_alloc();
    packet = av_packet_alloc();
    if (!frame || !packet)
      throw Error("OUT_OF_MEMORY");
    frame->format = encoder->pix_fmt;
    frame->width = w;
    frame->height = h;
    frame->color_primaries = encoder->color_primaries;
    frame->color_trc = encoder->color_trc;
    frame->colorspace = encoder->colorspace;
    frame->color_range = encoder->color_range;
    ok(av_frame_get_buffer(frame, 32));
  }
  void drain() {
    for (;;) {
      const int r = avcodec_receive_packet(encoder, packet);
      if (r == AVERROR_EOF || r == AVERROR(EAGAIN))
        return;
      ok(r);
      av_packet_rescale_ts(packet, encoder->time_base, stream->time_base);
      packet->stream_index = stream->index;
      packet->duration = av_rescale_q(1, encoder->time_base, stream->time_base);
      const int written = av_interleaved_write_frame(format, packet);
      av_packet_unref(packet);
      ok(written);
    }
  }
  void render(AVFrame *source, int64_t index) {
    ok(av_frame_make_writable(frame));
    if (!source) {
      for (int y = 0; y < frame->height; y++)
        std::memset(frame->data[0] + y * frame->linesize[0], 16, frame->width);
      for (int p = 1; p < 3; p++)
        for (int y = 0; y < frame->height / 2; y++)
          std::memset(frame->data[p] + y * frame->linesize[p], 128,
                      frame->width / 2);
    } else {
      if (source->width != frame->width || source->height != frame->height)
        throw Error("SCALING_POLICY_REQUIRED");
      if (source->colorspace != AVCOL_SPC_BT709 ||
          source->color_trc != AVCOL_TRC_BT709 ||
          source->color_primaries != AVCOL_PRI_BT709 ||
          source->color_range != AVCOL_RANGE_MPEG)
        throw Error("COLOR_POLICY_REQUIRED");
      scaler =
          sws_getCachedContext(scaler, source->width, source->height,
                               static_cast<AVPixelFormat>(source->format),
                               frame->width, frame->height, AV_PIX_FMT_YUV420P,
                               SWS_BILINEAR, nullptr, nullptr, nullptr);
      if (!scaler)
        throw Error("SCALER_UNAVAILABLE");
      const int *cs = sws_getCoefficients(SWS_CS_ITU709);
      ok(sws_setColorspaceDetails(scaler, cs, 0, cs, 0, 0, 1 << 16, 1 << 16));
      if (sws_scale(scaler, source->data, source->linesize, 0, source->height,
                    frame->data, frame->linesize) != frame->height)
        throw Error("SCALING_FAILED");
    }
    frame->pts = index;
    ok(avcodec_send_frame(encoder, frame));
    drain();
  }
  void finish() {
    ok(avcodec_send_frame(encoder, nullptr));
    drain();
    ok(av_write_trailer(format));
    ok(avio_closep(&format->pb));
  }
};
int64_t target_ticks(const J &source, int64_t frame, AVRational output_tb,
                     AVStream *stream) {
  if (stream->start_time == AV_NOPTS_VALUE)
    throw Error("STREAM_TIMESTAMP_METADATA_UNAVAILABLE");
  keys(source, {"n", "d"});
  if (!source["n"].is_string())
    throw Error("RECIPE_TYPE");
  const auto str = source["n"].get<std::string>();
  if (str.empty() || str.size() > 19 ||
      str.find_first_not_of("0123456789") != std::string::npos)
    throw Error("RECIPE_RANGE");
  const auto n = std::stoll(str);
  const auto d = integer(source, "d", 1, 1000000000);
  if (stream->time_base.num <= 0 || stream->time_base.den <= 0)
    throw Error("INVALID_TIME_BASE");
  const __int128 num = (static_cast<__int128>(n) * output_tb.den +
                        static_cast<__int128>(frame) * output_tb.num * d) *
                       stream->time_base.den;
  const __int128 den =
      static_cast<__int128>(d) * output_tb.den * stream->time_base.num;
  const __int128 ticks =
      num / den +
      (stream->start_time == AV_NOPTS_VALUE ? 0 : stream->start_time);
  if (ticks > std::numeric_limits<int64_t>::max() ||
      ticks < std::numeric_limits<int64_t>::min())
    throw Error("TIME_OVERFLOW");
  return static_cast<int64_t>(ticks);
}
// Native source thumbnail only, NOT timeline/effect rendering. Real container
// index seek + decoder flush + PTS floor; sequential mode is an independent
// decoded reference path used by qualification, never a fake seek result.
J preview(Engine &engine, const J &recipe) {
  keys(recipe, {"path", "time", "indexed"});
  if (!recipe["path"].is_string() || !recipe["indexed"].is_boolean())
    throw Error("RECIPE_TYPE");
  Input in;
  const auto epoch = engine.epoch.load();
  in.check = [&engine, epoch] {
    if (engine.epoch.load() != epoch)
      throw Error("CANCELED");
  };
  in.open(recipe["path"].get<std::string>());
  in.prepare();
  auto *stream = in.format->streams[in.video];
  int videos = 0;
  for (unsigned i = 0; i < in.format->nb_streams; ++i)
    if (in.format->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO)
      ++videos;
  if (videos != 1)
    throw Error("MULTI_VIDEO_STREAM_PREVIEW_UNSUPPORTED");
  if (in.decoder->width > 2048 || in.decoder->height > 2048)
    throw Error("FRAME_SIZE_LIMIT");
  const auto target = target_ticks(recipe["time"], 0, AVRational{1, 1}, stream);
  if (recipe["indexed"].get<bool>()) {
    const int r = avformat_seek_file(in.format, in.video,
        std::numeric_limits<int64_t>::min(), target, target, AVSEEK_FLAG_BACKWARD);
    if (r < 0)
      throw Error("SEEK_UNAVAILABLE");
    avcodec_flush_buffers(in.decoder);
    in.drained = false;
    in.current = in.decode();
    if (!in.current)
      throw Error("SOURCE_AFTER_LAST_FRAME");
    in.next = in.decode();
  }
  AVFrame *frame = in.at(target);
  if (frame->width < 1 || frame->height < 1 ||
      frame->width > 2048 || frame->height > 2048)
    throw Error("FRAME_SIZE_LIMIT");
  if (frame->format != AV_PIX_FMT_YUV420P)
    throw Error("PREVIEW_PIXEL_FORMAT_UNSUPPORTED");
  if (frame->color_primaries != AVCOL_PRI_BT709 ||
      frame->color_trc != AVCOL_TRC_BT709 ||
      frame->colorspace != AVCOL_SPC_BT709 ||
      frame->color_range != AVCOL_RANGE_MPEG)
    throw Error("COLOR_POLICY_REQUIRED");
  const double factor = 128.0 / std::max(frame->width, frame->height);
  const int width = std::max(1, static_cast<int>(frame->width * std::min(1.0, factor))),
      height = std::max(1, static_cast<int>(frame->height * std::min(1.0, factor)));
  std::unique_ptr<SwsContext, decltype(&sws_freeContext)> sws(
      sws_getContext(frame->width, frame->height,
          static_cast<AVPixelFormat>(frame->format), width, height, AV_PIX_FMT_RGBA,
          SWS_BILINEAR, nullptr, nullptr, nullptr), sws_freeContext);
  if (!sws)
    throw Error("SCALER_UNAVAILABLE");
  const auto *coeff = sws_getCoefficients(SWS_CS_ITU709);
  ok(sws_setColorspaceDetails(sws.get(), coeff, 0, coeff, 1, 0, 1 << 16, 1 << 16));
  std::vector<uint8_t> rgba(static_cast<size_t>(width) * height * 4);
  uint8_t *dst[] = {rgba.data(), nullptr, nullptr, nullptr};
  const int stride[] = {width * 4, 0, 0, 0};
  if (sws_scale(sws.get(), frame->data, frame->linesize, 0, frame->height,
                dst, stride) != height)
    throw Error("SCALE_INCOMPLETE");
  in.check();
  return J{{"width", width}, {"height", height}, {"rgba", rgba},
      {"pts", std::to_string(in.pts(frame))},
      {"startPts", std::to_string(stream->start_time)},
      {"timeBase", {{"n", std::to_string(stream->time_base.num)},
                    {"d", stream->time_base.den}}},
      {"packetsRead", in.packets}, {"indexed", recipe["indexed"]}};
}
J render(Engine &engine, const J &recipe) {
  keys(recipe,
       {"outputPath", "width", "height", "fps", "frameCount", "segments"});
  const auto w = integer(recipe, "width", 2, 2048),
             h = integer(recipe, "height", 2, 2048);
  if (w % 2 || h % 2)
    throw Error("INVALID_CANVAS");
  keys(recipe["fps"], {"n", "d"});
  const AVRational fps{static_cast<int>(integer(recipe["fps"], "n", 1, 120000)),
                       static_cast<int>(integer(recipe["fps"], "d", 1, 10000))};
  if (av_q2d(fps) > 120)
    throw Error("FRAME_RATE_LIMIT");
  const auto count = integer(recipe, "frameCount", 1, 120000);
  const auto &segments = recipe["segments"];
  if (!segments.is_array() || segments.size() > 10000)
    throw Error("SEGMENT_LIMIT");
  int64_t last_end = 0;
  for (const auto &segment : segments) {
    keys(segment,
         {"path", "startFrame", "frameCount", "sourceStart", "streamIndex"});
    const auto begin = integer(segment, "startFrame", 0, count - 1),
               length = integer(segment, "frameCount", 1, count);
    integer(segment, "streamIndex", 0, 63);
    if (begin < last_end || length > count - begin)
      throw Error("SEGMENT_OVERLAP_OR_RANGE");
    last_end = begin + length;
    local_file(segment.at("path").get<std::string>());
  }
  const auto epoch = engine.epoch.load();
  Output out;
  out.open(recipe.at("outputPath").get<std::string>(), w, h, fps);
  std::unique_ptr<Input> input;
  size_t si = 0;
  int current_segment = -1;
  for (int64_t frame = 0; frame < count; frame++) {
    if (engine.epoch.load() != epoch)
      throw Error("CANCELED");
    while (si < segments.size() &&
           frame >= segments[si]["startFrame"].get<int64_t>() +
                        segments[si]["frameCount"].get<int64_t>())
      si++;
    AVFrame *source = nullptr;
    if (si < segments.size() &&
        frame >= segments[si]["startFrame"].get<int64_t>()) {
      const auto &seg = segments[si];
      if (current_segment != static_cast<int>(si)) {
        input = std::make_unique<Input>();
        input->check = [&engine, epoch] {
          if (engine.epoch.load() != epoch)
            throw Error("CANCELED");
        };
        input->open(seg.at("path").get<std::string>());
        input->video = seg.at("streamIndex").get<int>();
        if (input->video < 0 ||
            static_cast<unsigned>(input->video) >= input->format->nb_streams ||
            input->format->streams[input->video]->codecpar->codec_type !=
                AVMEDIA_TYPE_VIDEO)
          throw Error("VIDEO_STREAM_REQUIRED");
        input->prepare();
        current_segment = si;
      }
      const auto target = target_ticks(
          seg.at("sourceStart"), frame - seg.at("startFrame").get<int64_t>(),
          av_inv_q(fps), input->format->streams[input->video]);
      source = input->at(target);
    }
    out.render(source, frame);
  }
  out.finish();
  return J{{"frames", count},
           {"audio", "notRequested"},
           {"encoder", "libx264"},
           {"container", "mp4"}};
}
} // namespace
extern "C" {
uint32_t sm_abi_version(void) { return 1; }
uint64_t sm_create(const char *ns) {
  try {
    if (!ns || !*ns || std::strlen(ns) > 1024)
      return 0;
    std::lock_guard guard(registry_lock);
    if (next_handle == std::numeric_limits<uint64_t>::max())
      return 0;
    const auto id = next_handle++;
    engines.emplace(id, std::make_shared<Engine>(ns));
    return id;
  } catch (...) {
    return 0;
  }
}
int32_t sm_close(uint64_t h, const char *ns) {
  try {
    auto e = engine(h, ns);
    e->epoch.fetch_add(1);
    std::lock_guard guard(registry_lock);
    engines.erase(h);
    return 0;
  } catch (...) {
    return -1;
  }
}
int32_t sm_cancel(uint64_t h, const char *ns) {
  try {
    engine(h, ns)->epoch.fetch_add(1);
    return 0;
  } catch (...) {
    return -1;
  }
}
char *sm_capabilities(void) {
  return boundary([] {
    return J{
        {"abi", 1},
        {"avformatVersion", avformat_version()},
        {"avcodecVersion", avcodec_version()},
        {"ffmpegVersion", av_version_info()},
        {"configuration", avcodec_configuration()},
        {"decoderH264", avcodec_find_decoder(AV_CODEC_ID_H264) != nullptr},
        {"encoderH264", avcodec_find_encoder_by_name("libx264") != nullptr},
        {"networkAllowed", false},
        {"sourcePreview128", true},
        {"audioExport", false},
        {"hardwareAcceleration", false}};
  });
}
char *sm_probe(uint64_t h, const char *ns, const char *path) {
  return boundary([&] {
    auto e = engine(h, ns);
    std::unique_lock lock(e->busy, std::try_to_lock);
    if (!lock.owns_lock())
      throw Error("RESOURCE_BUSY");
    if (!path)
      throw Error("LOCAL_FILE_REQUIRED");
    Input in;
    const auto epoch = e->epoch.load();
    in.check = [e, epoch] {
      if (e->epoch.load() != epoch)
        throw Error("CANCELED");
    };
    in.open(path);
    return probe(in);
  });
}
char *sm_preview(uint64_t h,const char *ns,const char *recipe) {
  return boundary([&] {
    auto e=engine(h,ns);std::unique_lock lock(e->busy,std::try_to_lock);
    if(!lock.owns_lock())throw Error("RESOURCE_BUSY");
    if(!recipe || std::strlen(recipe)>4096)throw Error("RECIPE_LIMIT");
    return preview(*e,parse_recipe(recipe));
  });
}
char *sm_export(uint64_t h, const char *ns, const char *recipe) {
  return boundary([&] {
    auto e = engine(h, ns);
    std::unique_lock lock(e->busy, std::try_to_lock);
    if (!lock.owns_lock())
      throw Error("RESOURCE_BUSY");
    if (!recipe || std::strlen(recipe) > 4 * 1024 * 1024)
      throw Error("RECIPE_LIMIT");
    return render(*e, parse_recipe(recipe));
  });
}
void sm_string_free(char *text) { std::free(text); }
}
