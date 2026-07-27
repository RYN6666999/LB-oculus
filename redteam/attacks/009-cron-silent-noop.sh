#!/bin/sh
# EXPECT: SEALED
# TARGET: cron/generalize.sh · cron/generalize.py（案 002 第一階段）
# CLAIM: 接外部 LLM 的排程最可能的失效不是「歸納得不好」，是「失敗了但沒人知道」
# WHY: 「從沒跑過」和「每天跑但每次都失敗」在使用者眼裡長得一模一樣 —— 什麼都沒發生。
#      這一支是案 002 的守門人：cron 只要學會安靜，這層就等於不存在。
. "$RT_LIB"

need "$SANDBOX/cron/generalize.sh"
need "$SANDBOX/cron/generalize.py"

# ledger 要有東西，否則歸納器會在更早的地方就失敗，驗不到我們要驗的那段
DEBUGPEDIA_DIR="$LEDGER" "$PY" "$SANDBOX/bin/dbp" \
  "紅隊種子：退出碼被複合指令吃掉" -w install.sh:52 -t shell >/dev/null 2>&1
[ -d "$LEDGER" ] || broken "種不進 ledger，攻擊前提不成立"

HB="$SANDBOX/cron/_heartbeat.json"
rm -f "$HB"

# ── 攻擊面 1 · 沒有 LLM 時會不會安靜成功 ─────────────────────────────
out=$(cd "$SANDBOX" && env -u DBP_LLM_CMD DEBUGPEDIA_DIR="$LEDGER" \
      sh cron/generalize.sh 2>&1)
rc=$?
[ "$rc" -eq 0 ] && breach "沒有 LLM 可用卻 exit 0 —— 安靜無作用，排程等於不存在"

# ── 攻擊面 2 · 失敗了有沒有留下心跳 ──────────────────────────────────
[ -f "$HB" ] || breach "失敗後沒寫心跳 —— 使用者無法區分「沒跑過」與「跑了但失敗」"

st=$(sed -n 's/.*"status":"\([a-z]*\)".*/\1/p' "$HB")
[ "$st" = "fail" ] || breach "這次執行失敗了，心跳卻寫 status=$st"

# ── 攻擊面 3 · 心跳的死因是真死因，還是進度訊息 ──────────────────────
# 第一版把 stdout 的「去識別化命中 2 處」記成死因。
# 一個把進度當死因記下來的心跳，比沒有心跳更糟：它會誤導追查方向。
rs=$(sed -n 's/.*"reason":"\([^"]*\)".*/\1/p' "$HB")
[ -n "$rs" ] || breach "心跳有 status=fail 但 reason 空白 —— 死得不明不白"
case "$rs" in
  *命中*處*) breach "心跳的 reason 是進度訊息不是死因: $rs" ;;
esac

# ── 攻擊面 4 · 回傳垃圾時會不會「盡力解析」 ──────────────────────────
# 一個能容忍垃圾輸入的解析器，會把垃圾當成知識存起來，
# 而存起來的垃圾長得跟知識一模一樣。
out2=$(cd "$SANDBOX" && env DEBUGPEDIA_DIR="$LEDGER" \
       DBP_LLM_CMD='echo 我覺得你們應該加強測試覆蓋率' sh cron/generalize.sh 2>&1)
rc2=$?
[ "$rc2" -eq 0 ] && breach "LLM 回了非 JSON 的廢話，歸納器卻 exit 0 收下了"

# ── 攻擊面 5 · 最惡毒的一種：exit 0 但什麼都沒輸出 ───────────────────
# 這是本攻擊最重要的一段。`true` 完美模擬「API 回 200 但 body 是空的」，
# 而那是雲端服務最常見的靜默失效。看起來成功，實際毫無產出。
#
# 反向驗證的過程值得留下：
#   我先只拆掉 generalize.py 的「零輸出」守衛，這一面**沒有翻態**。
#   一度以為是死碼。查清楚後發現是**兩道防線互為備援** ——
#   零輸出守衛掉了，parse_strict 的「找不到 JSON 物件」還會接住空字串。
#   把兩道都拆掉，這一面立刻 BREACH。
#
#   所以那不是攻擊的 bug，是我反向驗證的手法不夠精準：
#   **「拆掉一道防線後行為不變」不代表這一面是死碼，也可能代表縱深防禦生效。**
#   要分辨這兩者，唯一的方法是把所有可能接住它的路徑一起拆。
out3=$(cd "$SANDBOX" && env DEBUGPEDIA_DIR="$LEDGER" \
       DBP_LLM_CMD='true' sh cron/generalize.sh 2>&1)
rc3=$?
[ "$rc3" -eq 0 ] && breach "LLM 指令 exit 0 但零輸出，歸納器竟判定成功 —— 最危險的假綠"

# ── 攻擊面 6 · 成功時真的有產物嗎（不能只信它印「成功」）─────────────
today=$("$PY" -c 'import datetime;print(datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d"))')
(cd "$SANDBOX" && env DEBUGPEDIA_DIR="$LEDGER" \
   DBP_LLM_CMD="cat cron/fixtures/sample-response.json" sh cron/generalize.sh >/dev/null 2>&1)
rc4=$?
[ "$rc4" -eq 0 ] || broken "餵合格 fixture 仍失敗（rc=$rc4）—— 攻擊前提已變，先修 cron 再看這支"
cand="$SANDBOX/cron/candidates/$today.md"
[ -f "$cand" ] || breach "回報成功但沒有產出候選檔 —— 有輸出 ≠ 功能存在"
[ -s "$cand" ] || breach "候選檔存在但是空的"

# 產物必須真的含 LLM 給的內容，不是一個空殼模板。
# 「檔案存在」是 test -e 級別的證據，這個 repo 禁這種驗法。
grep -q '退出碼被 shell 複合指令吞掉' "$cand" \
  || breach "候選檔沒有帶進 LLM 回應的內容 —— 產出了一個空殼"

sealed "cron 在五種失效下都大聲失敗、心跳誠實、成功時產物有實際內容"
