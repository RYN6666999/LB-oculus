# `redteam/` · 再一層的測試工具

`audit/` 是**一次性的**複驗報告：2026-07-27 那天，那台機器上，那些洞在。
它證明不了明天還在、也證明不了明天修好了。報告會腐朽，**攻擊不會**。

這裡放可重跑的攻擊。價值不在「今天跑過了」，在於**某天攻擊本來會成功、突然不成功了**。

```sh
./redteam/run.sh          # 全部
./redteam/run.sh 001 004  # 只跑指定編號
```

## 語意是反的

| 結果 | 退出碼 | 意思 |
|---|---|---|
| **BREACH** | 0 | 攻擊成功 = **洞還在** = 這一刻正確 |
| **SEALED** | 1 | 攻擊失敗 = 洞補好了 = 去更新預期 |
| **DRIFT** | 1 | 實際 ≠ 檔頭宣告的 `EXPECT` |
| **BROKEN** | 2 | **攻擊自己跑不起來 = 最嚴重** |

BREACH 是綠色的，因為**「已知的洞還在原地」是可信狀態**。
洞消失了反而要停下來查：真的修好了，還是攻擊瞎了？

### 為什麼 BROKEN 的退出碼比 DRIFT 大

DRIFT 是「你知道有事變了」。BROKEN 是「你什麼都不知道」。**無知比壞消息嚴重。**

如果把「跑不起來」算成「攻擊失敗（洞補好了）」，那 redteam 整份壞掉的那天會顯示成
一片綠 —— 那正是 `install.sh:16` 用 `test -e` 定義成功的錯。
**紅隊工具重演被攻擊者的錯，就沒有存在價值。** 所以 BROKEN 是預設，攻擊必須主動證明自己走到了結論。

## 複式簿記怎麼套在紅隊上

每支攻擊在檔頭宣告 `EXPECT`，runner **從檔頭讀取、不在自己身上抄一份**（鐵律一）。
兩邊不一致才叫警報 —— 這就是兩本帳。

runner 也不信任攻擊的自我回報：任何非 0/1/2 的退出碼一律歸 BROKEN，
不會被當成「攻擊失敗」。

## 兩支 canary 在監視 harness 自己

| 攻擊 | EXPECT | 守什麼 |
|---|---|---|
| `900-canary-must-be-sealed` | SEALED | **不會憑空生洞**。假紅會訓練人忽略所有紅燈 |
| `901-canary-must-be-broken` | BROKEN | **前置條件不成立必須 BROKEN**，不可誤報成 SEALED |

901 是整份 redteam 最重要的一支。已實測：把 `lib.sh` 的 `need()` 改成永遠通過
（模擬 harness 被閹割），901 立刻由 BROKEN 變 BREACH → **DRIFT，exit 1**。
harness 抓到了自己被閹割。

## 目前的攻擊

| # | 標的 | EXPECT | 宣稱 |
|---|---|---|---|
| 001 | `install.sh:16` | BREACH | 印 6 個 ✓ 並 exit 0，而掛載點實際 exit 127 |
| 002 | `*.jsonl` | BREACH | 帳本可偽造 / 改寫 / 刪行，dbp 全程無感 |
| 003 | `dbp:202` | BREACH | `pytest --version` 這種空殼指令算「驗過」 |
| 004 | `risk-gate:41` | BREACH | dbp 缺席 → 帳本 B 歸零且不留痕（共同失效點） |
| 005 | `dbp:223` | BREACH | `unverified()` 零路由，兩本帳從未對帳 |
| 006 | `dbp:361` | BREACH | 看不見無副檔名的可執行檔 —— 包含它自己 |
| 007 | `dbp:69/183` | BREACH | `_edits.jsonl` 一存在，`dbp ls` 就 KeyError（且 exit 仍 0） |
| 008 | `dbp:573` | BREACH | 打錯的子指令被寫成一筆 bug，污染帳本 |
| 900 | （harness） | SEALED | 不憑空生洞 |
| 901 | （harness） | BROKEN | 三態判定沒壞 |

沙盒：每支跑在 `mktemp -d` 的 repo 複本 + 空 ledger（`DEBUGPEDIA_DIR`），
改壞它不影響真 repo，也不污染 `~/.debugpedia`。

## 新增一支攻擊

檔名 `NNN-短標題.sh`，放進 `attacks/`，檔頭四行必填：

```sh
#!/bin/sh
# EXPECT: BREACH        # BREACH | SEALED | BROKEN
# TARGET: bin/dbp:123   # 攻哪一行
# CLAIM: 一句話宣稱      # 攻擊成功代表什麼
# WHY: 為什麼這個洞值得一支專屬攻擊
. "$RT_LIB"
```

可用：`$SANDBOX` `$LEDGER` `$PY`、`dbp` 函式（繞過 shebang）、`need`/`breach`/`sealed`/`broken`。

**三條規矩**（都是踩過才寫下來的）：

1. **前置條件不成立要 `broken`，不可以 `sealed`。** 用 `need`。
2. **要驗「有沒有做該做的事」，不是「有沒有反應」。**
   攻擊 005 第一版用「`dbp unverified` 有回應」判定功能存在 → 假 SEALED。
   實查發現「有回應」是因為 fallthrough 把它當 bug 記進帳了。**有輸出 ≠ 功能存在。**
3. **別用 `|| broken` 判斷「找到問題」的指令。**
   攻擊 006 第一版對 `dbp sweep` 這樣寫 → sweep 正常執行（找到死引用仍 exit 0）卻被判 BROKEN。

## 這一層自己的極限（先說清楚）

- 只能攻擊**已知**的洞。全綠不代表安全，代表「已知的洞都還在原地」。
- 沙盒是 `cp -R` 的複本，**不驗 symlink 安裝的真實行為**。001 用假 `HOME` 近似。
- 只在 Linux / Python 3.13 驗過。**macOS 未驗** —— 那正是 shebang 洞的所在平台，最該補。
- runner 自己沒有 canary 監視「runner 會不會漏跑攻擊」。零攻擊已擋（exit 2），但
  「跑了 8 支卻只回報 5 支」目前偵測不到。

## 與其他部分的關係

| 目錄 | 時間性 | 角色 |
|---|---|---|
| `audit/` | 一次性快照 | 那天發現了什麼 |
| **`redteam/`** | **可重跑** | **那些洞今天還在嗎** |
| `plan/` | 事前宣告 | 打算怎麼修、預期出什麼 bug |
| `~/.debugpedia/` | 累積 | 鐵律三的帳本 |

修東西前後都該跑一次 `./redteam/run.sh`。
**DRIFT 就是「有洞被動到了」的信號**，該去 `plan/` 開一案。
