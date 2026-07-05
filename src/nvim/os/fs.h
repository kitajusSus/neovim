#pragma once

#include <stddef.h>  // IWYU pragma: keep
#include <stdint.h>  // IWYU pragma: keep
#include <stdio.h>  // IWYU pragma: keep
#include <uv.h>  // IWYU pragma: keep

#include "nvim/os/fs_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

char *os_realpath(const char *name, char *buf, size_t len);

#include "os/fs.h.generated.h"
