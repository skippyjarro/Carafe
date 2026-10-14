// Works around a bug in the CrossOver 24 Wine build: it looks up the TCP/UDP connection-table
// sysctls with an uninitialised (zero) buffer size, which current macOS rejects. Without the
// tables, Windows programs can't tell which process owns a socket, and Battle.net's Agent
// refuses its own launcher (error BLZBNTBNA00000005).
// Loaded into Wine processes with DYLD_INSERT_LIBRARIES.
#include <stddef.h>
#include <sys/types.h>
#include <sys/sysctl.h>

static int carafe_sysctlnametomib(const char *name, int *mib, size_t *size)
{
    if (mib && size && *size == 0) *size = CTL_MAXNAME;
    return sysctlnametomib(name, mib, size);
}

__attribute__((used, section("__DATA,__interpose")))
static const struct { const void *replacement, *original; } interpose_sysctlnametomib = {
    (const void *)carafe_sysctlnametomib, (const void *)sysctlnametomib
};
