#!/bin/sh
# anchor.sh — 排程外殼：每天跑 dbp anchor，寫入 audit/ANCHORS.md。
#
# 為什麼需要這個：
#   雜湊鏈本身是 append-only 的，但 append-only 的內容仍然可以被整本替換。
#   把錨點字串寫進 repo 並推上 GitHub 之後，agent 就改不動了 ——
#   改了 sha 全變、force-push 在 GitHub 事件記錄留痕。
#   這一層擋的是「悄悄換本」。
#
# 絕對約束（繼承 generalize.sh）：
#   · **無論成敗都寫心跳。** 「從沒跑過」和「每次都失敗」長得一模一樣。
#   · **失敗必須非零退出。** 永遠 exit 0 的排程不會出現在任何人的雷達上。
#   · 心跳不由自己檢查。檢查者是 tests/smoke.sh。
#   · 外殼用 sh，不假設 python 存在。

HERE="$(cd "$(dirname "$0")" && pwd)"
HB="$HERE/_heartbeat.json"
REPO_ROOT="$(cd "$HERE/.." && pwd)"

beat() {
  status="$1"; reason="$2"
  printf '{"ts":"%s","status":"%s","reason":"%s","host":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$reason" "$(uname -n 2>/dev/null || echo unknown)" \
    > "$HB" 2>/dev/null
}

die() {
  beat fail "$1"
  printf 'anchor: ✗ %s\n' "$1" >&2
  printf '       心跳已寫入 %s（status=fail）\n' "$HB" >&2
  exit 1
}

# ── 找 dbp ──────────────────────────────────────────────────────────
DBP=""
for c in ~/.local/bin/dbp /usr/local/bin/dbp /opt/homebrew/bin/dbp; do
  if [ -x "$c" ]; then
    # test -x 不夠（install.sh:16 的教訓），要真的跑得起來
    # 用裸 dbp（印 help exit 0）探活，不用 anchor（鏈斷時 anchor return 1）
    if "$c" >/dev/null 2>&1; then
      DBP="$c"; break
    fi
  fi
done
[ -n "$DBP" ] || die "找不到能執行的 dbp（cron PATH 比 shell 窄）"

# ── 跑 dbp anchor（鏈斷時這裡會 die，死因會是「鏈斷」不是「找不到 dbp」）─
ANCHOR_OUT="$("$DBP" anchor 2>&1)" || die "dbp anchor 失敗: $(printf '%s' "$ANCHOR_OUT" | tail -1)"

# ── 寫入 audit/ANCHORS.md ───────────────────────────────────────────
ANCHORS="$REPO_ROOT/audit/ANCHORS.md"
mkdir -p "$(dirname "$ANCHORS")"

# 如果沒有檔頭就補
[ -f "$ANCHORS" ] || printf '%s\n' "# 錨點紀錄" "" "> 自動產生，不要手改。cron/anchor.sh 每天 append。" "" > "$ANCHORS"

# append 一行
printf '%s\n' "$ANCHOR_OUT" >> "$ANCHORS"

# ── commit & push ────────────────────────────────────────────────────
cd "$REPO_ROOT" || die "無法 cd 到 repo root: $REPO_ROOT"

# 判斷是否有變動：用 git status --porcelain（git diff --quiet 對未追蹤檔回 0）
if ! git status --porcelain "$ANCHORS" 2>/dev/null | grep -q .; then
  beat ok "無變動（錨點內容與上次一致）"
  printf 'anchor: ✓ 無變動，跳過 commit\n'
  exit 0
fi

git add "$ANCHORS" || die "git add 失敗"
git commit -m "anchor: $(printf '%s' "$ANCHOR_OUT" | head -1)" || die "git commit 失敗"

if ! git push origin HEAD 2>&1; then
  # push 失敗不 die，因為可能只是離線 —— 下次 run 會補推
  beat fail "push 失敗（可能離線，下次會補）"
  printf 'anchor: ⚠ push 失敗（離線或權限），下次 run 會補推\n'
  exit 1
fi

beat ok "錨點已寫入 $ANCHORS 並推送"
printf 'anchor: ✓ 錨點已推送\n'
exit 0