#!/bin/sh
# generalize.sh — 排程外殼。不含任何智慧，只負責「讓失敗看得見」。
#
# 為什麼外殼是 sh 而不是 python：
#   cron 的環境是整台機器上最貧瘠的環境 —— PATH 常常只有 /usr/bin:/bin，
#   沒有 shell rc、沒有 pyenv、沒有 homebrew。
#   如果外殼本身需要「先能跑 python」才能報錯，那它在 python 找不到的那天
#   會安靜地 exit 127，而你會以為排程從來沒被觸發過。
#   這是 plan/001 那個 shebang 洞的同一個成因，換到 cron 環境發作。
#
# 絕對約束：
#   · **無論成敗都寫心跳。** 沒有心跳的 cron 等於沒有 cron ——
#     「從沒跑過」和「每次都失敗」在使用者眼裡長得一模一樣。
#   · **失敗必須非零退出。** 一個永遠 exit 0 的排程不會出現在任何人的雷達上。
#   · 心跳**不由自己檢查**。檢查者是 tests/smoke.sh（A14）——
#     自己檢查自己的心跳是共同失效點，plan/001 已經推翻過一次這個錯。

HERE="$(cd "$(dirname "$0")" && pwd)"
HB="$HERE/_heartbeat.json"

# 心跳一定要寫得出來，所以用最笨的方式寫（printf，不依賴任何工具）
beat() {
  status="$1"; reason="$2"
  # 手捏 JSON 是刻意的：這裡不能依賴 python，因為 python 不見正是要報的錯之一。
  printf '{"ts":"%s","status":"%s","reason":"%s","host":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$reason" "$(uname -n 2>/dev/null || echo unknown)" \
    > "$HB" 2>/dev/null
}

die() {
  beat fail "$1"
  printf 'generalize: ✗ %s\n' "$1" >&2
  printf '           心跳已寫入 %s（status=fail）\n' "$HB" >&2
  printf '           這支腳本刻意非零退出：安靜失敗的排程等於不存在的排程。\n' >&2
  exit 1
}

# ── 找 python ─────────────────────────────────────────────────────────
# 不寫死 /usr/bin/python3 也不寫死 homebrew。逐一試「真的跑得起來」，
# 不是 test -x —— test -x 在解譯器不存在時照樣通過（install.sh:16 的教訓）。
PY=""
for c in python3 /usr/bin/python3 /usr/local/bin/python3 /opt/homebrew/bin/python3; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys' >/dev/null 2>&1; then
    PY="$c"; break
  fi
done
[ -n "$PY" ] || die "找不到能執行的 python3（cron 的 PATH 通常比 shell 窄，考慮在 crontab 裡寫絕對路徑）"

[ -f "$HERE/generalize.py" ] || die "缺少 $HERE/generalize.py"

# ── 呼叫歸納器 ────────────────────────────────────────────────────────
# stdout 與 stderr 必須分開收。
#   第一版用 2>&1 合併，然後「取最後一行當失敗原因」。實測結果是心跳寫進了
#   「去識別化命中 2 處」—— 那是 stdout 的進度訊息，不是錯誤。
#   合併之後，兩條語意完全不同的流變得無法區分：進度長得跟死因一樣。
#   一個把進度報告當死因記下來的心跳，比沒有心跳更糟：它會誤導追查方向。
ERRF="$HERE/_lasterr.txt"
out="$("$PY" "$HERE/generalize.py" 2>"$ERRF")"
rc=$?

printf '%s\n' "$out"
[ -s "$ERRF" ] && cat "$ERRF" >&2

if [ "$rc" -ne 0 ]; then
  # 死因只從 stderr 取。歸納器所有 fail() 都寫 stderr，這是它的契約。
  reason="$(grep -v '^[[:space:]]*$' "$ERRF" 2>/dev/null | tail -1 | tr '"\\' "''" | cut -c1-200)"
  die "${reason:-歸納器非零退出（rc=$rc）但 stderr 是空的 —— 比有錯誤訊息更糟，代表它死得不明不白}"
fi

beat ok "產出候選成功"
printf 'generalize: ✓ 心跳已寫入 %s（status=ok）\n' "$HB"
printf '            候選不會自動變成攻擊 —— 見 cron/README.md 為什麼人必須在中間。\n'
exit 0
