/*
 * Minimal android.system.net.netd@1.1::INetd for netmgrd.
 *
 * Qualcomm's netmgrd waits for the netd HAL before it brings up the data
 * links ("NetmgrNetdClientInit(): Looking for Netd service") and only then
 * opens /dev/socket/netmgr.  Until it does, qcrild's data module never runs
 * dsi_init, every setupDataCall fails with "unable to get dsi hndl" (ofono:
 * "Unexpected data call status 4100") and there is no mobile data.  netd
 * lives in the tethering APEX, which this Halium system image does not
 * carry, so answer its OEM-network calls here.  Routing and addresses on
 * rmnet_data* are NetworkManager's job on Ubuntu Touch; netmgrd only needs
 * the calls to succeed.
 *
 * Build (in the rootfs build chroot): gcc -O2 -o cepheus-netd-stub
 *   cepheus-netd-stub.c $(pkg-config --cflags --libs libgbinder glib-2.0)
 */
#include <gbinder/gbinder.h>
#include <glib-unix.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>

#define NETD_1_0 "android.system.net.netd@1.0::INetd"
#define NETD_1_1 "android.system.net.netd@1.1::INetd"

enum {
    CREATE_OEM_NETWORK = 1,
    DESTROY_OEM_NETWORK,
    ADD_ROUTE_TO_OEM_NETWORK,
    REMOVE_ROUTE_FROM_OEM_NETWORK,
    ADD_INTERFACE_TO_OEM_NETWORK,
    REMOVE_INTERFACE_FROM_OEM_NETWORK,
    SET_IP_FORWARD_ENABLE,
    SET_FORWARDING_BETWEEN_INTERFACES,
};

/* Android builds an OEM network handle as (netId << 32) | 0xfacade. */
#define OEM_NET_ID 1001u
#define OEM_HANDLE (((guint64)OEM_NET_ID << 32) | 0xfacadeu)
#define OEM_MARK 0x0u

static GMainLoop *loop;

static const char *names[] = {
    "?", "createOemNetwork", "destroyOemNetwork", "addRouteToOemNetwork",
    "removeRouteFromOemNetwork", "addInterfaceToOemNetwork",
    "removeInterfaceFromOemNetwork", "setIpForwardEnable",
    "setForwardingBetweenInterfaces",
};

static GBinderLocalReply *handle(GBinderLocalObject *obj, GBinderRemoteRequest *req,
                                 guint code, guint flags, int *status, void *user)
{
    (void)flags; (void)user;
    const char *iface = gbinder_remote_request_interface(req);
    if (!iface || (strcmp(iface, NETD_1_1) && strcmp(iface, NETD_1_0)) ||
        code < CREATE_OEM_NETWORK || code > SET_FORWARDING_BETWEEN_INTERFACES) {
        fprintf(stderr, "unexpected call %s code %u\n", iface ? iface : "(null)", code);
        *status = GBINDER_STATUS_FAILED;
        return NULL;
    }
    GBinderReader r;
    gbinder_remote_request_init_reader(req, &r);
    char args[256] = "";
    guint64 h = 0;
    if (code != CREATE_OEM_NETWORK && code != SET_IP_FORWARD_ENABLE &&
        code != SET_FORWARDING_BETWEEN_INTERFACES)
        gbinder_reader_read_uint64(&r, &h);
    for (int i = 0; i < 3; i++) {
        const char *s = gbinder_reader_read_hidl_string_c(&r);
        if (!s)
            break;
        g_strlcat(args, " ", sizeof(args));
        g_strlcat(args, s, sizeof(args));
    }
    fprintf(stderr, "%s%s\n", names[code], args);

    GBinderLocalReply *reply = gbinder_local_object_new_reply(obj);
    gbinder_local_reply_append_int32(reply, GBINDER_STATUS_OK);
    if (code == CREATE_OEM_NETWORK) {
        gbinder_local_reply_append_int64(reply, OEM_HANDLE);
        gbinder_local_reply_append_int32(reply, OEM_MARK);
    }
    gbinder_local_reply_append_int32(reply, 0); /* StatusCode::OK */
    *status = GBINDER_STATUS_OK;
    return reply;
}

static gboolean on_signal(gpointer data)
{
    (void)data;
    g_main_loop_quit(loop);
    return G_SOURCE_REMOVE;
}

static void on_presence(GBinderServiceManager *sm, void *user)
{
    (void)user;
    if (!gbinder_servicemanager_is_present(sm)) {
        /* Our registration died with it; let systemd start us again. */
        fprintf(stderr, "hwservicemanager gone\n");
        g_main_loop_quit(loop);
    }
}

int main(void)
{
    static const char *ifaces[] = { NETD_1_1, NETD_1_0, NULL };
    GBinderServiceManager *sm = gbinder_servicemanager_new("/dev/hwbinder");
    if (!sm) {
        fprintf(stderr, "no hwservicemanager\n");
        return 1;
    }
    GBinderLocalObject *obj = gbinder_servicemanager_new_local_object2(sm, ifaces, handle, NULL);
    int st = gbinder_servicemanager_add_service_sync(sm, "default", obj);
    if (st != GBINDER_STATUS_OK) {
        fprintf(stderr, "registering " NETD_1_1 "/default failed: %d\n", st);
        return 2;
    }
    fprintf(stderr, "registered " NETD_1_1 "/default\n");
    loop = g_main_loop_new(NULL, FALSE);
    gbinder_servicemanager_add_presence_handler(sm, on_presence, NULL);
    g_unix_signal_add(SIGTERM, on_signal, NULL);
    g_unix_signal_add(SIGINT, on_signal, NULL);
    g_main_loop_run(loop);
    gbinder_local_object_drop(obj);
    gbinder_servicemanager_unref(sm);
    return 0;
}
