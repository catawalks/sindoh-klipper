#!/bin/sh
# Log changes of the eight GPIO level registers (read-only), with uptime.
# Bits that toggle by themselves in the first passes are masked out.
for b in 0 1 2 3 4 5 6 7; do eval p$b=$(devmem $((0xd4019000 + b*256))); eval m$b=0; done
n=0
while [ $n -lt 150 ]; do
  for b in 0 1 2 3 4 5 6 7; do
    v=$(devmem $((0xd4019000 + b*256))); eval o=\$p$b; eval m=\$m$b
    eval m$b=$(( m | (v ^ o) )); eval p$b=$v
  done
  n=$((n+1))
done
for b in 0 1 2 3 4 5 6 7; do eval m=\$m$b; eval o=\$p$b; printf "BASE %d level %08x noisy %08x\n" $b $((o)) $m; eval p$b=$(( o & ~m )); done
echo "READY $(cut -d' ' -f1 /proc/uptime)"
while [ ! -f /tmp/x1/gpiolog.stop ]; do
  for b in 0 1 2 3 4 5 6 7; do
    eval m=\$m$b; eval o=\$p$b
    v=$(( $(devmem $((0xd4019000 + b*256))) & ~m ))
    if [ $v -ne $o ]; then printf "%s bank %d changed %08x now %08x\n" $(cut -d' ' -f1 /proc/uptime) $b $((v ^ o)) $v; eval p$b=$v; fi
  done
done
