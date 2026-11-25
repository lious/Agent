#include "probe.h"
#include <limits>
#include <map>
#include <mutex>
#include <string>
namespace {
std::mutex mutex;
std::map<uint64_t, std::string> namespaces;
uint64_t next_handle = 1;
}
uint32_t studio_probe_abi_version(void) { return 1; }
int64_t studio_probe_echo_i64(int64_t value) { return value; }
uint64_t studio_probe_open(const char* ns) {
  if (!ns || !*ns) return 0;
  std::lock_guard lock(mutex);
  if (next_handle == std::numeric_limits<uint64_t>::max()) return 0;
  const auto handle = next_handle++;
  namespaces.emplace(handle, ns);
  return handle;
}
int32_t studio_probe_check(uint64_t handle, const char* ns) {
  if (!ns) return -1;
  std::lock_guard lock(mutex);
  const auto it = namespaces.find(handle);
  if (it == namespaces.end()) return -1;
  return it->second == ns ? 0 : -2;
}
int32_t studio_probe_close(uint64_t handle) {
  std::lock_guard lock(mutex);
  return namespaces.erase(handle) == 1 ? 0 : -1;
}
int32_t studio_probe_time(int64_t, uint32_t denominator) {
  return denominator > 0 && denominator <= 1000000000 ? 0 : -3;
}
