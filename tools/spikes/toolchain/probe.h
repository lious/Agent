#ifndef STUDIO_TOOLCHAIN_PROBE_H
#define STUDIO_TOOLCHAIN_PROBE_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// Probe-only ABI. Not a decoder or an editor media handle.
uint32_t studio_probe_abi_version(void);
int64_t studio_probe_echo_i64(int64_t value);
uint64_t studio_probe_open(const char* namespace_key);
int32_t studio_probe_check(uint64_t handle, const char* namespace_key);
int32_t studio_probe_close(uint64_t handle);
int32_t studio_probe_time(int64_t numerator, uint32_t denominator);
#ifdef __cplusplus
}
#endif
#endif
