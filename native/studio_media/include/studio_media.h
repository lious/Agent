#ifndef STUDIO_MEDIA_H
#define STUDIO_MEDIA_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
uint32_t sm_abi_version(void);
uint64_t sm_create(const char *ns);
int32_t sm_close(uint64_t handle, const char *ns);
/* Submitted AAC input diagnostic, NEVER a presented AudioSink clock. */
uint64_t sm_encoded_audio_samples(uint64_t handle, const char *namespace_json);
uint64_t sm_cancel_epoch(uint64_t handle, const char *ns);
int32_t sm_cancel(uint64_t handle, const char *ns);
// Returned UTF-8 JSON is owned by caller until sm_string_free. No borrowed
// frames.
char *sm_capabilities(void);
char *sm_probe(uint64_t handle, const char *ns, const char *local_path);
char *sm_decode_audio(uint64_t handle, const char *ns, const char *recipe);
char *sm_preview(uint64_t handle, const char *ns,
                 const char *closed_recipe_json);
char *sm_export(uint64_t handle, const char *ns,
                const char *closed_recipe_json);
/* Actual local Pulse service playback; no wall-clock interpolation. */
char *sm_playback(uint64_t handle, const char *ns, const char *recipe);
void sm_string_free(char *text);
#ifdef __cplusplus
}
#endif
#endif
