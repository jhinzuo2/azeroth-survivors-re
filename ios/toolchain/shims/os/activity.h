/*
 * A placeholder <os/activity.h> for compiling iOS objects on Linux. tracing-oslog's `wrapper.h`
 * includes it but its C code uses nothing from it (the activity API is bound from Rust).
 */
#ifndef SURVIVORS_SHIM_OS_ACTIVITY_H
#define SURVIVORS_SHIM_OS_ACTIVITY_H
#include <os/object.h>
#endif
