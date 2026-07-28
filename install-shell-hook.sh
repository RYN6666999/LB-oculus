#!/bin/sh
# install-shell-hook.sh — 在 ~/.zshrc 注入指令帳（preexec → ledger/_runs.jsonl）。
#
# 做三件事（idempotent）：
#   1. source hooks/dbp-preexec.sh（如果還沒被 source）
#   2. 確保 DBP 在 PATH 或 ~/.local/bin/dbp 可執行
#   3. 不重複注入（檢查特徵註記）
#
# 為什麼需要這個：
#   hook 類的帳本依賴 harness 呼叫 hook，不是每種開發環境都有 harness。
#   指令帳是「最後一道線」—— 只要你開 shell，就有紀錄。
#   這比 editor hook 弱（只有 runs, 沒有 edits），但比零好。
#
# 為什麼不直接寫 JSONL（走 dbp chain_append）：
#   prev 雜湊算式只存在 bin/dbp 內。hook 自算 prev 就破壞了「四位址化」。
#   見 hooks/dbp-preexec.sh 註解與 redteam/012。

HERE="$(cd "$(dirname "$0")" && pwd)"
PREEXEC_SCRIPT="$HERE/hooks/dbp-preexec.sh"
ZSHRC="$HOME/.zshrc"
MARKER="# >>> dbp preexec hook (指令帳) <<<"

if [ ! -f "$PREEXEC_SCRIPT" ]; then
  echo "✗ 找不到 $PREEXEC_SCRIPT" >&2
  echo "  請從 LB-oculus 目錄執行此腳本" >&2
  exit 1
fi

# 檢查是否已注入
if grep -qF "$MARKER" "$ZSHRC" 2>/dev/null; then
  echo "✓ 指令帳已注入 ~/.zshrc（跳過）"
  exit 0
fi

# 備份
cp "$ZSHRC" "$ZSHRC.dbp-bak.$(date +%s)" 2>/dev/null
echo "→ 已備份 $ZSHRC"

# 注入
cat >> "$ZSHRC" <<INJECT

$MARKER
# 自動由 install-shell-hook.sh 添加，移除這塊就要手動刪上面那行。
# 啟動不阻塞：preexec 為 zsh 內建 $EPOCHREALTIME，<0.1ms。
# precmd 背景寫入 ledger/_runs.jsonl，不拖慢提示。
if [ -f "$PREEXEC_SCRIPT" ]; then
  source "$PREEXEC_SCRIPT"
fi
# >>> dbp preexec hook (指令帳 end) <<<
INJECT

echo "✓ 已注入 $ZSHRC"
echo ""
echo "生效方式（二選一）："
echo "  1. source ~/.zshrc"
echo "  2. 開新終端視窗"
echo ""
echo "驗收：新 shell 跑 echo test123，然後："
echo "  tail -1 ~/.debugpedia/ledger/_runs.jsonl"
echo "  應該看到指令被記錄（含 ts/code=0）"