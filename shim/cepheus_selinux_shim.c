/*
 * cepheus_selinux_shim - lets vndservicemanager live without selinuxfs.
 *
 * Ubuntu Touch needs AppArmor as the active LSM, and on this 4.14 kernel only
 * one major LSM can be active, so security=apparmor means selinux=0 and no
 * /sys/fs/selinux.  Android 16's vndservicemanager then dies at startup:
 *
 *     vndservicemanager: Check failed: selinux_status_open(true ) >= 0
 *
 * and (until its rc was fixed) took every HAL down with it on each restart.
 * The rest of the container is fine: init handles a disabled SELinux, and
 * hwservicemanager survives because getcon() reads /proc/self/attr/current,
 * which AppArmor answers with "unconfined".  Only this one binary insists.
 *
 * Preloaded into vndservicemanager alone (setenv LD_PRELOAD in its rc), this
 * covers exactly the libselinux symbols that binary imports.  When selinuxfs
 * IS present it passes every call through to the real libselinux via
 * RTLD_NEXT, so the file is safe to ship on the SELinux boot too.  When it is
 * absent, it answers as an always-permissive SELinux would:
 * selinux_check_access() says allowed.  Be honest about what that is - the
 * same trade as the aa-exec shim: restoring function where the subsystem is
 * absent, not implementing it.  Android's SELinux on this port has been
 * permissive throughout anyway.
 *
 * Strings handed back through out-parameters are strdup()'d because the
 * caller releases them with freecon(), which is free().
 *
 * Build: NDK clang --target=aarch64-linux-android30 -fPIC -shared -O2
 *        -Wl,-soname,libcepheus_selinux_shim.so -o libcepheus_selinux_shim.so
 *        cepheus_selinux_shim.c -ldl
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

struct selabel_handle;

/* Prototypes as libselinux declares them; the NDK ships no selinux headers. */
typedef int  (*fn_status_open)(int);
typedef int  (*fn_status_updated)(void);
typedef int  (*fn_getcon)(char **);
typedef int  (*fn_check_access)(const char *, const char *, const char *,
                                const char *, void *);
typedef struct selabel_handle *(*fn_vendor_handle)(void);
typedef int  (*fn_selabel_lookup)(struct selabel_handle *, char **,
                                  const char *, int);
typedef void (*fn_selabel_close)(struct selabel_handle *);

static int dummy_handle;   /* what we hand out as a selabel_handle when stubbing */

static void kmsg(const char *msg)
{
    int fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);
    if (fd < 0)
        return;
    (void)!write(fd, msg, strlen(msg));
    close(fd);
}

/* Decided once: if selinuxfs is there, get out of the way completely. */
static int passthrough(void)
{
    static int cached = -1;
    if (cached < 0) {
        cached = access("/sys/fs/selinux/status", R_OK) == 0;
        kmsg(cached
             ? "cepheus-selinux-shim: selinuxfs present, passing through\n"
             : "cepheus-selinux-shim: no selinuxfs, answering as permissive\n");
    }
    return cached;
}

#define REAL(type, name) ((type)dlsym(RTLD_NEXT, #name))

int selinux_status_open(int fallback)
{
    fn_status_open real;
    if (passthrough() && (real = REAL(fn_status_open, selinux_status_open)))
        return real(fallback);
    return 0;
}

int selinux_status_updated(void)
{
    fn_status_updated real;
    if (passthrough() && (real = REAL(fn_status_updated, selinux_status_updated)))
        return real();
    return 0;   /* no policy change */
}

int getcon(char **con)
{
    fn_getcon real;
    if (passthrough() && (real = REAL(fn_getcon, getcon)))
        return real(con);
    *con = strdup("u:r:vndservicemanager:s0");
    return *con ? 0 : -1;
}

int selinux_check_access(const char *scon, const char *tcon,
                         const char *tclass, const char *perm, void *aux)
{
    fn_check_access real;
    if (passthrough() && (real = REAL(fn_check_access, selinux_check_access)))
        return real(scon, tcon, tclass, perm, aux);
    return 0;   /* allowed - permissive */
}

struct selabel_handle *selinux_android_vendor_service_context_handle(void)
{
    fn_vendor_handle real;
    if (passthrough() &&
        (real = REAL(fn_vendor_handle, selinux_android_vendor_service_context_handle)))
        return real();
    return (struct selabel_handle *)&dummy_handle;
}

int selabel_lookup(struct selabel_handle *h, char **con, const char *key, int type)
{
    fn_selabel_lookup real;
    if (h != (struct selabel_handle *)&dummy_handle &&
        (real = REAL(fn_selabel_lookup, selabel_lookup)))
        return real(h, con, key, type);
    *con = strdup("u:object_r:default_android_vndservice:s0");
    return *con ? 0 : -1;
}

void selabel_close(struct selabel_handle *h)
{
    fn_selabel_close real;
    if (h != (struct selabel_handle *)&dummy_handle &&
        (real = REAL(fn_selabel_close, selabel_close)))
        real(h);
}
