#!/bin/sh
# EXPECT: BREACH
# TARGET: bin/dbp:573 main() fallthrough
# CLAIM: 打錯的子指令會被當成 bug 描述寫進帳本，且回報成功
# WHY: 這是紅隊 005 誤判時意外挖出來的新洞。
#      帳本會被自己的手滑污染 —— 錯字變成「錯誤紀錄」，而鐵律三的帳本
#      一旦混入雜訊，統計與 dbp rules 歸納出的「法則」就全部失真。
. "$RT_LIB"

typo='unverifiedd'
out=$(dbp "$typo" 2>&1); rc=$?

# 帳本裡真的有這筆嗎（看檔案，不看輸出 —— 鐵律二）
if grep -q "$typo" "$LEDGER"/*.jsonl 2>/dev/null; then
  breach "打錯的子指令「$typo」被寫成一筆 bug 紀錄（exit=$rc），帳本被錯字污染"
fi
printf '%s' "$out" | grep -qiE '未知|unknown|usage|用法|不認識' \
  && sealed "未知子指令已被正確拒絕"
broken "既沒寫進帳本也沒報錯，行為無法判定：$out"
