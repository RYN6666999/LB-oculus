#!/bin/sh
# redteam/run.sh — 跑全部攻擊，對帳「宣告的預期」與「實際結果」。
#
# 用法：
#   ./redteam/run.sh              全部
#   ./redteam/run.sh 001 004      只跑編號開頭符合的
#
# 退出碼：
#   0  全部符合預期（含 BREACH —— 洞還在就是符合預期）
#   1  有 DRIFT（實際 != 預期）→ 去更新預期或去確認修好了
#   2  有 BROKEN（攻擊自己跑不起來）→ 最嚴重，先修 redteam
#
# 為什麼 BROKEN 的退出碼比 DRIFT 大：
#   DRIFT 是「你知道有事變了」。BROKEN 是「你什麼都不知道」。
#   無知比壞消息嚴重。

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
RT="$ROOT/redteam"
export RT_LIB="$RT/lib.sh"

# 找一個真的能跑的 python3 —— 不假設 /opt/homebrew（那正是被攻擊的洞之一）
PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys' 2>/dev/null; then
    PY=$(command -v "$c"); break
  fi
done
[ -n "$PY" ] || { echo "找不到可用的 python3 —— redteam 無法執行"; exit 2; }
export PY

WORK=$(mktemp -d "${TMPDIR:-/tmp}/redteam.XXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT INT TERM

n_ok=0; n_drift=0; n_broken=0
DRIFT_LOG=""; BROKEN_LOG=""

printf '\n=== 陰陽眼 · 紅隊複驗 ===\n'
printf 'repo    %s\n' "$ROOT"
printf 'python  %s\n' "$PY"
printf 'BREACH=洞還在（正確）  SEALED=洞補好了  DRIFT=與預期不符  BROKEN=攻擊自己壞了\n\n'

for atk in "$RT/attacks"/*.sh; do
  name=$(basename "$atk")

  # 過濾
  if [ $# -gt 0 ]; then
    match=0
    for pat in "$@"; do case "$name" in "$pat"*) match=1;; esac; done
    [ "$match" -eq 1 ] || continue
  fi

  # EXPECT 從檔頭讀，不在 runner 裡手抄一份（鐵律一：事實只能推導）
  expect=$(sed -n 's/^# *EXPECT: *\([A-Z]*\).*/\1/p' "$atk" | head -1)
  case "$expect" in
    BREACH|SEALED|BROKEN) ;;
    *) printf '  ⚠️  %-42s 檔頭沒有合法的 EXPECT，跳過並計為 BROKEN\n' "$name"
       n_broken=$((n_broken+1)); BROKEN_LOG="$BROKEN_LOG
      $name  缺 EXPECT 標頭"; continue;;
  esac

  # 每支一份用完即丟的沙盒：改壞它不影響真 repo
  #
  # 這份清單是白名單，而白名單會過期 ——
  # 2026-07-27 新增 cron/ 後，attack 009 立刻 BROKEN（缺 cron/generalize.sh）。
  # 那次 BROKEN 是**正確的行為**：它沒有謊稱 SEALED，而是說「我跑不起來」。
  # 若當初把 need() 寫成 sealed()，紅隊會回報「洞補好了」——
  # 一個從沒執行過的攻擊宣稱它保護了什麼，那是這整層最貴的謊言。
  SANDBOX="$WORK/$name.box"
  mkdir -p "$SANDBOX"
  for d in bin hooks skill cron tests install.sh README.md; do
    [ -e "$ROOT/$d" ] && cp -R "$ROOT/$d" "$SANDBOX/" 2>/dev/null
  done
  # 心跳與候選是執行產物，不是原始碼。帶進沙盒會讓「上次跑的結果」
  # 被誤認成「這次跑出來的結果」—— 攻擊 009 會因此假 SEALED。
  rm -f "$SANDBOX/cron/_heartbeat.json" "$SANDBOX/cron/_lasterr.txt"
  rm -rf "$SANDBOX/cron/candidates"
  LEDGER="$WORK/$name.ledger"
  mkdir -p "$LEDGER"
  export SANDBOX LEDGER

  out=$(sh "$atk" 2>&1); rc=$?

  case "$rc" in
    0) actual=BREACH ;;
    1) actual=SEALED ;;
    2) actual=BROKEN ;;
    # 任何其他退出碼都是 BROKEN。絕不當成「攻擊失敗」——
    # 那就是 install.sh:16 的錯（用 test -e 定義成功）。
    *) actual=BROKEN; out="$out
      （非預期退出碼 $rc，一律歸 BROKEN）" ;;
  esac

  msg=$(printf '%s' "$out" | grep -E '^(BREACH|SEALED|BROKEN):' | head -1 | cut -c9-)
  [ -n "$msg" ] || msg="(無訊息)"

  if [ "$actual" = "$expect" ]; then
    if [ "$actual" = BROKEN ]; then
      # 預期就是 BROKEN 的（canary 901）—— 這是 harness 自檢通過
      printf '  ✓ %-42s %s（harness 自檢通過）\n' "$name" "$actual"
    else
      printf '  ✓ %-42s %s\n' "$name" "$actual"
    fi
    n_ok=$((n_ok+1))
  elif [ "$actual" = BROKEN ]; then
    printf '  ⚠️  %-42s BROKEN（預期 %s）\n' "$name" "$expect"
    printf '       %s\n' "$msg"
    n_broken=$((n_broken+1))
    BROKEN_LOG="$BROKEN_LOG
      $name  $msg"
  else
    printf '  △ %-42s DRIFT: 預期 %s，實得 %s\n' "$name" "$expect" "$actual"
    printf '       %s\n' "$msg"
    n_drift=$((n_drift+1))
    DRIFT_LOG="$DRIFT_LOG
      $name  預期 $expect / 實得 $actual  ·  $msg"
  fi
done

total=$((n_ok + n_drift + n_broken))
printf '\n─── 共 %d 支 · 符合預期 %d · DRIFT %d · BROKEN %d ───\n' \
  "$total" "$n_ok" "$n_drift" "$n_broken"

if [ "$total" -eq 0 ]; then
  printf '\n⚠️  沒有任何攻擊被執行。零攻擊不等於安全 —— 這是無知，不是綠燈。\n\n'
  exit 2
fi

if [ -n "$BROKEN_LOG" ]; then
  printf '\n⚠️  BROKEN（最嚴重 —— 此刻你對這些面向一無所知）:%s\n' "$BROKEN_LOG"
fi
if [ -n "$DRIFT_LOG" ]; then
  printf '\n△ DRIFT（去確認：是修好了，還是壞法變了）:%s\n' "$DRIFT_LOG"
fi

if [ "$n_broken" -gt 0 ]; then
  printf '\n先修 redteam 自己，再談 repo。\n\n'; exit 2
fi
if [ "$n_drift" -gt 0 ]; then
  printf '\n有洞的狀態變了。若確認已修好，改該支的 EXPECT 為 SEALED 並在 plan/ 留案。\n\n'; exit 1
fi
printf '\n全部符合預期。注意：這代表「已知的洞都還在原地」，不代表安全。\n\n'
exit 0
