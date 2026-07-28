#!/bin/sh
# EXPECT: BREACH
# TARGET: ~/.debugpedia/ledger/_edits.jsonl（截尾）
# CLAIM: 刪最後 N 行，雜湊鏈前綴自洽，verify-chain --anchor 也通過（舊 hash 在前面仍在鏈上）
# WHY: 想抹掉剛做過的事最省力的手法就是砍尾巴。改中間和換本都擋了，截尾還沒擋。
. "$RT_LIB"

need "$SANDBOX/bin/dbp"
need "$PY"

mkdir -p "$LEDGER"

# 寫 5 筆有 prev 的鏈紀錄
prev="genesis"
for i in 1 2 3 4 5; do
  rec="{\"ts\":$i,\"path\":\"/tmp/attack-test-$i\",\"tool\":\"Edit\",\"prev\":\"$prev\"}"
  printf '%s\n' "$rec" >> "$LEDGER/_edits.jsonl"
  prev=$(printf '%s' "$rec" | "$PY" -c "import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())")
done

# 記下錨點（含筆數）
anchor_out=$(dbp anchor 2>&1) || broken "dbp anchor 失敗: $(printf '%s' "$anchor_out" | tail -1)"
OLD_HASH=$(printf '%s' "$anchor_out" | awk '{print $2}')
OLD_COUNT=$(printf '%s' "$anchor_out" | awk '{print $3}')
[ -n "$OLD_HASH" ] || broken "取不到舊錨點 hash"
[ -n "$OLD_COUNT" ] || broken "取不到舊錨點筆數"

# 攻擊：砍掉最後 2 行
"$PY" -c "
lines = open('$LEDGER/_edits.jsonl').read().strip().splitlines()
open('$LEDGER/_edits.jsonl', 'w').write('\n'.join(lines[:-2]) + '\n')
"

# 檢驗 1：verify-chain 仍通過（前綴自洽）
if dbp verify-chain 2>&1; then
  breach "verify-chain 仍通過：截尾後前綴自洽"
fi

# 檢驗 2（核心）：verify-chain --anchor <舊錨點> 也通過（舊 hash 在前面仍在鏈上）
anchor_flag="${OLD_HASH}:${OLD_COUNT}"
if dbp verify-chain --anchor "$anchor_flag" 2>&1; then
  breach "截尾後旧 anchor 仍通過（hash 在前段仍在鏈上）：這是截尾攻擊未擋住的根因"
fi

# 檢驗 3：如果連 hash-only（不帶 n）都過 = 完全沒擋
if dbp verify-chain --anchor "$OLD_HASH" 2>&1; then
  breach "截尾後 hash-only anchor 也通過：連截尾警告都沒有"
fi

sealed "verify-chain 正確拒絕了截尾後的舊錨點（筆數不符或位置偏移）"