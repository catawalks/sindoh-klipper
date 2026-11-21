// regwatch - watch hardware registers change on a running stock system.
//
// Read-only: maps /dev/mem with PROT_READ and never writes. Made for the
// 3DWOX 1X (88PA6270) to see which GPIO lines and stepper-engine registers
// move when the stock firmware jogs or homes an axis.
//
//   regwatch [seconds]
//
// Once a second it prints, with the uptime:
//   G<bank> bit(toggles) ...   GPIO level bits that changed, with how often
//   S<block> +off old>new ...  stepper engine registers that changed
//   P<block> ctrl high low     PWM blocks that changed
// GPIO is sampled as fast as the loop runs (fast pulses are undercounted,
// but a stepping pin still shows up as a large count).
//
// Build: arm-linux-gnueabihf-gcc -O2 -static -o regwatch regwatch.c
//
// Copyright (C) 2026  This file may be distributed under the terms of the
// GNU GPLv3 license.

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define GPIO_BASE 0xd4019000u
#define GPIO_BANKS 8
#define SMOT_BASE 0xf8150000u
#define SMOT_BLOCKS 6
// Only registers our DP200 tools already read on a live system (1X offsets
// = DP200 + 0x28): block enable, config, control (direction), status,
// edge counter. Others might clear on read.
static const uint16_t smot_offs[] = { 0x00, 0x34, 0x6c, 0x8c, 0xa0 };
#define SMOT_WORDS (sizeof(smot_offs) / sizeof(smot_offs[0]))
#define PWM_BASE 0xf9304000u
#define PWM_BLOCKS 32

static volatile uint32_t *
map(int fd, uint32_t addr, size_t len)
{
    void *p = mmap(NULL, len, PROT_READ, MAP_SHARED, fd, addr);
    if (p == MAP_FAILED) {
        perror("mmap");
        exit(1);
    }
    return p;
}

static double
now(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
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
    volatile uint32_t *gp = map(fd, GPIO_BASE, 0x1000);
    volatile uint32_t *sm = map(fd, SMOT_BASE, 0x1000 * SMOT_BLOCKS);
    volatile uint32_t *pw = map(fd, PWM_BASE, 0x3000);
    uint32_t glast[GPIO_BANKS], gcnt[GPIO_BANKS][32];
    static uint32_t slast[SMOT_BLOCKS][8];
    static uint32_t plast[PWM_BLOCKS + 1][3];
    memset(gcnt, 0, sizeof(gcnt));
    for (int b = 0; b < GPIO_BANKS; b++) {
        glast[b] = gp[b * 0x40];
        printf("BASE G%d %08x\n", b, glast[b]);
    }
    for (int n = 0; n < SMOT_BLOCKS; n++) {
        printf("BASE S%d", n);
        for (unsigned w = 0; w < SMOT_WORDS; w++) {
            slast[n][w] = sm[n * 0x400 + smot_offs[w] / 4];
            printf(" %x", slast[n][w]);
        }
        printf("\n");
    }
    for (int n = 1; n <= PWM_BLOCKS; n++) {
        plast[n][0] = pw[n * 0x40];
        plast[n][1] = pw[n * 0x40 + 2];
        plast[n][2] = pw[n * 0x40 + 3];
    }
    double t0 = now(), tick = t0 + 1;
    unsigned long loops = 0;
    for (;;) {
        for (int b = 0; b < GPIO_BANKS; b++) {
            uint32_t v = gp[b * 0x40], d = v ^ glast[b];
            if (d) {
                glast[b] = v;
                while (d) {
                    int i = __builtin_ctz(d);
                    gcnt[b][i]++;
                    d &= d - 1;
                }
            }
        }
        loops++;
        if ((loops & 0x3f) != 0)
            continue;
        double t = now();
        if (t < tick)
            continue;
        tick += 1;
        char line[4096];
        int len = 0;
        for (int b = 0; b < GPIO_BANKS; b++) {
            int any = 0;
            for (int i = 0; i < 32; i++)
                if (gcnt[b][i]) {
                    if (!any)
                        len += snprintf(line + len, sizeof(line) - len, " G%d", b);
                    any = 1;
                    len += snprintf(line + len, sizeof(line) - len, " %d(%u)",
                                    b * 32 + i, gcnt[b][i]);
                    gcnt[b][i] = 0;
                }
        }
        for (int n = 0; n < SMOT_BLOCKS; n++) {
            int any = 0;
            for (unsigned w = 0; w < SMOT_WORDS; w++) {
                uint32_t v = sm[n * 0x400 + smot_offs[w] / 4];
                if (v != slast[n][w] && len < 3800) {
                    if (!any)
                        len += snprintf(line + len, sizeof(line) - len, " S%d", n);
                    any = 1;
                    len += snprintf(line + len, sizeof(line) - len, " +%x %x>%x",
                                    smot_offs[w], slast[n][w], v);
                    slast[n][w] = v;
                }
            }
        }
        for (int n = 1; n <= PWM_BLOCKS; n++) {
            uint32_t c = pw[n * 0x40], h = pw[n * 0x40 + 2], l = pw[n * 0x40 + 3];
            // heater duty moves every second: only report run/level changes
            if (c != plast[n][0] && len < 3900)
                len += snprintf(line + len, sizeof(line) - len, " P%d %x>%x %u/%u",
                                n, plast[n][0], c, h, l);
            plast[n][0] = c;
            plast[n][1] = h;
            plast[n][2] = l;
        }
        if (len)
            printf("%.1f%s\n", t, line);
        fflush(stdout);
        if (t - t0 > secs)
            break;
    }
    printf("DONE loops/s %.0f\n", loops / (now() - t0));
    return 0;
}
