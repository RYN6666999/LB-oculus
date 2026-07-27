#!/bin/sh
# EXPECT: BREACH
# TARGET: bin/dbp:69 _all() glob("*.jsonl") → bin/dbp:183 ls()
# CLAIM: _all() 把 harness 帳本（_edits/_runs）也當成 bug 紀錄讀進來，
#        它們沒有 id 欄位，於是 dbp ls 直接 KeyError 崩潰
# WHY: 這是「兩本帳混成一本」的直接後果。
#      前一版我以為觸發條件是 open 紀錄 → 實測 open 完全正常，SEALED。
#      真正的觸發條件是 _edits.jsonl 存在，也就是「hook 真的跑過」之後。
#      諷刺的是：這個 repo 越正常運作，dbp ls 越必然崩潰。
. "$RT_LIB"

dbp "紅隊種下的真實紀錄" -k human >/dev/null 2>&1 || broken "dbp 寫不進去"

# 模擬 hook 正常運作後的產物 —— 這是 repo「健康」時的必然狀態
printf '%s\n' '{"ts":"2026-07-27T00:00:00+00:00","tool":"Edit","path":"/tmp/x.py"}' > "$LEDGER/_edits.jsonl"

out=$(dbp ls 2>&1); rc=$?

if printf '%s' "$out" | grep -q 'KeyError'; then
  # 順手記下第二個事實：崩了卻回 0
  extra=""
  [ "$rc" -eq 0 ] && extra="；而且崩潰後 exit 仍為 0，自動化完全偵測不到"
  breach "_edits.jsonl 存在時 dbp ls 崩潰 KeyError$extra"
fi
printf '%s' "$out" | grep -q '紅隊種下的真實紀錄' \
  || broken "ls 沒印出既有紀錄也沒 KeyError，行為無法判定：$out"
sealed "dbp ls 已能區隔 harness 帳本，不再崩潰"
