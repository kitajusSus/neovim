#pragma once

#include <stddef.h>
#include "nvim/func_attr.h"

#ifdef __cplusplus
extern "C" {
#endif
char *base64_encode(const char *src, size_t src_len);
char *base64_decode(const char *src, size_t src_len, size_t *out_lenp);
#ifdef __cplusplus
}
#endif
