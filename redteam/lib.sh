#!/bin/sh
# redteam/lib.sh — 每個攻擊腳本都 source 這支。
#
# ─── 語意是反的，先讀懂再改 ────────────────────────────────────────
#   BREACH (exit 0)  攻擊成功 = 洞還在 = 這一刻「正確」
#   SEALED (exit 1)  攻擊失敗 = 洞補好了 = 該去更新預期
#   BROKEN (exit 2)  攻擊自己跑不起來 = 最嚴重，此刻你什麼都不知道
#
# 為什麼 BROKEN 要獨立成一態：
#   如果把「跑不起來」算成「攻擊失敗」，那整份 redteam 壞掉的那天
#   會顯示成一片綠。那正是 install.sh:16 的錯（用 test -e 定義成功）。
#   紅隊工具重演被攻擊者的錯，就沒有存在價值。
#
# 因此：BROKEN 是預設。攻擊必須「主動證明」自己走到了結論。
# ──────────────────────────────────────────────────────────────

breach() { printf '%s\n' "BREACH: $*" >&2; exit 0; }
sealed() { printf '%s\n' "SEALED: $*" >&2; exit 1; }
broken() { printf '%s\n' "BROKEN: $*" >&2; exit 2; }

# $DPEDIA  一份清潔的 ~/.debugpedia 模擬目錄（DEBUGPEDIA_DIR 指向它）
# $LEDGER  $DPEDIA/ledger（攻擊直接往這裡寫檔案）
# $PY       這台機器上真的能跑的 python3

# 繞過 shebang 直接用解譯器跑 dbp。
# 給「不是在測 shebang」的攻擊用 —— 否則 Linux 上每條都會因為
# /opt/homebrew/bin/python3 不存在而 BROKEN，測不到真正想測的東西。
dbp() { DEBUGPEDIA_DIR="$DPEDIA" "$PY" "$SANDBOX/bin/dbp" "$@"; }

# 前置條件不成立時要 BROKEN，不可以 SEALED。
need() { [ -e "$1" ] || broken "前置條件不成立，缺少 $1"; }

# 取得 DEBUGPEDIA_DIR 的預設值（單一來源，從 bin/dbp 讀取）
# 路徑定義只存在 bin/dbp 的 DIR 變數，其他地方一律讀這裡。
# 讀不到就用 ~/.debugpedia。
dbp_default_dir() {
  "$SANDBOX/bin/dbp" _dir 2>/dev/null || echo "$HOME/.debugpedia"
}
