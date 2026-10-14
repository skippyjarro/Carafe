// Lets Carafe choose a bottle's graphics layer on engines built from CodeWeavers' CrossOver source.
// That Wine loads an optional "cxcompatdb.so" from beside ntdll.so at startup and exports
// prepend_dll_path() for it to call. This plugin uses the hook to put the folders listed in
// WINEDLLPATH_PREPEND (D3DMetal, DXMT or DXVK) ahead of Wine's own DirectX libraries.
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

__attribute__((constructor))
static void carafe_prepend_dll_paths(void)
{
    void (*prepend_dll_path)(const char *) = dlsym(RTLD_DEFAULT, "prepend_dll_path");
    const char *list = getenv("WINEDLLPATH_PREPEND");
    if (!prepend_dll_path || !list || !*list) return;

    // Each call puts its folder first, so walk the list backwards to keep the order as written.
    // Wine keeps the pointers, so the copy is deliberately never freed.
    char *copy = strdup(list);
    for (;;) {
        char *colon = strrchr(copy, ':');
        const char *entry = colon ? colon + 1 : copy;
        if (*entry) prepend_dll_path(entry);
        if (!colon) break;
        *colon = '\0';
    }
}
