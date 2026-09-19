#!/bin/sh
PREREQ=""

prereqs() {
    echo "$PREREQ"
}

case $1 in
prereqs)
    prereqs
    exit 0
    ;;
esac

ZRAM_PERCENT=""
for x in $(cat /proc/cmdline); do
    case $x in
    custom_zram_percent=*)
        ZRAM_PERCENT="${x#custom_zram_percent=}"
        ;;
    esac
done

# -------------- check zram percent

[ -n "$ZRAM_PERCENT" ] || exit 0

case "$ZRAM_PERCENT" in
    *[!0-9]*) exit 0 ;;
esac

[ "$ZRAM_PERCENT" -gt 0 ]   || exit 0
[ "$ZRAM_PERCENT" -le 100 ] || ZRAM_PERCENT=100

# --------------

modprobe zram num_devices=1 || exit 0
[ -e /dev/zram0 ] || exit 0

mem_total_kb=$(/nativeawk '/^MemTotal:/ {print $2}' /proc/meminfo)
zram_size_mb=$(( mem_total_kb * ZRAM_PERCENT / 100 / 1024 ))

[ "$zram_size_mb" -gt 0 ] || exit 0

echo "zram: ${zram_size_mb}M (${ZRAM_PERCENT}% of RAM)"

if [ -e /sys/block/zram0/comp_algorithm ]; then
    for algo in zstd lz4 lzo lz4hc; do
        if grep -qw "$algo" /sys/block/zram0/comp_algorithm; then
            echo "$algo" > /sys/block/zram0/comp_algorithm 2>/dev/null && break
        fi
    done
fi

echo "${zram_size_mb}M" > /sys/block/zram0/disksize || exit 0

mkswap /dev/zram0 >/dev/null 2>&1
swapon /dev/zram0 || exit 0
