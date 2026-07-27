#!/bin/sh
# EXPECT: SEALED
# TARGET: （無 —— 這支不攻擊 repo，攻擊的是 redteam 自己）
# CLAIM: 對一個「確定不存在的洞」發動攻擊，harness 必須回報 SEALED
# WHY: 假紅會訓練人忽略所有紅燈。如果這支報 BREACH，代表 harness 會憑空
#      生出洞，那前面每一支 BREACH 都不可信。
#      這是「測試會不會紅」的反向版：測試會不會亂紅。
. "$RT_LIB"

need "$SANDBOX/bin/dbp"

# 一個絕不可能成立的宣稱：dbp 原始碼裡有 "quantum_teleport" 這個函式
if grep -q 'def quantum_teleport' "$SANDBOX/bin/dbp"; then
  breach "dbp 竟然真的有 quantum_teleport() —— harness 或 repo 有一方極度異常"
fi
sealed "確認不存在的洞正確回報為 SEALED —— harness 不會憑空生洞"
