/*
 * cepheus-hostless-pcm DEVICE p|c RATE CHANNELS
 *
 * Open a "hostless" ALSA PCM (a DSP-to-DSP link such as SLIMBUS_2 Hostless),
 * start it and keep it running without reading or writing any samples, until
 * SIGTERM/SIGINT.  This is what tinyalsa's pcm_start() does for Qualcomm's
 * hostless front ends; arecord/aplay cannot, because they transfer data and
 * a hostless PCM never delivers or consumes any (reads fail with EIO).
 */
#include <alsa/asoundlib.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static volatile sig_atomic_t stop;
static void on_sig(int s) { (void)s; stop = 1; }

int main(int argc, char **argv)
{
    if (argc < 5) {
        fprintf(stderr, "usage: %s hw:0,37 p|c rate channels\n", argv[0]);
        return 2;
    }
    snd_pcm_stream_t dir = argv[2][0] == 'p' ? SND_PCM_STREAM_PLAYBACK : SND_PCM_STREAM_CAPTURE;
    unsigned rate = atoi(argv[3]), ch = atoi(argv[4]);
    snd_pcm_t *pcm;
    int r = snd_pcm_open(&pcm, argv[1], dir, 0);
    if (r < 0) { fprintf(stderr, "open %s: %s\n", argv[1], snd_strerror(r)); return 1; }

    snd_pcm_hw_params_t *hw;
    snd_pcm_hw_params_alloca(&hw);
    snd_pcm_hw_params_any(pcm, hw);
    snd_pcm_hw_params_set_access(pcm, hw, SND_PCM_ACCESS_RW_INTERLEAVED);
    snd_pcm_hw_params_set_format(pcm, hw, SND_PCM_FORMAT_S16_LE);
    snd_pcm_hw_params_set_channels(pcm, hw, ch);
    snd_pcm_hw_params_set_rate(pcm, hw, rate, 0);
    snd_pcm_uframes_t period = rate / 100, buffer = period * 4;
    snd_pcm_hw_params_set_period_size_near(pcm, hw, &period, 0);
    snd_pcm_hw_params_set_buffer_size_near(pcm, hw, &buffer);
    if ((r = snd_pcm_hw_params(pcm, hw)) < 0) { fprintf(stderr, "hw_params: %s\n", snd_strerror(r)); return 1; }

    snd_pcm_sw_params_t *sw;
    snd_pcm_uframes_t boundary;
    snd_pcm_sw_params_alloca(&sw);
    snd_pcm_sw_params_current(pcm, sw);
    snd_pcm_sw_params_get_boundary(sw, &boundary);
    snd_pcm_sw_params_set_start_threshold(pcm, sw, 1);
    snd_pcm_sw_params_set_stop_threshold(pcm, sw, boundary);   /* never xrun */
    if (dir == SND_PCM_STREAM_PLAYBACK) {
        snd_pcm_sw_params_set_silence_threshold(pcm, sw, 0);
        snd_pcm_sw_params_set_silence_size(pcm, sw, boundary);
    }
    if ((r = snd_pcm_sw_params(pcm, sw)) < 0) { fprintf(stderr, "sw_params: %s\n", snd_strerror(r)); return 1; }

    if ((r = snd_pcm_prepare(pcm)) < 0) { fprintf(stderr, "prepare: %s\n", snd_strerror(r)); return 1; }
    if ((r = snd_pcm_start(pcm)) < 0) { fprintf(stderr, "start: %s\n", snd_strerror(r)); return 1; }
    fprintf(stderr, "%s %s started (%u Hz, %u ch)\n", argv[1], argv[2], rate, ch);

    signal(SIGTERM, on_sig);
    signal(SIGINT, on_sig);
    while (!stop)
        pause();
    snd_pcm_drop(pcm);
    snd_pcm_close(pcm);
    return 0;
}
