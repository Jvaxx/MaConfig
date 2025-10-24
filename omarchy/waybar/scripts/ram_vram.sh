#!/usr/bin/env bash
# ~/.config/waybar/scripts/ram_vram.sh

# RAM used GiB (1 décimale)
read -r MEM_TOTAL_KB MEM_AVAIL_KB < <(awk '/MemTotal:/{t=$2}/MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo)
USED_KB=$((MEM_TOTAL_KB - MEM_AVAIL_KB))
RAM_GIB=$(awk -v k="$USED_KB" 'BEGIN{printf("%.1f", k/1024/1024)}')

# VRAM used GiB (1 décimale)
VRAM_GIB="0.0"

if command -v nvidia-smi >/dev/null 2>&1; then
  USED_MIB=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -n1)
  if [ -n "$USED_MIB" ]; then
    VRAM_GIB=$(awk -v m="$USED_MIB" 'BEGIN{printf("%.1f", m/1024)}')
  fi
else
  FILE=$(ls -1 /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | head -n1)
  if [ -n "$FILE" ] && [ -r "$FILE" ]; then
    USED_BYTES=$(cat "$FILE")
    VRAM_GIB=$(awk -v b="$USED_BYTES" 'BEGIN{printf("%.1f", b/1024/1024/1024)}')
  fi
fi

echo "{\"text\": \"${RAM_GIB}/${VRAM_GIB}\"}"

