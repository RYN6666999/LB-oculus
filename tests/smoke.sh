#!/usr/bin/env bash
# smoke.sh — plan/001 第 3 項：第一個 smoke test
#
# ─────────────────────────────────────────────────────────────────────
# 為什麼這支不是「全綠才算過」
# ─────────────────────────────────────────────────────────────────────
# plan/001 自己有矛盾（執行時才發現，已記進 ledger）：
#   · 核心判斷寫「**不修任何一個 bug**」
#   · 驗收第 4 步寫「baseline 應為 0」
# 一個不修 bug 的 repo，寫一套抓得到那些 bug 的測試，baseline 不可能是 0。
# 硬要 0 只有兩條路，兩條都是這個 repo 自己禁的：
#   (a) 偷偷把 bug 修掉  → 違反本案核心判斷，且 15 條靜默失效會失去護欄
#   (b) 偷偷跳過那幾條  → 「抑制必須可見」的反面，牆上開洞還不掛牌
#
# 所以走第三條路，語意跟 redteam/ 同一套（同一個 repo 不該有兩種真假觀）：
#   每條斷言自帶 EXPECT。
#     EXPECT=PASS        本案已修好的 → 紅了就是回歸（NEW_RED）
#     EXPECT=KNOWN_FAIL  已立案的洞   → 紅了是「符合預期」，綠了是 DRIFT
#
#   綠了反而要報警：洞被修掉卻沒人更新 EXPECT，下一個人就會以為這裡從來沒事。
#   跟 redteam 的 BREACH/SEALED 是同一個道理 —— 狀態變了必須有人知道。
#
# 退出碼
#   0  全部與宣告一致（含「已知洞今天還在」）
#   1  有 NEW_RED（回歸）或 DRIFT（洞沒了但沒更新宣告）
#   2  harness 自己壞了 / 前置不成立 / 污染了真帳本
#      —— 2 比 1 嚴重。無知比壞消息嚴重。
# ─────────────────────────────────────────────────────────────────────

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO" || { echo "BROKEN: 進不去 repo"; exit 2; }

PASS=0; KNOWN=0; NEWRED=0; DRIFT=0; BROKEN=0

# ── 隔離 ──────────────────────────────────────────────────────────────
# plan/001 預期 bug #4（自評「高 · 短期」）：測試會污染真實 ~/.debugpedia。
# 不可逆的傷害不能只靠「我記得有設環境變數」。這裡的做法是：
#   1. 全部塞進 mktemp
#   2. 動手前把真帳本的指紋存下來，跑完比對；不一致就 exit 2
# 指紋而不是「我檢查過 DEBUGPEDIA_DIR 有設」—— 後者是宣稱，前者是證據。
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lb-smoke.XXXXXX")" || { echo "BROKEN: mktemp 失敗"; exit 2; }
HOME_T="$TMP/home"
LEDGER="$TMP/ledger"
FIXTURE="$TMP/fixture"
mkdir -p "$HOME_T" "$LEDGER" "$FIXTURE"

REAL_DBP="${DEBUGPEDIA_DIR:-$(~/.local/bin/dbp _dir 2>/dev/null || echo "$HOME/.debugpedia")}"
fingerprint() {
  [ -d "$REAL_DBP" ] || { echo "(不存在)"; return 0; }
  # 檔名 + 位元組數。內容變了但大小沒變的機率不是 0，但這是不需要 hash 工具的最強可攜檢查。
  ls -l "$REAL_DBP" 2>/dev/null | awk '{print $5, $NF}' | sort
}
FP_BEFORE="$(fingerprint)"

export DEBUGPEDIA_DIR="$TMP"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# ── 三態回報 ──────────────────────────────────────────────────────────
run_case() {
  id="$1"; expect="$2"; desc="$3"; fn="$4"
  out="$($fn 2>&1)"; rc=$?
  # 任何非 0/1/2 一律當 BROKEN。絕不當成「斷言不成立」——
  # 那正是 install.sh:16 犯過的錯：把「沒驗到」當成「驗過了」。
  case "$rc" in
    0) actual=PASS ;;
    1) actual=FAIL ;;
    2) actual=BROKEN ;;
    *) actual=BROKEN; out="$out
      （案子退出碼 $rc，不在 0/1/2 之內 —— 一律降級為 BROKEN）" ;;
  esac

  if [ "$actual" = BROKEN ]; then
    printf '  BROKEN   %s  %s\n' "$id" "$desc"
    printf '%s\n' "$out" | sed 's/^/             /'
    BROKEN=$((BROKEN + 1)); return
  fi

  if [ "$expect" = PASS ] && [ "$actual" = PASS ]; then
    printf '  ✓ PASS   %s  %s\n' "$id" "$desc"
    PASS=$((PASS + 1)); return
  fi
  if [ "$expect" = PASS ] && [ "$actual" = FAIL ]; then
    printf '  ✗ NEW_RED %s  %s\n' "$id" "$desc"
    printf '%s\n' "$out" | sed 's/^/             /'
    NEWRED=$((NEWRED + 1)); return
  fi
  if [ "$expect" = KNOWN_FAIL ] && [ "$actual" = FAIL ]; then
    # 紅是對的。但必須印出來 —— 被抑制的洞不掛牌，就會被當成沒有。
    printf '  · 已知紅 %s  %s\n' "$id" "$desc"
    KNOWN=$((KNOWN + 1)); return
  fi
  printf '  ! DRIFT  %s  %s\n' "$id" "$desc"
  printf '             宣告 KNOWN_FAIL 但今天通過了 —— 洞被修掉了？\n'
  printf '             去改本案的 EXPECT 並在 plan/ 留案，別讓它靜靜變綠。\n'
  DRIFT=$((DRIFT + 1))
}

D="$HOME_T/.local/bin/dbp"                 # 走安裝後的路徑，不是 repo 裡的 bin/dbp
GATE="$HOME_T/.claude/hooks/dbp-risk-gate"
CAP="$HOME_T/.claude/hooks/dbp-autocapture"
# 直接餵 hook 原始檔（安裝可能不存在，但原始檔一定在 repo 裡）
HOOK_GATE_SRC="$REPO/hooks/dbp-risk-gate"
HOOK_CAP_SRC="$REPO/hooks/dbp-autocapture"

# 產出者不得自驗：本案改的是 shebang 與 install.sh，
# 所以驗收一律「執行安裝後的檔」，不准讀 install.sh 的輸出當證據。
dbp() { "$D" "$@" </dev/null; }
lines() { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }

printf '\nLB-oculus · smoke test\n'
printf 'repo    : %s\n' "$REPO"
printf '沙盒    : %s\n' "$TMP"
printf '真帳本  : %s（只讀指紋，不碰）\n\n' "$REAL_DBP"

# ── 前置：安裝 ────────────────────────────────────────────────────────
INSTALL_OUT="$TMP/install.out"
HOME="$HOME_T" sh "$REPO/install.sh" >"$INSTALL_OUT" 2>&1
INSTALL_RC=$?

printf '斷言（EXPECT=PASS 紅了是回歸；EXPECT=KNOWN_FAIL 綠了是 DRIFT）\n\n'

# ── A01 · install.sh 自己的退出碼 ─────────────────────────────────────
# 對應 plan/001 第 2 項。它以前永遠 exit 0，那等於沒有檢查。
c01() { [ "$INSTALL_RC" -eq 0 ] || { echo "install exit=$INSTALL_RC"; sed -n '/✗/p' "$INSTALL_OUT"; return 1; }; }
run_case A01 PASS "install.sh 在健康環境 exit 0" c01

# ── A02 · P0-0 · 裝完真的跑得起來 ────────────────────────────────────
# test -e 會在解譯器不存在時照樣 PASS。只有執行會露出 exit 127。
c02() {
  [ -e "$D" ] || { echo "掛載點不存在 $D"; return 2; }
  "$D" --help </dev/null >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 0 ] || { echo "dbp --help exit=$rc（127=shebang 指向不存在的解譯器）"; return 1; }
}
run_case A02 PASS "dbp --help 從安裝後的路徑 exit 0（P0-0）" c02

# ── 前置：讓 gate 產生 _edits.jsonl ─────────────────────────────────
# 直接餵 stdin 給 hook 原始檔，不依賴 Claude 安裝路徑。
# clean CI 機器上 hook 不在標準位置，但原始檔一定在 repo 裡。
GATE_RUNNER="$HOOK_GATE_SRC"
# 如果安裝路徑有 hook 就用安裝的（那才是產出者要驗的路徑）
[ -x "$GATE" ] && GATE_RUNNER="$GATE"
printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/target.py"}}\n' "$FIXTURE" \
  | "$GATE_RUNNER" >/dev/null 2>&1
EDITS="$LEDGER/_edits.jsonl"

# 種幾筆真 bug 紀錄，之後的斷言都從「我寫了幾筆」推導，不寫死數字。
# plan/001 預期 bug #5：斷言裡寫死數字就是鐵律一的抄寫病。
SEED_N=0
seed() { dbp "$1" -w "$2" -t smoke >/dev/null 2>&1 && SEED_N=$((SEED_N + 1)); }
seed "smoke 種子：sweep 對自己瞎" "bin/dbp:436"
seed "smoke 種子：gate 有共同失效點" "hooks/dbp-risk-gate:41"
FIX_ID="$(dbp "smoke 種子：等著被補解法的一筆" -t smoke 2>/dev/null | awk '{print $2}')"
[ -n "$FIX_ID" ] && SEED_N=$((SEED_N + 1))

# ── A03 · P0-1 · ledger 裡有 _edits.jsonl 時 ls 不該爆 ───────────────
# 修復：ccb3ae2（階段 A：ledger/ 接地 + _all() 防呆，排除 _ 前綴的 ledger 檔）
c03() {
  [ -f "$EDITS" ] || { echo "前置不成立：gate 沒寫出 _edits.jsonl，無法觸發本條"; return 2; }
  err="$(dbp ls 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { printf '%s\n' "$err" | tail -3; return 1; }
}
run_case A03 PASS "dbp ls 在 ledger 有 _edits.jsonl 時 exit 0（P0-1）" c03

# ── A04 · P0-1b · stats 總數 == 真 bug 數 ────────────────────────────
# 真 bug 數 = 我剛剛種了幾筆（推導）。_edits.jsonl 是機械 log，不是 bug，
# 但 _all() 的 glob 是 *.jsonl，把它一起算進去 → 分母被污染。
# 修復：ccb3ae2（階段 A：ledger/ 接地 + _all() 防呆，排除 _ 前綴）
c04() {
  tot="$(dbp stats 2>/dev/null | sed -n 's/^總計 \([0-9]*\) 筆.*/\1/p' | head -1)"
  [ -n "$tot" ] || { echo "stats 沒印出總計，形狀變了"; return 2; }
  [ "$SEED_N" -gt 0 ] || { echo "前置不成立：一筆種子都沒寫進去"; return 2; }
  [ "$tot" -eq "$SEED_N" ] || { echo "stats 總計=$tot 但真 bug 數=$SEED_N（差額=機械 log 被算成 bug）"; return 1; }
}
run_case A04 PASS "dbp stats 總數 == 真 bug 數（P0-1b）" c04

# ── A05 · P0-3 · fix 之後指標要動 ────────────────────────────────────
# fix() 只是 append 一筆新紀錄，沒有任何一行的 fix 欄位被填上 →
# 「已補解法」永遠 0%。一個永遠 0% 的指標比沒有指標更糟：它看起來在量。
c05() {
  [ -n "$FIX_ID" ] || { echo "前置不成立：拿不到可補解法的 id"; return 2; }
  dbp fix "$FIX_ID" "smoke 測試補上的解法" >/dev/null 2>&1
  pct="$(dbp stats 2>/dev/null | sed -n 's/.*已補解法 [0-9]* 筆 (\([0-9]*\)%).*/\1/p' | head -1)"
  [ -n "$pct" ] || { echo "stats 沒印出百分比，形狀變了"; return 2; }
  [ "$pct" -gt 0 ] || { echo "補了解法但 stats 仍然 0%"; return 1; }
}
run_case A05 KNOWN_FAIL "dbp fix 後 stats 的 % > 0（P0-3）" c05

# ── A06 · 新洞 E · risk 的 len(stem) > 3 把三字檔名整批排除 ──────────
#
# 這一條我第一次寫錯，過程留在這裡因為它比結論值錢：
#   plan/001 的斷言表原文是「`dbp risk bin/dbp` 有輸出 → 新洞 E」。我照抄，結果它「通過」了，
#   被 harness 報成 DRIFT。換一條路查才發現：`risk bin/dbp` 沒有副檔名，
#   走的是 base 比對（"dbp" in "bin/dbp:436"）—— 本來就會中，跟 stem 長度無關。
#
#   也就是說：**那條斷言驗不到它宣稱要驗的洞**，而且它會永遠綠。
#   我在寫一支專門抓「假綠」的測試時，自己先產了一個假綠 —— 而且是照抄計畫案來的。
#   （鐵律一：抄寫就是排程好的未來謊言。連自己的計畫案也不能抄。）
#
# 真正的洞：`len(stem) > 3` 排除掉所有三字 stem 的比對路徑。
# 前科記在 bin/dbp，今天要改 `bin/dbp.py`（base 不同、stem 相同）→ 查不到。
# 這不是假設：dbp / gsk / 任何三字工具名都在這個盲區裡。
# 修復：f1713c0（輪次 3-final: dbp prompt + risk() 修自盲，len(stem)>3 → >=3）
c06() {
  out="$(dbp risk bin/dbp.py 2>&1)"
  case "$out" in
    *無前科*)
      echo "前科記在 bin/dbp:436，查 bin/dbp.py（同 stem）卻說「無前科」"
      echo "原因：risk() 的 len(stem) > 3 把三字 stem 整批排除（bin/dbp:272）"
      return 1 ;;
  esac
  [ -n "$out" ] || { echo "risk 完全沒有輸出"; return 1; }
}
run_case A06 PASS "dbp risk 跨副檔名查得到同 stem 前科（新洞 E）" c06

# ── A06b · 反面：risk 不該無故命中 ───────────────────────────────────
# 沒有這條，把 len(stem)>3 改成 >=3 之後，A06 會變綠但可能是因為
# risk 開始對「所有」檔案都喊有前科 —— 那是假紅，而假紅會訓練人忽略全部的紅。
# 修 A06 的人必須同時被這條擋著。
c06b() {
  out="$(dbp risk totally/unrelated-xk92.conf 2>&1)"
  case "$out" in
    *無前科*) return 0 ;;
  esac
  echo "對一個毫無關聯的檔名喊出前科 —— 假紅比沒有警告更糟"
  printf '%s\n' "$out" | head -4
  return 1
}
run_case A06b PASS "dbp risk 對無關檔名不喊前科（假紅防線）" c06b

# ── A07 · P2-b · sweep 掃到的檔數 == 真檔數 ──────────────────────────
# 用受控 fixture，數字由 fixture 推導。SWEEP_EXT 是白名單副檔名，
# 沒有副檔名的 hook 一律掃不到 —— 這個 repo 有三支這種檔（正是最愛壞的三支）。
c07() {
  mkdir -p "$FIXTURE/sw"
  printf 'x = 1\n'        > "$FIXTURE/sw/a.py"
  printf '# note\n'       > "$FIXTURE/sw/b.md"
  printf '#!/bin/sh\ntrue\n' > "$FIXTURE/sw/somehook"   # 無副檔名，但確實是原始碼
  chmod +x "$FIXTURE/sw/somehook"
  real="$(find "$FIXTURE/sw" -type f | wc -l | tr -d ' ')"
  got="$(dbp sweep "$FIXTURE/sw" 2>/dev/null | sed -n 's/^掃了 \([0-9]*\) 個檔.*/\1/p' | head -1)"
  [ -n "$got" ] || { echo "sweep 沒印出「掃了 N 個檔」，形狀變了"; return 2; }
  [ "$got" -eq "$real" ] || { echo "sweep 掃了 $got 個，fixture 實際有 $real 個（漏的是無副檔名的檔）"; return 1; }
}
run_case A07 KNOWN_FAIL "dbp sweep 掃到的檔數 == 真檔數（P2-b）" c07

# ── A08 · P2-c · done 一個不存在的 id 必須非零 ───────────────────────
# 現在永遠 exit 0 並印「dbp done <id>」。
# 打錯 id 的收尾看起來成功了，那條未收尾的事就永遠掛在那裡。
c08() {
  dbp done "這個id絕對不存在-9q8w7e" "亂收尾" >/dev/null 2>&1
  rc=$?
  [ "$rc" -ne 0 ] || { echo "收尾一個不存在的 id，仍然 exit 0"; return 1; }
}
run_case A08 KNOWN_FAIL "dbp done <不存在的id> 非零退出（P2-c）" c08

# ── A09 · 新洞 D · 未知子指令不該變成一筆 bug ────────────────────────
# main() 的 fallthrough 是「預設就是記一筆」，所以打錯字會被記成 bug 紀錄。
# 帳本被自己的 typo 污染，而且 exit 0 讓你完全不知道打錯了。
c09() {
  before="$(lines "$LEDGER/$(date -u +%G-W%V).jsonl")"
  dbp frobnicate-does-not-exist >/dev/null 2>&1
  rc=$?
  after="$(lines "$LEDGER/$(date -u +%G-W%V).jsonl")"
  if [ "$rc" -eq 0 ]; then echo "未知子指令 exit 0"; return 1; fi
  [ "$after" -eq "$before" ] || { echo "未知子指令把自己寫成了一筆紀錄（$before → $after）"; return 1; }
}
run_case A09 KNOWN_FAIL "dbp <未知子指令> 非零且不寫帳本（新洞 D）" c09

# ── A10 · P1-6 · _runs.jsonl 不該含機密 ──────────────────────────────
# autocapture 把 cmd[:500] 原封不動寫進帳本。指令裡的 token 就進去了，
# 而帳本是 append-only、將來還要搬去別台機器 —— 越搬越難刪。
c10() {
  CAP_RUNNER="$HOOK_CAP_SRC"
  [ -x "$CAP" ] && CAP_RUNNER="$CAP"
  printf '{"command":"curl -H \\"Authorization: Bearer sk-SMOKEFAKEKEY0000000000\\" https://example.com","exit_code":0}\n' \
    | "$CAP_RUNNER" >/dev/null 2>&1
  r="$LEDGER/_runs.jsonl"
  [ -f "$r" ] || { echo "前置不成立：autocapture 沒寫出 _runs.jsonl"; return 2; }
  grep -q 'sk-SMOKEFAKEKEY' "$r" && { echo "_runs.jsonl 裡有未遮罩的 sk- 字串"; return 1; }
}
run_case A10 KNOWN_FAIL "_runs.jsonl 不含 sk- 樣式（P1-6）" c10

# ── A11 · P0-2 · Bash 改檔也該進 _edits.jsonl ────────────────────────
# WATCH 只認 Edit/Write/NotebookEdit/MultiEdit。
# 用 sed -i / cat > 改檔完全不留痕 —— 而那正是 AI 最常用的改檔手法。
c11() {
  GATE_RUNNER="$HOOK_GATE_SRC"
  [ -x "$GATE" ] && GATE_RUNNER="$GATE"
  before="$(lines "$EDITS")"
  printf '{"tool_name":"Bash","tool_input":{"command":"sed -i \\"1s/a/b/\\" %s/target.py"}}\n' "$FIXTURE" \
    | "$GATE_RUNNER" >/dev/null 2>&1
  after="$(lines "$EDITS")"
  [ "$after" -gt "$before" ] || { echo "Bash 改檔沒有留下任何 _edits 紀錄（$before → $after）"; return 1; }
}
run_case A11 KNOWN_FAIL "Bash 改檔 payload 會進 _edits.jsonl（P0-2）" c11

# ── A12 · 新洞 A · dbp 不在時 gate 仍該記帳 ──────────────────────────
# 這是共同失效點：帳本 B 的寫入被 os.path.exists(DBP) 擋在後面。
# dbp 一失效，兩本帳同時空白 —— 複式簿記整個失效，而且完全靜默。
c12() {
  bare="$TMP/bare-home"; mkdir -p "$bare"
  GATE_RUNNER="$HOOK_GATE_SRC"
  [ -x "$GATE" ] && GATE_RUNNER="$GATE"
  before="$(lines "$EDITS")"
  printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/target.py"}}\n' "$FIXTURE" \
    | env HOME="$bare" "$GATE_RUNNER" >/dev/null 2>&1
  after="$(lines "$EDITS")"
  [ "$after" -gt "$before" ] || { echo "dbp 不存在時 gate 連 _edits 都不寫了（$before → $after）"; return 1; }
}
run_case A12 KNOWN_FAIL "dbp 不存在時 gate 仍寫 _edits.jsonl（新洞 A）" c12

# ── A13 · harness 自檢：有沒有污染真帳本 ─────────────────────────────
# plan/001 預期 bug #4。這條不是在驗 repo，是在驗這支測試自己。
# 屠龍者終將成為惡龍 —— 一支會偷寫使用者真帳本的測試，就是那條龍。
c13() {
  [ "$(fingerprint)" = "$FP_BEFORE" ] || {
    echo "真帳本 $REAL_DBP 的指紋變了 —— 這支測試污染了使用者資料"
    return 2   # 不是 1。這是不可逆傷害，必須用最嚴重的那一級。
  }
}
run_case A13 PASS "跑完沒有動到真實 ~/.debugpedia（預期 bug #4）" c13

# ── A14 · 案 002 · cron 不可以安靜無作用 ─────────────────────────────
#
# 這一條是案 002 的核心。理由：
#   一個從沒跑成功過的排程，和一個「每天跑但每次都失敗」的排程，
#   在使用者眼裡長得一模一樣 —— 什麼都沒發生。
#
# 為什麼檢查者是 smoke test 而不是 cron 自己：
#   自己檢查自己的心跳是共同失效點。plan/001 已經推翻過一次這個錯
#   （「heartbeat 也走同一個 shebang」）。所以必須換一條路。
c14() {
  gen="$REPO/cron/generalize.sh"
  [ -f "$gen" ] || { echo "前置不成立：找不到 $gen"; return 2; }
  hb="$TMP/hb.json"
  # 用沙盒 ledger + 明確沒有 LLM 的環境跑
  ( cd "$TMP" && env -u DBP_LLM_CMD DEBUGPEDIA_DIR="$TMP" sh "$gen" >/dev/null 2>&1 )
  rc=$?
  [ "$rc" -ne 0 ] || { echo "沒有 LLM 可用，generalize.sh 竟然 exit 0 —— 這就是安靜無作用"; return 1; }
  real_hb="$REPO/cron/_heartbeat.json"
  [ -f "$real_hb" ] || { echo "失敗了但沒寫心跳 —— 沒有心跳的 cron 等於沒有 cron"; return 1; }
  st="$(sed -n 's/.*"status":"\([a-z]*\)".*/\1/p' "$real_hb")"
  [ "$st" = fail ] || { echo "心跳 status=$st，但這次執行明明失敗了"; return 1; }
  # 「有寫 reason」不夠 —— 必須確認 reason 不是進度訊息。
  # 第一版心跳把 stdout 的「去識別化命中 2 處」當成死因記下來了。
  rs="$(sed -n 's/.*"reason":"\([^"]*\)".*/\1/p' "$real_hb")"
  case "$rs" in
    *命中*處*) echo "心跳的 reason 記的是進度訊息不是死因: $rs"; return 1 ;;
    "") echo "心跳有 status=fail 但 reason 是空的 —— 死得不明不白"; return 1 ;;
  esac
}
run_case A14 PASS "LLM 不可用時 cron 大聲失敗且心跳誠實（案 002）" c14

# ── A15 · 案 002 · 歸納器不得把機密送出去 ────────────────────────────
#
# 這條的驗收設計本身改過一次，過程比結論值錢：
#   原本只寫 `grep -c 'sk-' payload → 必須 0`。那是死碼的溫床 ——
#   如果哪天 payload 改走 argv，攔截檔會是**空的**，grep 回 0，驗收通過，
#   而機密照樣外送。「空檔案」和「乾淨的檔案」在 grep 眼裡完全一樣。
#
#   所以順序必須是：
#     (1) 先證明「攔截真的攔到了東西」（非空、且含得到 ledger 的內容）
#     (2) 才去斷言「裡面沒有機密」
#   拿「某字串不存在」當證據，必須先證明檢查執行到了。
#   —— 2026-07-27 同一個病在這個 repo 裡犯了五次，這條是它的護欄。
c15() {
  gen="$REPO/cron/generalize.sh"
  fix="$REPO/cron/fixtures/sample-response.json"
  [ -f "$gen" ] && [ -f "$fix" ] || { echo "前置不成立：缺 generalize.sh 或 fixture"; return 2; }

  SL="$TMP/secret-ledger"; mkdir -p "$SL"
  MARK="canary-payload-marker-8h3k"
  # 種一筆含假機密的紀錄。MARK 用來證明攔截確實看到了這筆。
  env DEBUGPEDIA_DIR="$SL" "$D" \
    "$MARK curl -H 'Authorization: Bearer sk-SMOKEFAKE1234567890abc' 失敗" \
    -w "$FIXTURE/probe.sh" -t smoke -e "AKIAIOSFODNN7EXAMPLE" </dev/null >/dev/null 2>&1

  PL="$TMP/payload.txt"; rm -f "$PL"
  ( cd "$TMP" && env DEBUGPEDIA_DIR="$SL" \
      DBP_LLM_CMD="cat > '$PL'; cat '$fix'" sh "$gen" >/dev/null 2>&1 )

  # (1) 攔截真的執行到了嗎
  [ -s "$PL" ] || { echo "攔截檔是空的 —— 無法斷言任何事（可能 payload 改走了別條路）"; return 2; }
  grep -q "$MARK" "$PL" || { echo "攔截檔非空但不含種下的標記 —— 攔到的不是這次的 payload"; return 2; }

  # (2) 現在才有資格斷言沒有機密
  for pat in 'sk-SMOKEFAKE' 'AKIAIOSFODNN7' 'Bearer sk-'; do
    grep -q "$pat" "$PL" && { echo "送出的 payload 含未遮罩的 $pat"; return 1; }
  done
  # 家目錄路徑也算 —— 不是密鑰，但是使用者的目錄結構，對歸納毫無幫助
  grep -q "$HOME_T" "$PL" && { echo "送出的 payload 含使用者家目錄路徑"; return 1; }
  return 0
}
run_case A15 PASS "歸納器送出前遮罩機密，且攔截確實生效（案 002）" c15

# ── 總結 ──────────────────────────────────────────────────────────────
printf '\n共 %s 條 · 通過 %s · 已知紅 %s · 回歸 %s · DRIFT %s · BROKEN %s\n' \
  "$((PASS + KNOWN + NEWRED + DRIFT + BROKEN))" "$PASS" "$KNOWN" "$NEWRED" "$DRIFT" "$BROKEN"

if [ "$BROKEN" -ne 0 ]; then
  printf '\n✗ BROKEN —— 測試自己跑不起來，或前置不成立。\n'
  printf '  這比「測出 bug」嚴重：無知比壞消息嚴重。先修 harness，別看其他結果。\n\n'
  exit 2
fi
if [ "$NEWRED" -ne 0 ]; then
  printf '\n✗ 回歸 —— 本案已修好的東西又壞了。\n\n'
  exit 1
fi
if [ "$DRIFT" -ne 0 ]; then
  printf '\n! DRIFT —— 有已知洞今天通過了。\n'
  printf '  這是好消息，但必須留下記錄：改該條 EXPECT 為 PASS，並在 plan/ 開案說明是誰修的。\n'
  printf '  靜靜變綠等於下一個人以為這裡從來沒事。\n\n'
  exit 1
fi
printf '\n✓ 全部與宣告一致。\n'
printf '  注意：「一致」不等於「都好了」—— 上面 %s 條已知紅是刻意留著的，見 plan/001。\n' "$KNOWN"
printf '  一支永遠全綠的 smoke test 是最貴的謊言。\n\n'
exit 0
