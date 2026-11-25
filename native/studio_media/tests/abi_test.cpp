#include "studio_media.h"
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <mutex>
#include <nlohmann/json.hpp>
#include <stdexcept>
#include <thread>
using J = nlohmann::json;
void require(bool b) {
  if (!b)
    throw std::runtime_error("assertion failed");
}
J response(char *s) {
  require(s);
  J j;
  try {
    j = J::parse(s);
  } catch (...) {
    sm_string_free(s);
    throw;
  }
  sm_string_free(s);
  return j;
}
size_t fds() {
  return std::distance(std::filesystem::directory_iterator("/proc/self/fd"),
                       std::filesystem::directory_iterator());
}
int main(int argc, char **argv) {
  try {
    require(argc == 2);
    std::string test = argv[1];
    require(sm_abi_version() == 1);
    const auto before = fds();
    if (test == "handles") {
      require(sm_create(nullptr) == 0);
      require(sm_create("") == 0);
      for (int i = 0; i < 100; i++) {
        auto a = sm_create("studio"), b = sm_create("image");
        require(a && b && a != b);
        require(response(sm_probe(a, "image", "/not/read"))["code"] ==
                "NAMESPACE_MISMATCH");
        require(sm_close(a, "image") == -1);
        require(sm_cancel(b, "studio") == -1);
        require(sm_cancel(a, "studio") == 0);
        require(sm_close(a, "studio") == 0);
        require(sm_close(a, "studio") == -1);
        require(response(sm_probe(a, "studio", "/not/read"))["code"] ==
                "INVALID_HANDLE");
        require(sm_close(b, "image") == 0);
      }
    } else if (test == "errors") {
      auto h = sm_create("test");
      for (auto path : {"https://example.invalid/media.mp4", "file:/etc/passwd",
                        "relative.mp4"})
        require(response(sm_probe(h, "test", path))["code"] ==
                "LOCAL_FILE_REQUIRED");
      require(!response(sm_export(h, "test", "not json"))["ok"].get<bool>());
      require(response(sm_export(h, "test", "{}"))["code"] == "RECIPE_FIELDS");
      require(
          response(sm_export(h, "test", "{\"width\":1,\"width\":2}"))["code"] ==
          "RECIPE_DUPLICATE_KEY");
      std::string deep(66, '[');
      deep += "0";
      deep += std::string(66, ']');
      require(response(sm_export(h, "test", deep.c_str()))["code"] ==
              "RECIPE_DEPTH_LIMIT");
      require(sm_close(h, "test") == 0);
    } else if (test == "cancel") {
      auto root =
          std::filesystem::temp_directory_path() /
          ("studio-cancel-" +
           std::to_string(
               std::chrono::steady_clock::now().time_since_epoch().count()));
      std::filesystem::create_directory(root);
      const auto pcm = root / "bounded.f32";
      {
        std::ofstream f(pcm, std::ios::binary);
        f.seekp(48000LL * 120 * 8 - 1);
        f.put(0);
      }
      for (int i = 0; i < 20; i++) {
        auto h = sm_create("cancel");
        std::atomic<bool> done = false;
        J result;
        J recipe = {
            {"outputPath", (root / (std::to_string(i) + ".pending")).string()},
            {"width", 720},
            {"height", 1280},
            {"fps", {{"n", 30}, {"d", 1}}},
            {"frameCount", 120000},
            {"segments", J::array()}};
        if (i >= 10) {
          recipe["frameCount"] = 3600;
          recipe["audio"] = {{"path", pcm.string()},
                             {"sampleCount", 48000 * 120}};
        }
        std::thread work([&] {
          result = response(sm_export(h, "cancel", recipe.dump().c_str()));
          done = true;
        });
        // Observe actual AAC input progress, not buffered file size or a sleep.
        // This diagnostic is NOT a device presentation clock.
        if (i >= 10) {
          const auto limit =
              std::chrono::steady_clock::now() + std::chrono::seconds(5);
          while (!done && sm_encoded_audio_samples(h, "cancel") < 4800 &&
                 std::chrono::steady_clock::now() < limit)
            std::this_thread::yield();
          if (done || sm_encoded_audio_samples(h, "cancel") < 4800) {
            sm_cancel(h, "cancel");
            work.join();
            throw std::runtime_error(
                "AAC cancellation missed active encoder progress");
          }
        }
        std::mutex m;
        std::condition_variable cv;
        std::unique_lock lock(m);
        const auto limit =
            std::chrono::steady_clock::now() + std::chrono::seconds(10);
        while (!done && std::chrono::steady_clock::now() < limit) {
          sm_cancel(h, "cancel");
          cv.wait_for(lock, std::chrono::milliseconds(1));
        }
        if (!done)
          sm_close(h, "cancel");
        work.join();
        require(result["code"] == "CANCELED");
        require(sm_close(h, "cancel") == 0);
        require(response(sm_probe(h, "cancel", "/not/read"))["code"] ==
                "INVALID_HANDLE");
      }
      std::filesystem::remove_all(root);
    } else if(test=="opacity_cancel" || test=="transform_cancel" || test=="dissolve_cancel" || test=="raster_cancel") {
      const auto *source=std::getenv("STUDIO_TEST_VIDEO");require(source && std::filesystem::is_regular_file(source));
      const auto root=std::filesystem::temp_directory_path()/("opacity-cancel-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));std::filesystem::create_directory(root);
      const auto initial=sm_live_owned_frames();
      for(int i=0;i<100;i++){
        const auto h=sm_create("opacity-cancel");std::atomic<bool> done=false;J result;
        J recipe={{"outputPath",(root/(std::to_string(i)+".mp4")).string()},{"width",320},{"height",180},{"fps",{{"n",30},{"d",1}}},{"frameCount",120000},{"segments",J::array({{{"path",source},{"startFrame",0},{"frameCount",90},{"sourceStart",{{"n","0"},{"d",1}}},{"streamIndex",0},{"opacityQ16",32768}}})}};
        auto &seg=recipe["segments"][0];seg.erase("opacityQ16");seg["opacityFramesQ16"]=J::array();for(int f=0;f<90;f++)seg["opacityFramesQ16"].push_back(f*65536/89);
        if(test=="transform_cancel")seg["transform2d"]={{"translateX",16},{"translateY",0},{"scaleX",.75},{"scaleY",.75},{"rotationDeg",15},{"anchorX",.5},{"anchorY",.5}};
        if(test=="dissolve_cancel" || test=="raster_cancel"){
          auto right=seg;right.erase("startFrame");right.erase("frameCount");right["transform2d"]={{"translateX",16},{"translateY",0},{"scaleX",.75},{"scaleY",.75},{"rotationDeg",15},{"anchorX",.5},{"anchorY",.5}};
          if(test=="raster_cancel"){
            seg["rasterEffects"]={{"crop",{{"left",.25},{"top",.1},{"right",.9},{"bottom",1}}},{"colorBasic",{{"exposureStops",2},{"contrast",.6},{"saturation",1.5}}}};
            right["rasterEffects"]={{"crop",{{"left",.1},{"top",0},{"right",.75},{"bottom",.9}}},{"colorBasic",{{"exposureStops",-1},{"contrast",1.2},{"saturation",.5}}}};
          }
          seg["secondary"]=right;seg["mixFramesQ16"]=J::array();for(int f=0;f<90;f++)seg["mixFramesQ16"].push_back(f*65536/89);
        }
        std::thread work([&]{result=response(sm_export(h,"opacity-cancel",recipe.dump().c_str()));done=true;});
        const auto limit=std::chrono::steady_clock::now()+std::chrono::seconds(8);
        while(!done && sm_rendered_video_frames(h,"opacity-cancel")<2 && std::chrono::steady_clock::now()<limit)std::this_thread::yield();
        const bool active=!done && sm_rendered_video_frames(h,"opacity-cancel")>=2;
        sm_cancel(h,"opacity-cancel");work.join();
        require(sm_close(h,"opacity-cancel")==0);
        require(active && result["code"]=="CANCELED");require(sm_live_owned_frames()==initial);
      }
      std::filesystem::remove_all(root);std::cout<<"100 active "<<test<<" cancellations; app-owned AVFrame delta=0; codec/GPU internal leak qualification NOT claimed\n";
    } else
      throw std::runtime_error("unknown test");
    require(fds() == before);
    std::cout << test << ": PASS; fd delta=0\n";
    return 0;
  } catch (const std::exception &e) {
    std::cerr << e.what() << "\n";
    return 1;
  }
}
