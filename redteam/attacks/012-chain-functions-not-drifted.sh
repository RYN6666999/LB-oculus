#!/bin/sh
# EXPECT: BREACH  （正常 = 四函式都在 bin/dbp 裡、hooks 全清掉了）
# TARGET: hooks/* （統一後 hooks 內不該有獨立的 prev 算式）
# CLAIM: 四函式（chain_prev/read_chain/verify_chain/chain_append）
#          曾散落三處，統一後只能存在 bin/dbp。
# WHY: 同一份 prev 算式寫三遍，改其中一份就漂移。
#       漂移在鏈斷掉之前完全不被察覺 —— 這是「凍結核心 K」要關掉的東西。
. "$RT_LIB"

need "$SANDBOX/bin/dbp"
need "$SANDBOX/hooks/dbp-risk-gate"
need "$SANDBOX/hooks/dbp-autocapture"

# 檢查 hooks 裡不該有獨立的 hash/prev 計算
for hook in "$SANDBOX/hooks/dbp-risk-gate" "$SANDBOX/hooks/dbp-autocapture"; do
  if grep -q 'hashlib\|sha256\|_chain_prev\|"prev"' "$hook" 2>/dev/null; then
    breach "hook $hook 內仍殘留獨立的 hash 或 prev 計算 —— 漂移已發生"
  fi
done

# 檢查四函式都在 bin/dbp
for fn in '_chain_prev' '_read_chain' 'chain_append' 'verify_chain'; do
  if ! grep -q "def $fn" "$SANDBOX/bin/dbp" 2>/dev/null; then
    breach "bin/dbp 缺少 $fn —— 四函式之一從核心消失"
  fi
done

# 檢查 chain_append CLI 存在
if ! "$SANDBOX/bin/dbp" _chain-append 2>&1 | grep -q "用法"; then
  breach "dbp _chain-append CLI 不存在或行為異常"
fi

sealed "四函式皆在 bin/dbp，hooks 無殘留，無漂移"