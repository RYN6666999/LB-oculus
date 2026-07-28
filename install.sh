#!/bin/sh
# install.sh — 用 symlink 安裝，不複製。
#
# 為什麼是 symlink：複製會產生第二份，兩份會各自漂移，那正是鐵律一禁的事。
# symlink 讓 repo 永遠是唯一來源，改 repo 就等於改所有掛載點。
#
# 冪等：重跑安全。解安裝：刪掉那些 symlink 即可，本 repo 不動。


R="$(cd "$(dirname "$0")" && pwd)"

# set -e 已關閉：這支腳本現在要「收集」失敗並在最後統一回報，
# 而不是在第一個失敗處靜靜跳出。set -e 會讓 verify 的非零退出直接終止腳本，
# 使用者只看到腳本消失，看不到哪幾項壞了。
FAILED=0

link() {
  src="$1"; dst="$2"
  mkdir -p "$(dirname "$dst")"
  # 只覆蓋 symlink。真檔案不動 —— 那可能是使用者自己的東西。
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  ⚠️  略過（那裡有真檔案，不是 symlink）: $dst"
    return 0
  fi
  if ! ln -sfn "$src" "$dst"; then
    echo "  ✗ 連結失敗: $dst"
    FAILED=1
    return 1
  fi
  # 這裡刻意「不印 ✓」。
  # 舊版在這裡印 ✓，判定依據是 test -e —— ln 產出 symlink、test -e 驗 symlink，
  # 同一條路驗等於沒驗（README:38 自己禁的事）。
  # 綠勾現在只能由 verify_* 發放，而那必須真的執行過。
  return 0
}

# 產出者不得自驗：link 是一條路，執行是另一條。
#
# 為什麼餵 </dev/null 而不用 --help：
#   兩個 hook 從 stdin 讀 JSON。`dbp-risk-gate --help` 在沒有 stdin 的環境
#   會「永久掛住」（2026-07-27 實測 >120 秒）。若照原計畫用 --help 驗 hook，
#   install.sh 會直接凍結 —— 一個為了偵測失敗而加的檢查，自己變成更糟的失敗。
#   </dev/null 讓 stdin 立刻 EOF，且不需要 timeout（macOS 預設沒有 timeout）。
verify_exec() {
  dst="$1"
  # 退出碼必須「直接」取，不能隔著 if 複合指令 ——
  # `if cmd; then ...; fi` 之後的 $? 是那整個 if 的退出碼；條件為假又沒有 else 時
  # if 本身成功退出（0），真正的 127 已經被吃掉。
  # 2026-07-27 實測：反向驗證印出「exit 0」而非「exit 127」，就是踩到這裡。
  # 這正是 plan/001 預測 bug #2：「shell 的錯誤處理很容易只在快樂路徑上驗過」。
  "$dst" --help </dev/null >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "  ✓ $dst"
    return 0
  fi
  echo "  ✗ $dst 裝上了但跑不起來（exit $rc）"
  [ "$rc" -eq 127 ] && echo "      exit 127 = 解譯器不存在，通常是 shebang 指向這台機器沒有的 python"
  FAILED=1
  return 1
}

# 目錄型掛載點（skill）沒有 --help 可跑。
# 這是預期 bug #7：原計畫只想到三個執行檔，漏了 ~/.agents/skills 是目錄。
# 目錄能驗的「執行」就是：symlink 解得開，且裡面該有的檔真的讀得到。
verify_dir() {
  dst="$1"; must="$2"
  if [ -d "$dst" ] && [ -r "$dst/$must" ]; then
    echo "  ✓ $dst"
    return 0
  fi
  echo "  ✗ $dst 連結存在但讀不到 $must（斷鏈或指向空目錄）"
  FAILED=1
  return 1
}

printf '\nLB-oculus · 陰陽眼 安裝\n'
printf '來源: %s\n\n' "$R"

# chmod 必須在 verify 之前 —— 否則「直接執行」必然因權限失敗，
# 那會是假紅（報告一個安裝根本沒造成的問題）。
chmod +x "$R/bin/dbp" "$R/hooks/dbp-autocapture" "$R/hooks/dbp-risk-gate" 2>/dev/null || true

link "$R/bin/dbp"                  "$HOME/.local/bin/dbp"
link "$R/skill/coding-yinyang-eye" "$HOME/.claude/skills/coding-yinyang-eye"
link "$R/hooks/dbp-autocapture"    "$HOME/.claude/hooks/dbp-autocapture"
link "$R/hooks/dbp-risk-gate"      "$HOME/.claude/hooks/dbp-risk-gate"
# Scream 讀 ~/.agents/skills（不是 ~/.scream-code/skills —— 那裡只有 8 個，
# 實際載入的是 ~/.agents/skills 的 101 個。2026-07-27 實查）。
link "$R/skill/coding-yinyang-eye" "$HOME/.agents/skills/coding-yinyang-eye"

# ── 綠勾在這裡才發放，且只由「真的執行過」發放 ──────────────────
printf '掛載點實測（不信 ln 的回報，直接執行）\n'
verify_exec "$HOME/.local/bin/dbp"
verify_exec "$HOME/.claude/hooks/dbp-autocapture"
verify_exec "$HOME/.claude/hooks/dbp-risk-gate"
verify_dir  "$HOME/.claude/skills/coding-yinyang-eye" "SKILL.md"
verify_dir  "$HOME/.agents/skills/coding-yinyang-eye" "SKILL.md"

if [ "$FAILED" -ne 0 ]; then
  printf '\n✗ 安裝未完成 —— 上面有 ✗ 的項目裝上了但跑不起來。\n'
  printf '  這支腳本刻意非零退出：一個永遠成功的安裝程序等於沒有檢查。\n'
  printf '  常見原因：shebang 指向這台機器沒有的 python（exit 127）。\n\n'
  exit 1
fi

printf '\n驗收（換一條路，不信上面的 ✓）：\n'
printf '  dbp stats            # CLI 通了嗎\n'
printf '  dbp open             # 有沒有未收尾的事\n'
printf '  dbp rules            # 錯誤史歸納出哪些類別\n'
printf '  ./redteam/run.sh     # 已知的洞今天還在嗎（BREACH=還在=符合預期）\n'
printf '\nClaude Code 的兩個 hook 要重開 session 才生效（settings.json 啟動時載入）。\n'
printf 'settings.json 不由本腳本改 —— 那是你的全域設定，見 README。\n\n'
