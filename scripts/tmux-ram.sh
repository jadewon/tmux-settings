#!/bin/bash
# RAM 표시: macOS Activity Monitor 정의 % / 기존 tmux-cpu 식 % (참고용)
# 색상: memory_pressure 휴리스틱 기반 (swap, compressor)

# vm_stat 파싱 (페이지 사이즈 시스템에서 직접 조회 — Apple Silicon 16384, Intel 4096)
PAGE_SIZE=$(/usr/bin/pagesize 2>/dev/null || sysctl -n vm.pagesize 2>/dev/null || echo 16384)
STATS=$(/usr/bin/vm_stat)

get() { echo "$STATS" | grep -E "^$1" | grep -Eo '[0-9]+'; }

active=$(get "Pages active")
inactive=$(get "Pages inactive")
speculative=$(get "Pages speculative")
wired=$(get "Pages wired down")
compressor=$(get "Pages occupied by compressor")
purgeable=$(get "Pages purgeable")
file_backed=$(get "File-backed pages")
free=$(get "Pages free")

total_pages=$((active + inactive + speculative + wired + compressor + free))

# B: macOS Activity Monitor 정의 — Memory Used = active + wired + compressor
macos_used=$((active + wired + compressor))
macos_pct=$((macos_used * 100 / total_pages))

# A: 기존 tmux-cpu 플러그인 식 — inactive/speculative 도 used 로 잡음
plugin_used_and_cached=$((active + inactive + speculative + wired + compressor))
plugin_cached=$((purgeable + file_backed))
plugin_used=$((plugin_used_and_cached - plugin_cached))
plugin_pct=$((plugin_used * 100 / total_pages))

# C: 색상은 memory_pressure 휴리스틱
# swap 사용량 (MB)
swap_used_mb=$(sysctl -n vm.swapusage 2>/dev/null | grep -oE 'used = [0-9.]+M' | grep -oE '[0-9.]+' | head -1)
swap_used_int=${swap_used_mb%.*}
: ${swap_used_int:=0}

# compressor 크기 (GB × 10)
compressor_gb_x10=$((compressor * PAGE_SIZE * 10 / 1024 / 1024 / 1024))

# 임계 판정 (memory pressure 휴리스틱)
if [ "$swap_used_int" -gt 1024 ] || [ "$compressor_gb_x10" -gt 100 ]; then
  COLOR="colour196"   # red
elif [ "$swap_used_int" -gt 0 ] || [ "$compressor_gb_x10" -gt 50 ]; then
  COLOR="yellow"
else
  COLOR="colour76"    # green
fi

printf '#[fg=%s]%d%%/%d%%#[fg=colour250]' "$COLOR" "$macos_pct" "$plugin_pct"
