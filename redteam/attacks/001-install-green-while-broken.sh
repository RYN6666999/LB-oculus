#!/bin/sh
# EXPECT: SEALED
# TARGET: install.sh:16（已於 plan/001 處置）
# CLAIM: install.sh 曾用 test -e 定義成功，所以 shebang 壞掉時照樣印 ✓ 並 exit 0
# WHY: 這是整個 repo 最嚴重的洞 —— 安裝成功即失敗。只有真的安裝才看得到。
#
# 2026-07-27 · EXPECT 由 BREACH 改為 SEALED。
#   依 redteam/README.md 自己的規定：狀態變了必須改 EXPECT 並在 plan/ 留案。
#   處置見 plan/001（第 2 項）。這一支從此變成**回歸偵測器**：
#   哪天有人把綠勾改回 test -e，這裡會 BREACH → 對 SEALED 而言就是 DRIFT。
#
#   攻擊本身一行未改（除了下面新增的「診斷正確性」一段）。
#   刻意不刪：一個被修好的洞，它的攻擊留著才能防止它回來。
. "$RT_LIB"

need "$SANDBOX/install.sh"

# 把 shebang 指向一個絕不存在的解譯器，模擬「換一台機器」
for f in bin/dbp hooks/dbp-autocapture hooks/dbp-risk-gate; do
  need "$SANDBOX/$f"
  sed -i.bak '1s|.*|#!/nonexistent/python3|' "$SANDBOX/$f" || broken "改不動 $f 的 shebang"
done

HOME_FAKE="$SANDBOX/_home"
mkdir -p "$HOME_FAKE"
out=$(cd "$SANDBOX" && HOME="$HOME_FAKE" sh ./install.sh 2>&1)
rc=$?

# install.sh 說了什麼
ticks=$(printf '%s' "$out" | grep -c '✓')

# 換一條路：那些掛載點真的能跑嗎（不信 ✓，實際執行）
"$HOME_FAKE/.local/bin/dbp" stats >/dev/null 2>&1
real=$?

[ "$real" -eq 0 ] && sealed "掛載點真的能執行了，這個攻擊不再成立"
[ "$real" -eq 127 ] || broken "預期 exit 127（解譯器不存在），實得 $real —— 攻擊前提已變"

if [ "$rc" -eq 0 ] && [ "$ticks" -ge 4 ]; then
  breach "install.sh 印了 $ticks 個 ✓ 且 exit 0，而掛載點實際執行 exit 127"
fi

# ── 新增：診斷正確性也算在封堵範圍內 ──────────────────────────────────
# 2026-07-27 實測，第一版修好的 install.sh 印的是「（exit 0）」而不是「（exit 127）」
# —— 因為 rc=$? 隔著 if 複合指令取。它確實非零退出了，但把使用者指向錯誤的方向：
# 看到 exit 0 的人會去查權限、查路徑，永遠想不到是 shebang。
# 「有報錯」不等於「報對了」。所以這裡連診斷一起驗。
printf '%s' "$out" | grep -q '✗' || breach "install.sh 非零退出但沒印任何 ✗，使用者不知道是哪一項壞了"

# 這裡的取樣範圍必須限定在「✗ 那一行」。
#   第一版寫 `grep -q 'exit 127'` 掃整份輸出 → 假 SEALED。
#   因為 install.sh 結尾有一句無條件印出的「常見原因：…（exit 127）」，
#   它永遠都在，跟 rc 實際是多少完全無關。
#   我在一支專門偵測「有輸出 ≠ 功能存在」的攻擊裡，自己用「輸出裡有這串字」當證據。
#   （本場第三次同型錯誤，已記進鐵律三。）
diag=$(printf '%s\n' "$out" | grep '✗.*\.local/bin/dbp')
[ -n "$diag" ] || broken "找不到 dbp 那一行的 ✗ 診斷，install.sh 的輸出格式變了 —— 攻擊前提已失效"
case "$diag" in
  *"exit 127"*)
    sealed "install.sh 察覺失敗且診斷正確（rc=$rc, ticks=$ticks, ✗ 行報出 exit 127）" ;;
esac
breach "install.sh 的 ✗ 行沒報出真正的 exit 127（實際內容: $diag）—— 診斷把人指往錯的方向"
