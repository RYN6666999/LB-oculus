#!/bin/sh
# EXPECT: BROKEN
# TARGET: （無 —— 這支攻擊 redteam 自己）
# CLAIM: 前置條件不成立時，harness 必須回報 BROKEN，不可以誤報成 SEALED
# WHY: 這是整份 redteam 最重要的一支。
#      如果「跑不起來」被算成「攻擊失敗（洞補好了）」，那 redteam 整個壞掉的
#      那天會顯示成一片綠 —— 那正是 install.sh:16 用 test -e 定義成功的錯。
#      紅隊工具重演被攻擊者的錯，就沒有存在價值。
. "$RT_LIB"

need "$SANDBOX/this-file-must-never-exist-4k3j2h"
breach "need() 沒有攔下缺失的前置條件 —— harness 的三態判定壞了，所有結果都不可信"
