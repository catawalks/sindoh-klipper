// movewatch - record every move of a running stock 3DWOX 1X, move by move.
//
// Read-only: maps /dev/mem with PROT_READ and never writes. Where
// regwatch prints totals once a second, this follows the step and
// direction pins of each motor in a tight loop and prints one line per
// move (a run of steps in one direction), so a homing or a wipe can be
// read back exactly. It also prints every change of the home, filament
// and leveling inputs and of the fan, lamp, beeper and solenoid outputs.
//
//   movewatch [seconds]
//
// Lines (times are seconds of uptime):
//   M <start> <end> <axis> <dir pin level> <steps> <mm>
//   I <time> <name> <level>
//   P <time> <block> <ctrl> <high>/<low>
// Steps faster than the loop are lost; the loop takes a few microseconds.
//
// Build: gcc -O2 -static -o movewatch movewatch.c
//
// Copyright (C) 2026  This file may be distributed under the terms of the
// GNU GPLv3 license.

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define GPIO_BASE 0xd4019000u
#define PWM_BASE 0xf9304000u

struct axis { const char *name; int step, dir; double spm;
              int last, d, moving; long n; double t0, tl; };
static struct axis ax[] = {
    {"X", 162, 163, 80.0}, {"Y", 168, 169, 80.4}, {"Z", 36, 37, 2560.0},
    {"E", 42, 43, 458.8}, {"C", 48, 49, 220.35},
};
struct input { const char *name; int gpio, last; };
static struct input in[] = {
    {"x_home", 99}, {"y_home", 82}, {"z_home", 83}, {"extruder_entry", 120},
    {"bay", 80}, {"level_contact", 81}, {"level_enable", 153}, {"nozzle_voltage", 69},
};
static const int pwm_blocks[] = { 2, 7, 8, 10, 14, 18, 19, 20, 22, 24, 26 };
#define NAX (sizeof(ax) / sizeof(ax[0]))
#define NIN (sizeof(in) / sizeof(in[0]))
#define NPW (sizeof(pwm_blocks) / sizeof(pwm_blocks[0]))

static volatile uint32_t *gp, *pw;

static double
now(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static void
end_move(struct axis *a)
{
    if (a->n)
        printf("M %.3f %.3f %s %d %ld %.2f\n", a->t0, a->tl, a->name, a->d,
               a->n, a->n / a->spm);
    a->n = 0;
    a->moving = 0;
}

int
main(int argc, char **argv)
{
    double secs = argc > 1 ? atof(argv[1]) : 60;
    int fd = open("/dev/mem", O_RDONLY | O_SYNC);
    if (fd < 0) {
        perror("/dev/mem");
        return 1;
    }
    gp = mmap(NULL, 0x1000, PROT_READ, MAP_SHARED, fd, GPIO_BASE);
    pw = mmap(NULL, 0x3000, PROT_READ, MAP_SHARED, fd, PWM_BASE);
    if (gp == MAP_FAILED || pw == MAP_FAILED) {
        perror("mmap");
        return 1;
    }
    setvbuf(stdout, NULL, _IOLBF, 0);
    uint32_t g[8], plast[NPW][3];
    unsigned i, loops = 0;
    double t = now(), tend = t + secs;
    for (i = 0; i < 8; i++)
        g[i] = gp[i * 0x40];
    for (i = 0; i < NAX; i++)
        ax[i].last = (g[ax[i].step / 32] >> (ax[i].step % 32)) & 1;
    for (i = 0; i < NIN; i++) {
        in[i].last = (g[in[i].gpio / 32] >> (in[i].gpio % 32)) & 1;
        printf("I %.3f %s %d\n", t, in[i].name, in[i].last);
    }
    for (i = 0; i < NPW; i++) {
        volatile uint32_t *b = pw + pwm_blocks[i] * 0x40;
        plast[i][0] = b[0]; plast[i][1] = b[2]; plast[i][2] = b[3];
        printf("P %.3f %d %x %u/%u\n", t, pwm_blocks[i], b[0], b[2], b[3]);
    }
    while (t < tend) {
        g[1] = gp[1 * 0x40];
        g[5] = gp[5 * 0x40];
        if (!(loops & 15))
            t = now();
        for (i = 0; i < NAX; i++) {
            struct axis *a = &ax[i];
            int s = (g[a->step / 32] >> (a->step % 32)) & 1;
            if (s != a->last) {
                a->last = s;
                if (s) {
                    int d = (g[a->dir / 32] >> (a->dir % 32)) & 1;
                    if (a->moving && d != a->d)
                        end_move(a);
                    if (!a->moving) {
                        a->moving = 1;
                        a->d = d;
                        a->t0 = t;
                    }
                    a->n++;
                    a->tl = t;
                }
            } else if (a->moving && t - a->tl > 0.03) {
                end_move(a);
            }
        }
        if (!(loops & 255)) {
            g[2] = gp[2 * 0x40];
            g[3] = gp[3 * 0x40];
            g[4] = gp[4 * 0x40];
            for (i = 0; i < NIN; i++) {
                int v = (g[in[i].gpio / 32] >> (in[i].gpio % 32)) & 1;
                if (v != in[i].last) {
                    in[i].last = v;
                    printf("I %.3f %s %d\n", t, in[i].name, v);
                }
            }
        }
        if (!(loops & 16383)) {
            for (i = 0; i < NPW; i++) {
                volatile uint32_t *b = pw + pwm_blocks[i] * 0x40;
                uint32_t c = b[0], h = b[2], l = b[3];
                if (c != plast[i][0] || h != plast[i][1] || l != plast[i][2]) {
                    plast[i][0] = c; plast[i][1] = h; plast[i][2] = l;
                    printf("P %.3f %d %x %u/%u\n", t, pwm_blocks[i], c, h, l);
                }
            }
        }
        loops++;
    }
    for (i = 0; i < NAX; i++)
        end_move(&ax[i]);
    printf("END %.3f loops %u\n", t, loops);
    return 0;
}
