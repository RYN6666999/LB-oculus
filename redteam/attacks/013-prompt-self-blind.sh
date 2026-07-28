#!/bin/sh
# EXPECT: BREACH
# TARGET: bin/dbp — prompt() 自盲退化
# CLAIM: dbp prompt 對帳本裡有前科的檔案回「無前科」
# WHY: risk() 的過濾條件一旦被改回 len(stem)>3 或加了新盲區，
#      prompt 會靜默回「無前科」—— 假綠比沒有更糟。
. "$RT_LIB"

need "$SANDBOX/bin/dbp"
need "$SANDBOX/hooks/dbp-risk-gate"

# 在沙盒 ledger 種一筆跟 bin/dbp 相關的前科
dbp "dbp prompt 測試前科：bin/dbp 的 bug" -w bin/dbp -t test >/dev/null 2>&1

# 跑 prompt，確認它看到了那筆
out=$(dbp prompt bin/dbp 2>&1)
rc=$?

case "$rc" in
  0)
    breach "dbp prompt bin/dbp exit 0 且輸出: $(printf '%s' "$out" | head -3)"
    ;;
  1)
    # exit 1 有兩個意思：查到前科、檔案不存在。只看 rc 分不出來。
    # 改看輸出內容有沒有包含種下的那筆前科文字
    if printf '%s' "$out" | grep -q 'dbp prompt 測試前科'; then
      sealed "dbp prompt 輸出內容含種下的前科，確認有查到"
    else
      breach "dbp prompt exit 1 但輸出不含種下的前科: $(printf '%s' "$out" | head -5)"
    fi
    ;;
  *)
    broken "dbp prompt 異常退出碼 $rc"
    ;;
esac