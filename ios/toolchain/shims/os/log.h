/*
 * A minimal <os/log.h> for compiling iOS objects on Linux.
 *
 * Apple's <os/log.h> ships only in the Xcode SDK, which Linux build hosts do not have. The one C
 * file in the iOS dependency graph that needs it is tracing-oslog's `wrapper.c` (pulled in by
 * bevy_log on iOS), and it only uses `os_log_with_type` and `OS_LOG_DEFAULT`. This header declares
 * that public ABI and expands the macro the same way the SDK does, through clang's
 * `__builtin_os_log_format` builtins. The real libsystem_trace resolves the symbols on macOS.
 */
#ifndef SURVIVORS_SHIM_OS_LOG_H
#define SURVIVORS_SHIM_OS_LOG_H

#include <stdbool.h>
#include <stdint.h>
#include <os/object.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct os_log_s *os_log_t;
typedef uint8_t os_log_type_t;

#define OS_LOG_TYPE_DEFAULT ((os_log_type_t)0x00)
#define OS_LOG_TYPE_INFO    ((os_log_type_t)0x01)
#define OS_LOG_TYPE_DEBUG   ((os_log_type_t)0x02)
#define OS_LOG_TYPE_ERROR   ((os_log_type_t)0x10)
#define OS_LOG_TYPE_FAULT   ((os_log_type_t)0x11)

extern struct os_log_s _os_log_default;
#define OS_LOG_DEFAULT ((os_log_t)(&_os_log_default))

extern void *__dso_handle;

os_log_t os_log_create(const char *subsystem, const char *category);
bool os_log_type_enabled(os_log_t oslog, os_log_type_t type);
void _os_log_impl(void *dso, os_log_t log, os_log_type_t type, const char *format, uint8_t *buf,
                  uint32_t size);

#define os_log_with_type(log, type, format, ...) __extension__({                                  \
    os_log_t _s_log = (log);                                                                       \
    os_log_type_t _s_type = (type);                                                                \
    if (os_log_type_enabled(_s_log, _s_type)) {                                                    \
        static const char _s_fmt[]                                                                 \
            __attribute__((section("__TEXT,__oslogstring,cstring_literals"))) = format;            \
        uint8_t _s_buf[__builtin_os_log_format_buffer_size(format, ##__VA_ARGS__)]                 \
            __attribute__((aligned(16)));                                                          \
        _os_log_impl(&__dso_handle, _s_log, _s_type, _s_fmt,                                       \
                     (uint8_t *)__builtin_os_log_format(_s_buf, format, ##__VA_ARGS__),            \
                     (uint32_t)sizeof(_s_buf));                                                    \
    }                                                                                              \
})

#define os_log(log, format, ...) os_log_with_type(log, OS_LOG_TYPE_DEFAULT, format, ##__VA_ARGS__)

#ifdef __cplusplus
}
#endif

#endif
