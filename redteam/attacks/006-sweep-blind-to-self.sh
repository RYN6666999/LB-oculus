#!/bin/sh
# EXPECT: BREACH
# TARGET: bin/dbp:361 SWEEP_EXT
# CLAIM: sweep 只看白名單副檔名，看不見「無副檔名的可執行檔」—— 包含它自己
# WHY: 屠龍者對自己完全瞎。repo 的核心資產 bin/dbp、hooks/* 全都無副檔名。
. "$RT_LIB"

need "$SANDBOX/bin/dbp"
probe="$SANDBOX/_probe_target"
mkdir -p "$probe"

# 同一個必死引用，種在兩種檔案裡
REF='config/definitely-does-not-exist-9z8y7x.yaml'
printf '#!/usr/bin/env python3\nREF = "%s"\n' "$REF" > "$probe/somehook"
chmod +x "$probe/somehook"
printf 'REF = "%s"\n' "$REF" > "$probe/control.py"

# 注意：sweep 找到死引用時仍然 exit 0，所以不能用 || broken 判定失敗
# （前一版就是這樣誤把正常執行判成 BROKEN）。改為檢查輸出內容。
out=$(dbp sweep "$probe" 2>&1)
printf '%s' "$out" | grep -q 'sweep' || broken "sweep 沒有正常輸出，無法判定：$out"

# 對照組：證明 sweep 本身是活的（否則兩邊都沒抓到會被誤判成 BREACH）
printf '%s' "$out" | grep -q 'control.py' \
  || broken "對照組 control.py 沒被抓到 —— sweep 整體失效，非本攻擊標的"

printf '%s' "$out" | grep -q 'somehook' \
  && sealed "sweep 已能掃無副檔名的可執行檔"

breach "同一個死引用：control.py 被抓到，無副檔名的 somehook 被忽略 —— sweep 看不見 bin/dbp 與 hooks/*"
