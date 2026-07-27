#!/bin/sh
# install.sh — 用 symlink 安裝，不複製。
#
# 為什麼是 symlink：複製會產生第二份，兩份會各自漂移，那正是鐵律一禁的事。
# symlink 讓 repo 永遠是唯一來源，改 repo 就等於改所有掛載點。
#
# 冪等：重跑安全。解安裝：刪掉那些 symlink 即可，本 repo 不動。
set -e

R="$(cd "$(dirname "$0")" && pwd)"

link() {
  src="$1"; dst="$2"
  mkdir -p "$(dirname "$dst")"
  # 只覆蓋 symlink。真檔案不動 —— 那可能是使用者自己的東西。
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  ⚠️  略過（那裡有真檔案，不是 symlink）: $dst"
    return 0
  fi
  ln -sfn "$src" "$dst"
  echo "  ✓ $dst"
}

echo "\nLB-oculus · 陰陽眼 安裝"
echo "來源: $R\n"

echo "CLI"
link "$R/bin/dbp" "$HOME/.local/bin/dbp"

echo "\nClaude Code"
link "$R/skill/coding-yinyang-eye" "$HOME/.claude/skills/coding-yinyang-eye"
link "$R/hooks/dbp-autocapture"    "$HOME/.claude/hooks/dbp-autocapture"
link "$R/hooks/dbp-risk-gate"      "$HOME/.claude/hooks/dbp-risk-gate"

# Scream 讀 ~/.agents/skills（不是 ~/.scream-code/skills —— 那裡只有 8 個，
# 實際載入的是 ~/.agents/skills 的 101 個。2026-07-27 實查）。
echo "\nScream"
link "$R/skill/coding-yinyang-eye" "$HOME/.agents/skills/coding-yinyang-eye"

chmod +x "$R/bin/dbp" "$R/hooks/dbp-autocapture" "$R/hooks/dbp-risk-gate" 2>/dev/null || true

echo "\n驗收（換一條路，不信上面的 ✓）："
echo "  dbp stats            # CLI 通了嗎"
echo "  dbp open             # 有沒有未收尾的事"
echo "  dbp rules            # 錯誤史歸納出哪些類別"
echo ""
echo "Claude Code 的兩個 hook 要重開 session 才生效（settings.json 啟動時載入）。"
echo "settings.json 不由本腳本改 —— 那是你的全域設定，見 README。\n"
