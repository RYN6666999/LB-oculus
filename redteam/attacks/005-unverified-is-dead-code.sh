#!/bin/sh
# EXPECT: BREACH
# TARGET: bin/dbp:223 unverified() / main()
# CLAIM: 兩本帳從未對帳 —— unverified() 沒有任何 CLI 路由，是死碼
# WHY: 帳本 B 對防漂移的貢獻是「零」，不是「弱」。複式簿記名存實亡。
#
# 前一版的錯（保留為教材）：我用「dbp unverified 有回應」判定功能存在，
# 結果 SEALED。實查發現「有回應」是因為 main() 的 fallthrough 把
# "unverified" 當成 bug 描述記進帳了 —— 那是另一個洞，不是功能。
# 教訓：有輸出 != 功能存在。要驗「有沒有做該做的事」，不是「有沒有反應」。
. "$RT_LIB"

need "$SANDBOX/bin/dbp"
grep -q 'def unverified' "$SANDBOX/bin/dbp" || sealed "unverified() 已不存在（可能已改名或整併）"

routed=$("$PY" - "$SANDBOX/bin/dbp" << 'PYEOF'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'\ndef main\(', src)
body = src[m.end():] if m else ""
print("Y" if re.search(r'\bunverified\s*\(', body) else "N")
PYEOF
) || broken "解析原始碼失敗"

[ "$routed" = "Y" ] && sealed "main() 已呼叫 unverified()，兩本帳有機會對帳了"

# 換一條路（鐵律二）：真的跑一次，但這次驗「行為」不驗「有無輸出」。
# 對帳功能若存在，讀了 _edits.jsonl 就該提到那個未驗過的檔名。
printf '%s\n' '{"ts":"2026-07-27T00:00:00+00:00","tool":"Edit","path":"/tmp/never-verified-7x6w.py"}' \
  > "$LEDGER/_edits.jsonl"
: > "$LEDGER/_runs.jsonl"

hit=0
for sub in unverified unverify drift reconcile; do
  o=$(dbp "$sub" 2>&1)
  printf '%s' "$o" | grep -q 'never-verified-7x6w' && hit=1
done
[ "$hit" -eq 1 ] && sealed "有子指令真的讀了 _edits.jsonl 並報出未驗檔案，對帳已接上"

breach "unverified() 存在但 main() 零路由；種了未驗紀錄進 _edits.jsonl，4 種子指令沒有一個報出來 —— 死碼，兩本帳從未對帳"
