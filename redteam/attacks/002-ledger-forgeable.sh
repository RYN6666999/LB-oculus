#!/bin/sh
# EXPECT: BREACH
# TARGET: ~/.debugpedia/*.jsonl（append-only 只是口頭約定）
# CLAIM: 任何人可以直接改寫 ledger，dbp 事後完全看不出來
# WHY: 篡改不可觀測，比「可篡改」更嚴重 —— 帳本失去證據力。
. "$RT_LIB"

dbp "紅隊種下的真實紀錄" -k human -t redteam-probe >/dev/null 2>&1 \
  || broken "dbp 寫不進去，攻擊無法進行"

wk=$(ls "$DPEDIA"/*.jsonl 2>/dev/null | head -1)
[ -n "$wk" ] || broken "ledger 檔沒生出來（dbp add 寫到 $DPEDIA/，不是 $LEDGER/）"

before=$(dbp stats 2>/dev/null | grep -c 'redteam-probe')

# 攻擊一：偽造一筆從未發生的事
printf '%s\n' '{"id":"deadbeef","ts":"2026-07-27T00:00:00+00:00","kind":"bug","who":"human","what":"這件事從來沒發生過","tags":"forged"}' >> "$wk"
# 攻擊二：把既有紀錄改掉
sed -i.bak 's/紅隊種下的真實紀錄/被改寫的內容/' "$wk"
# 攻擊三：整行刪掉
grep -v 'forged' "$wk" > "$wk.tmp" && head -c -1 "$wk.tmp" > /dev/null 2>&1

out=$(dbp stats 2>&1) || broken "篡改後 dbp 直接壞掉，這不是本攻擊要測的"

printf '%s' "$out" | grep -qiE 'tamper|篡改|校驗|checksum|hash|完整性' \
  && sealed "dbp 已能偵測篡改"

printf '%s' "$out" | grep -q 'forged' \
  && breach "偽造紀錄被 dbp 當成真實資料統計，且無任何完整性警告"

grep -q '被改寫的內容' "$wk" \
  && breach "既有紀錄可被改寫，dbp 無感"

sealed "找不到可篡改的縫隙"
