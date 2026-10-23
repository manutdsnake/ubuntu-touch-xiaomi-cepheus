/*
 * cepheus-hidl-primary-out [device-type]
 *
 * Open the audio HAL's primary output over HIDL (android.hardware.audio@7.0)
 * and hold it until SIGTERM, the way Android's AudioFlinger keeps one open.
 * Xiaomi's 32-bit HAL (vendor.audio-hal) needs a primary output before it can
 * start the Elliptic ultrasound RX path; Ubuntu Touch has no AudioFlinger.
 *
 * Layouts follow android.hardware.audio.common@7.0 (64-bit):
 *   DeviceAddress 40 bytes  { string deviceType; safe_union address (0 = id) }
 *   AudioConfig  176 bytes  { AudioConfigBase base (40); safe_union offload
 *                             (128, left "unspecified"); uint64 frameCount }
 * A wrong layout makes the HAL reject the buffers (BAD_VALUE), nothing more.
 */
#include <gbinder/gbinder.h>
#include <glib-unix.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define FACTORY "android.hardware.audio@7.0::IDevicesFactory"
/* openOutputStream is an IDevice method: its stub enforces the IDevice
 * descriptor even on an IPrimaryDevice object (BAD_TYPE otherwise). */
#define DEVICE "android.hardware.audio@7.0::IDevice"
#define CODE_OPEN_PRIMARY_DEVICE 2
#define CODE_OPEN_OUTPUT_STREAM 9

static void hstr(void *base, size_t off, const char *s)
{
    GBinderHidlString *h = (GBinderHidlString *)((char *)base + off);
    h->data.str = s;
    h->len = strlen(s);
    h->owns_buffer = TRUE;
}

static void hstr_data(GBinderWriter *w, guint32 parent, guint32 off, const char *s)
{
    GBinderParent p = { parent, off };
    gbinder_writer_append_buffer_object_with_parent(w, s, strlen(s) + 1, &p);
}

static GMainLoop *loop;
static int exit_code;

static gboolean on_signal(gpointer data) { (void)data; g_main_loop_quit(loop); return G_SOURCE_REMOVE; }

static void on_death(GBinderRemoteObject *obj, void *data)
{
    (void)obj;
    fprintf(stderr, "%s died\n", (const char *)data);
    exit_code = 3;              /* let systemd restart us against the new HAL */
    g_main_loop_quit(loop);
}

int main(int argc, char **argv)
{
    const char *devtype = argc > 1 ? argv[1] : "AUDIO_DEVICE_OUT_SPEAKER";
    const char *fmt = "AUDIO_FORMAT_PCM_16_BIT";
    const char *mask = "AUDIO_CHANNEL_OUT_STEREO";
    const char *flag = "AUDIO_OUTPUT_FLAG_PRIMARY";
    int st = 0;
    gint32 hst = -1, res = -1;

    GBinderServiceManager *sm = gbinder_servicemanager_new("/dev/hwbinder");
    GBinderRemoteObject *fac = sm ? gbinder_servicemanager_get_service_sync(sm, FACTORY "/default", &st) : NULL;
    if (!fac) { fprintf(stderr, "no %s (status %d)\n", FACTORY, st); return 1; }

    GBinderClient *fc = gbinder_client_new(fac, FACTORY);
    GBinderLocalRequest *rq = gbinder_client_new_request(fc);
    GBinderRemoteReply *rp = gbinder_client_transact_sync_reply(fc, CODE_OPEN_PRIMARY_DEVICE, rq, &st);
    GBinderReader r;
    if (!rp) { fprintf(stderr, "openPrimaryDevice: transact %d\n", st); return 1; }
    gbinder_remote_reply_init_reader(rp, &r);
    gbinder_reader_read_int32(&r, &hst);
    gbinder_reader_read_int32(&r, &res);
    GBinderRemoteObject *dev = gbinder_reader_read_object(&r);
    printf("openPrimaryDevice: status %d result %d device %p\n", hst, res, (void *)dev);
    if (!dev) return 1;

    GBinderClient *dc = gbinder_client_new(dev, DEVICE);
    rq = gbinder_client_new_request(dc);
    GBinderWriter w;
    gbinder_local_request_init_writer(rq, &w);

    gbinder_writer_append_int32(&w, 13);                    /* AudioIoHandle */

    static guint8 addr[40];                                  /* DeviceAddress */
    hstr(addr, 0, devtype);
    /* address @0x10: hidl_d 0 is "string id" in the generated safe_union
     * (readEmbeddedFromParcel reads a string at +0x18 when it is 0) */
    hstr(addr, 0x18, "");
    guint32 ai = gbinder_writer_append_buffer_object(&w, addr, sizeof(addr));
    hstr_data(&w, ai, 0, devtype);
    hstr_data(&w, ai, 0x18, "");

    static guint8 cfg[176];                                  /* AudioConfig */
    hstr(cfg, 0, fmt);
    *(guint32 *)(cfg + 16) = 48000;
    hstr(cfg, 24, mask);                                     /* offloadInfo @40: unspecified */
    guint32 ci = gbinder_writer_append_buffer_object(&w, cfg, sizeof(cfg));
    hstr_data(&w, ci, 0, fmt);
    hstr_data(&w, ci, 24, mask);

    static GBinderHidlString flags[1];                       /* vec<AudioInOutFlag> */
    static GBinderHidlVec fv;
    hstr(flags, 0, flag);
    fv.data.ptr = flags; fv.count = 1; fv.owns_buffer = TRUE;
    guint32 vi = gbinder_writer_append_buffer_object(&w, &fv, sizeof(fv));
    GBinderParent vp = { vi, 0 };
    guint32 fi = gbinder_writer_append_buffer_object_with_parent(&w, flags, sizeof(flags), &vp);
    hstr_data(&w, fi, 0, flag);

    static GBinderHidlVec tracks;                            /* SourceMetadata { vec tracks } */
    static guint8 empty[8];
    tracks.data.ptr = empty; tracks.count = 0; tracks.owns_buffer = TRUE;
    guint32 mi = gbinder_writer_append_buffer_object(&w, &tracks, sizeof(tracks));
    GBinderParent mp = { mi, 0 };
    gbinder_writer_append_buffer_object_with_parent(&w, empty, 0, &mp);

    rp = gbinder_client_transact_sync_reply(dc, CODE_OPEN_OUTPUT_STREAM, rq, &st);
    if (!rp) { fprintf(stderr, "openOutputStream: transact %d\n", st); return 1; }
    gbinder_remote_reply_init_reader(rp, &r);
    hst = res = -1;
    gbinder_reader_read_int32(&r, &hst);
    gbinder_reader_read_int32(&r, &res);
    GBinderRemoteObject *out = gbinder_reader_read_object(&r);
    printf("openOutputStream(%s): status %d result %d stream %p\n", devtype, hst, res, (void *)out);
    fflush(stdout);
    if (!out || res != 0) return 2;

    loop = g_main_loop_new(NULL, FALSE);
    g_unix_signal_add(SIGTERM, on_signal, NULL);
    g_unix_signal_add(SIGINT, on_signal, NULL);
    gbinder_remote_object_add_death_handler(dev, on_death, "audio HAL device");
    gbinder_remote_object_add_death_handler(out, on_death, "primary output stream");
    g_main_loop_run(loop);
    printf("closing\n");
    return exit_code;
}
