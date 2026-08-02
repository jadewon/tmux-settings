#!/bin/bash
# tmux-resurrect post-save hook
# 각 pane의 claude 프로세스를 추적해서 saved 명령줄을
# 'claude --dangerously-skip-permissions --resume <sessionId>' 로 치환
# /rename 후에도 안전 — sessionId는 영구 불변

# 로그는 홈 아래. /tmp 는 world-writable 이라 다른 로컬 사용자가 이 경로에 심볼릭 링크를 미리
# 심어둘 수 있고, 로그에는 claude sessionId 가 그대로 남는다.
LOG_DIR="$HOME/.local/state"
LOG="$LOG_DIR/tmux-resurrect-rewrite.log"
mkdir -p "$LOG_DIR"
exec 2>>"$LOG"
echo "--- $(date '+%F %T') rewrite start ---" >&2

LATEST=$(ls -t ~/.local/share/tmux/resurrect/tmux_resurrect_*.txt 2>/dev/null | head -1)
[ -z "$LATEST" ] && { echo "no resurrect file" >&2; exit 0; }
echo "target: $LATEST" >&2

JQ=/usr/bin/jq
MAP=$(mktemp)
TMP=""
# 종료 시점에 평가되도록 작은따옴표. TMP 는 아직 비어 있을 수 있어 ${TMP:+…} 로 인자 자체를 뺀다
trap 'rm -f "$MAP" ${TMP:+"$TMP"}' EXIT

# tmux pane → claude PID → sessionId 매핑을 줄별 파일로 저장
# 형식: session|window|pane_idx<TAB>uuid
tmux list-panes -a -F '#{session_name}	#{window_index}	#{pane_index}	#{pane_pid}	#{pane_current_command}' 2>/dev/null \
| while IFS=$'\t' read -r session window_idx pane_idx pane_pid pane_cmd; do
    # claude 실행 중인 pane 만. Claude Code 는 프로세스 타이틀을 자기 버전 문자열로 바꾸므로
    # pane_current_command 가 "2.1.220" 처럼 보인다 — 그래서 "claude" 와 "2.*" 를 같이 잡는다.
    case "$pane_cmd" in
      2.*|claude)
        claude_pid=""
        if [ -f "$HOME/.claude/sessions/${pane_pid}.json" ]; then
          claude_pid="$pane_pid"
        else
          for child in $(pgrep -P "$pane_pid" 2>/dev/null); do
            if [ -f "$HOME/.claude/sessions/${child}.json" ]; then
              claude_pid="$child"
              break
            fi
          done
        fi
        if [ -n "$claude_pid" ]; then
          uuid=$($JQ -r '.sessionId // empty' "$HOME/.claude/sessions/${claude_pid}.json" 2>/dev/null)
          if [ -n "$uuid" ]; then
            printf '%s|%s|%s\t%s\n' "$session" "$window_idx" "$pane_idx" "$uuid" >> "$MAP"
            echo "  pane ${session}:${window_idx}.${pane_idx} → pid=$claude_pid → $uuid" >&2
          fi
        fi
        ;;
    esac
  done

# 라인 수 세기. wc -l 은 개행으로 끝나지 않는 마지막 줄을 세지 않아 아래 가드가 헛돈다
count_lines() { awk 'END{print NR}' "$1"; }

# resurrect 파일의 pane 행 치환
# read 는 개행 없이 끝나는 마지막 줄에 non-zero 를 반환하므로 '|| [ -n "$line" ]' 없이는 그 줄이 통째로 사라진다
TMP=$(mktemp)
while IFS= read -r line || [ -n "$line" ]; do
  if [[ "$line" == pane$'\t'* ]]; then
    IFS=$'\t' read -ra fields <<< "$line"
    session="${fields[1]}"
    window="${fields[2]}"
    pane_idx="${fields[5]}"
    cmd_field="${fields[10]}"
    if [[ "$cmd_field" == *claude* ]]; then
      key="${session}|${window}|${pane_idx}"
      uuid=$(awk -F'\t' -v k="$key" '$1==k {print $2; exit}' "$MAP")
      if [ -n "$uuid" ]; then
        fields[10]=":claude --dangerously-skip-permissions --resume $uuid"
        line=$(printf '%s\t' "${fields[@]}")
        line="${line%$'\t'}"
        echo "  rewrote $key → --resume $uuid" >&2
      fi
    fi
  fi
  printf '%s\n' "$line"
done < "$LATEST" > "$TMP"

# 라인 수가 원본과 정확히 같을 때만 교체. 모든 입력 라인을 무조건 다시 출력하므로 수가 달라졌다면
# 중간에 깨진 것이고, 그대로 덮으면 resurrect 저장본이 통째로 날아간다.
if [ "$(count_lines "$TMP")" -eq "$(count_lines "$LATEST")" ]; then
  mv "$TMP" "$LATEST"
  echo "--- done ---" >&2
else
  rm -f "$TMP"
  echo "!!! aborted: line count mismatch — resurrect file left untouched" >&2
fi
