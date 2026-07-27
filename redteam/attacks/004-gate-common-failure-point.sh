#!/bin/sh
# EXPECT: BREACH
# TARGET: hooks/dbp-risk-gate:41-42
# CLAIM: ledger 寫入被擋在 os.path.exists(DBP) 之後，dbp 不在時 gate 靜默放行且不留痕
# WHY: 共同失效點讓複式簿記歸零 —— 帳本 B 依賴帳本 A 的工具存在。
#      shebang 一壞，兩本帳同時歸零，而 install.sh 的 ✓ 照樣發光。
. "$RT_LIB"

need "$SANDBOX/hooks/dbp-risk-gate"

FAKE_HOME="$SANDBOX/_home4"
mkdir -p "$FAKE_HOME/.local/bin"
# 刻意「不」提供 ~/.local/bin/dbp —— 模擬 dbp 壞掉或沒安裝
[ -e "$FAKE_HOME/.local/bin/dbp" ] && broken "沙盒不乾淨，dbp 不該存在"

payload='{"tool_name":"Edit","tool_input":{"file_path":"'"$SANDBOX"'/bin/dbp"}}'
out=$(printf '%s' "$payload" | HOME="$FAKE_HOME" DEBUGPEDIA_DIR="$FAKE_HOME/.debugpedia" \
        "$PY" "$SANDBOX/hooks/dbp-risk-gate" 2>&1)
rc=$?

[ "$rc" -eq 0 ] || broken "gate 退出碼 $rc（應永遠 0，不得阻擋）—— 這是另一個 bug，非本攻擊標的"

# 帳本 B 有留下任何痕跡嗎
edits="$FAKE_HOME/.debugpedia/_edits.jsonl"
if [ -s "$edits" ]; then
  sealed "dbp 缺席時 gate 仍寫入了 _edits.jsonl，共同失效點已解除"
fi

breach "dbp 缺席 → gate 靜默 exit 0 且 _edits.jsonl 完全沒產生（帳本 B 歸零，無痕跡）"
