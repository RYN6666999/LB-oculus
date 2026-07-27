#!/bin/sh
# EXPECT: BREACH
# TARGET: ~/.debugpedia/ledger/（目錄層 — 002 只驗了檔案層）
# CLAIM: sappnd 鎖檔案不夠：mv ledger /tmp/ 再建空目錄，整本帳無聲消失
# WHY: 檔案鎖得再好，目錄沒鎖等於沒鎖。這就是 002 自己寫的手段。
. "$RT_LIB"

need "$SANDBOX/bin/dbp"
need "$PY"

mkdir -p "$LEDGER"
printf '{"ts":1,"path":"/tmp/test","tool":"Edit"}\n' > "$LEDGER/_edits.jsonl"
printf '{"ts":1,"cmd":"echo hi","code":0}\n' > "$LEDGER/_runs.jsonl"

# 攻擊一：append 成功（鎖前正常行為）
echo '{"ts":2,"path":"/tmp/test2","tool":"Edit"}' >> "$LEDGER/_edits.jsonl" \
  || broken "連 append 都不行，攻擊無法進行"

# 攻擊二：刪除檔案成功（鎖前可刪）
rm "$LEDGER/_runs.jsonl" || broken "連 rm 都不行，攻擊無法進行"
touch "$LEDGER/_runs.jsonl"  # 恢復供後續檢查

# 攻擊三（核心）：整個目錄搬走
mv "$LEDGER" /tmp/ledger-stolen 2>/dev/null || broken "mv 失敗，攻擊無法進行"

# 驗證：舊路徑已空，資料在 /tmp/
[ -d "$LEDGER" ] && breach "ledger 目錄搬走後舊路徑還在（不該在）"
[ -f /tmp/ledger-stolen/_edits.jsonl ] || breach "ledger 搬走後 /tmp 裡找不到資料（搬失敗）"

# 重建一個空目錄，假裝什麼都沒發生
mkdir -p "$LEDGER"
ls -la "$LEDGER"/*.jsonl 2>/dev/null \
  && breach "重建 ledger 後舊帳本檔案仍在（不該在，表示沒被搬走）"

# 確認 dbp 讀不到被搬走的資料
out=$("$SANDBOX/bin/dbp" ls 2>&1)
printf '%s' "$out" | grep -q 'test' \
  && sealed "dbp 還能從被搬走的 ledger 讀到資料（不該讀到）"

breach "目錄可整碗搬走，檔案層 sappnd 擋不住目錄級攻擊"