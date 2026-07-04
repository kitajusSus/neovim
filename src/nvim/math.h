#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
int xfpclassify(double d);
int xisinf(double d);
int xisnan(double d);
int xctz(uint64_t x);
unsigned xpopcount(uint64_t x);
int vim_append_digit_int(int *value, int digit);
int trim_to_int(int64_t x);
#ifdef __cplusplus
}
#endif
