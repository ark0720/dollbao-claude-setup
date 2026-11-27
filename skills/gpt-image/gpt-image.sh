#!/usr/bin/env bash
# gpt-image.sh — 透過 Codex CLI（ChatGPT 訂閱登入，非 API key）呼叫 GPT Image 生圖。
#
# 用法:
#   gpt-image.sh -o <輸出.png> [-r <參考圖>]... [-m <model>] [-p "<prompt>"]
#   prompt 也可從 stdin 傳入（長 prompt / 中文建議用 stdin 或 -f <prompt 檔>）
#
# 結束碼: 0 成功；1 參數錯誤；2 找不到 codex；3 未登入；4 沒產出圖片
set -u

OUT="" ; PROMPT="" ; PROMPT_FILE="" ; REFS=()
MODEL="${GPT_IMAGE_MODEL:-gpt-6.2-sol}"

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--out)    OUT="$2"; shift 2 ;;
    -p|--prompt) PROMPT="$2"; shift 2 ;;
    -f|--file)   PROMPT_FILE="$2"; shift 2 ;;
    -r|--ref)    REFS+=("$2"); shift 2 ;;
    -m|--model)  MODEL="$2"; shift 2 ;;
    *) echo "未知參數: $1" >&2; exit 1 ;;
  esac
done

[ -z "$OUT" ] && { echo "缺少 -o <輸出路徑>" >&2; exit 1; }
if [ -n "$PROMPT_FILE" ]; then PROMPT="$(cat "$PROMPT_FILE")"; fi
if [ -z "$PROMPT" ] && [ ! -t 0 ]; then PROMPT="$(cat)"; fi
[ -z "$PROMPT" ] && { echo "缺少 prompt（-p / -f / stdin）" >&2; exit 1; }

# --- 找 codex.exe：PATH → Codex 桌面版（WindowsApps，版本號會隨更新變動）---
CX="$(command -v codex 2>/dev/null || true)"
if [ -z "$CX" ]; then
  LOC="$(powershell.exe -NoProfile -Command "(Get-AppxPackage -Name OpenAI.Codex | Sort-Object Version | Select-Object -Last 1).InstallLocation" 2>/dev/null | tr -d '\r')"
  [ -n "$LOC" ] && CX="$(cygpath -u "$LOC")/app/resources/codex.exe"
fi
[ -x "$CX" ] || { echo "找不到 codex.exe（請安裝 Codex 桌面版或 npm i -g @openai/codex）" >&2; exit 2; }

"$CX" login status 2>&1 | grep -qi "ChatGPT" || { echo "Codex 尚未用 ChatGPT 帳號登入，請先開 Codex 桌面版登入" >&2; exit 3; }

GEN_DIR="$HOME/.codex/generated_images"
WORK="$(mktemp -d)"
MARK="$WORK/.mark"; touch "$MARK"
LOG="$WORK/codex.log"

ARGS=(exec --skip-git-repo-check -s read-only -m "$MODEL" -c 'model_reasoning_effort="low"' -C "$WORK")
for r in "${REFS[@]}"; do ARGS+=(-i "$(cygpath -w "$r")"); done

INSTR="Use your built-in image generation tool (not code, not scripts) to generate exactly ONE image following the brief below.
If reference images are attached, use them as the visual reference (keep the product's shape, colors and details faithful).
Do not run any shell commands. Do not copy or move files. After the image is generated, reply only with: DONE

=== BRIEF ===
$PROMPT"

printf '%s' "$INSTR" | "$CX" "${ARGS[@]}" > "$LOG" 2>&1
RC=$?

NEW="$(find "$GEN_DIR" -type f -name '*.png' -newer "$MARK" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
if [ -z "$NEW" ]; then
  echo "沒有產出圖片（codex exit=$RC）。log 尾段：" >&2
  tail -15 "$LOG" >&2
  exit 4
fi

mkdir -p "$(dirname "$OUT")"
cp "$NEW" "$OUT"
echo "$OUT"
rm -rf "$WORK"
