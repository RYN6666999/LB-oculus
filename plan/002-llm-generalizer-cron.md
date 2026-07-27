# 案 002 · 讓錯誤史自己餵養紅隊（cron + LLM 歸納）

| | |
|---|---|
| **狀態** | **已完成（第一階段：只產候選，不自動改紅隊）** |
| 提出 | 2026-07-27 |
| 依據 | 使用者要求：「鐵律三要寫一個 cron 借力 LLM 的動力來歸納總結常見的錯誤，用以優化這個專項抓 bug 的紅隊的能力」 |
| 對應 ledger | `dbp rules` 的既有輸出（規則候選）；plan/001 事後回填新開的條目 |

---

## 核心判斷

**這一案最大的風險不是「歸納得不夠好」，是「歸納失敗了但沒人知道」。**

要接的是一個外部 LLM。外部依賴的失效方式有一整族，而且全部靜默：
沒網路、沒 API key、額度用盡、回傳格式變了、模型改版後不照格式輸出、
cron 根本沒被排進去、排進去了但 PATH 不對所以每次都 exit 127。

`dbp rules` 已經在做本機的統計式歸納了。所以這一案要加的不是「歸納」，
是**「借 LLM 的推理力，把統計看不出來的跨檔同型錯誤講成一條可攻擊的假說」**。

> 統計說「shell 標籤出現 7 次」。
> LLM 該說的是「這 7 次的共同結構是『退出碼被複合指令吃掉』，
> 所以任何 `if cmd; then` 後面取 `$?` 的地方都該有一支攻擊」。

第二句才餵得動紅隊。第一句餵不動。

---

## 這一案推翻了什麼

**推翻我在 plan/001 執行過程中的直覺做法：「讓 cron 自動產生新的 attack 檔」。**

理由是實證的，就發生在今天：
plan/001 執行時，我自己手寫的攻擊 001 產出了一個**假 SEALED** ——
它 `grep 'exit 127'` 掃整份輸出，抓到的是 `install.sh` 結尾一句無條件印出的說明文字，
跟實際 `rc` 毫無關係。同一天我還在 smoke test 裡照抄 plan/001 的斷言，
產出了 A06 那條**永遠會綠**的假斷言。

**一天之內，我這個有完整上下文的 agent，在專門偵測假綠的程式碼裡產了兩個假綠。**
一個只讀得到 ledger 摘要、沒有 repo 上下文的 LLM，產出的攻擊只會更糟。

而假紅／假綠在紅隊裡的傷害是**複利**的：
`redteam/README.md` 自己寫了「假紅會訓練人忽略全部的紅」。
一支自動長出 30 支垃圾攻擊的 cron，會讓這整層測試在兩週內變成沒人看的雜訊。

所以第一階段的邊界劃在這裡：

| cron 可以做 | cron 不可以做 |
|---|---|
| 讀 ledger，送給 LLM，把回答存成候選 | 直接寫進 `redteam/attacks/` |
| 產出「攻擊假說 + 建議的 EXPECT + 該打哪個檔」 | 產出可執行的 `.sh` 並讓 `run.sh` 撿去跑 |
| 把候選記進 `dbp open`（未收尾，會過期會叫） | 自動 commit / push |
| 在 LLM 掛掉時**大聲失敗** | 在 LLM 掛掉時安靜 exit 0 |

**人（或另一個有 repo 上下文的 agent）必須在中間。**
候選要變成攻擊，得經過 `redteam/README.md` 的那套規矩：反向驗證證明它會紅。

---

## 要解決什麼（僅此四項）

### 1 · `cron/generalize.sh` —— 排程外殼，不含任何智慧

只負責：找到 python、餵環境變數、呼叫歸納器、**把失敗變成看得見的東西**。

刻意用 `sh` 而不是 python：cron 環境的 PATH 常常是最小的，
外殼本身不能有「需要先能跑 python」這個前提 ——
那正是 plan/001 那個 shebang 洞的同一個成因。

### 2 · `cron/generalize.py` —— 歸納器

- 讀 ledger（走 `DEBUGPEDIA_DIR`，不硬寫路徑）
- **本機先做去識別化**：ledger 裡有 `cwd`、`evidence`、可能有機密（P1-6 還沒修）。
  在 P1-6 修好之前，把 ledger 原封不動送出去等於把使用者的機密外送。
  這一項不是加分項，是**送出前的必要條件**。
- 呼叫 LLM，要求輸出嚴格 JSON
- 校驗回傳結構；不合格就是失敗，**不接受「盡力解析」**
- 產出 `cron/candidates/YYYY-MM-DD.md` + 一筆 `dbp open`

### 3 · 心跳（heartbeat）—— 這一項是整案的核心

**沒有心跳的 cron 等於沒有 cron。** 一個從來沒跑成功過的排程，
和一個「跑了但每次都失敗」的排程，在使用者眼裡長得一模一樣：什麼都沒發生。

做法：每次執行**無論成敗**都寫 `cron/_heartbeat.json`（狀態 + 時間 + 原因）。
然後 —— 這才是關鍵 —— **由 smoke test 去讀那個心跳**。

> 心跳不能由 cron 自己檢查。那是共同失效點，
> 也是 plan/001 已經推翻過一次的錯（「heartbeat 也走同一個 shebang」）。
> 所以檢查者必須是另一條路：`tests/smoke.sh`。

### 4 · `tests/smoke.sh` 增加 A14 / A15 兩條斷言

| 斷言 | 抓什麼 |
|---|---|
| A14 · LLM 不可用時 `generalize.sh` 必須非零退出且心跳寫 `status=fail` | 靜默無作用（本案最大風險） |
| A15 · 歸納器不得把 `sk-` 樣式送出（用假 key 種進沙盒 ledger 驗） | 機密外送（不可逆傷害） |

---

## 不解決什麼（明確排除）

| 排除項 | 為什麼留給後續案 |
|---|---|
| 自動產生 `redteam/attacks/*.sh` | 見上面「推翻了什麼」。要等候選的品質有兩週以上的實測記錄 |
| 自動安裝 crontab | 改使用者的 crontab 是有副作用的全域操作。跟 `settings.json` 同一條理由：印指令給人看，不代替人做 |
| 選哪一家 LLM／付費 | 用 `DBP_LLM_CMD` 讓使用者自己指定指令。硬綁一家等於幫使用者決定他的帳單 |
| 把候選寫回 ledger 當「錯誤」 | 候選是**假說**不是錯誤。混進 ledger 會污染 `dbp stats` 的分母（P0-1b 的同型錯誤） |
| 歸納結果的品質評估 | 需要先累積候選，然後回頭看「哪些候選後來真的變成攻擊」。這是案 003 |

---

## 驗收方式（產出者不得自驗）

**我寫的是 cron 與歸納器，所以不准用「讀 generalize.py」或「它印了成功」驗。**

```bash
# 1 · 沒有 LLM 的環境（絕大多數第一次跑的情況）—— 必須大聲失敗
unset DBP_LLM_CMD
sh cron/generalize.sh; echo "無 LLM exit=$?"        # 必須非 0
cat cron/_heartbeat.json                            # 必須 status=fail 且有 reason

# 2 · LLM 回垃圾 —— 必須拒收，不准「盡力解析」
DBP_LLM_CMD='echo 這不是JSON' sh cron/generalize.sh; echo "垃圾回應 exit=$?"   # 必須非 0

# 3 · LLM 回格式對的東西 —— 必須產出候選檔
DBP_LLM_CMD='cat cron/fixtures/sample-response.json' sh cron/generalize.sh
echo "正常 exit=$?"                                  # 必須 0
ls cron/candidates/                                  # 必須有今天的檔

# 4 · 機密不得外送（反向驗證，這條最重要）
#    在沙盒 ledger 種一筆含假 key 的紀錄，攔下送出的 payload 檢查
DBP_LLM_CMD='cat > /tmp/payload.txt; cat cron/fixtures/sample-response.json' \
  DEBUGPEDIA_DIR=/tmp/secret-ledger sh cron/generalize.sh
grep -c 'sk-' /tmp/payload.txt                       # 必須 0

# 5 · 心跳必須由另一條路檢查
bash tests/smoke.sh                                  # A14/A15 必須出現在清單裡
```

**第 1、4 步是驗收的核心。**
第 1 步因為「靜默無作用」是本案唯一會讓整件事白做的失效方式；
第 4 步因為機密外送是不可逆的 —— 送出去就收不回來了。

---

## 預期會出什麼 bug（100% 前提的直接後果）

| # | 預期 | 為什麼會發生 | 嚴重度 |
|---|---|---|---|
| 1 | 去識別化的正則漏抓某種 key 格式 | 我只想得到 `sk-` / `ghp_` / `Bearer`。世界上的 key 格式比我想得到的多 | **高 · 長期** |
| 2 | cron 在真實 crontab 裡因 PATH 不同而 exit 127 | 這正是 shebang 洞的同一成因，而 cron 的環境比 shell 更貧瘠 | **高 · 短期** |
| 3 | 心跳檔本身變成腐朽宣稱 | 它自稱是現況。如果 cron 停了三個月，`_heartbeat.json` 會靜靜宣稱著三個月前的成功 | 高 · 長期 |
| 4 | LLM 產出的候選讀起來很有道理，但全部不可執行 | 沒有 repo 上下文的歸納傾向產出「應該加強測試」這種正確但無用的話 | 中 · 短期 |
| 5 | 候選檔越積越多，沒人看 | 跟 `dbp open` 一樣需要會過期會叫。第一階段只做到「記一筆 open」，不夠 | 中 · 長期 |
| 6 | 我會忍不住在第一階段就自動生 attack | 誘惑很大，因為那看起來才像「閉環」。但今天的兩個假綠就是反例 | 中 · 短期 |
| 7 | 用 `cat > /tmp/payload.txt` 驗證外送內容這招，只驗到 stdin 那條路 | 若歸納器改成用 argv 或環境變數傳 payload，這條驗收會靜靜失效 | 中 · 長期 |

**最可能出事的是 #1 和 #3。**
#1 因為它不可逆；#3 因為它會讓整層監控變成「看起來有在跑」——
那正是 `install.sh:16` 的病，只是換了個地方發作。

---

## 事後回填

> 執行後填。留空代表**未執行**。

- **實際結果**：四個檔（`cron/generalize.sh`、`cron/generalize.py`、`cron/fixtures/sample-response.json`、`cron/README.md`）
  建立完成。驗收 1–5 步全數走過，見下方落差欄。`tests/smoke.sh` 增加 A14/A15，共 16 條。

- **與預期的落差**：
  - **預期 bug #7 提前現形，且比預期嚴重。** 我原本打算用 `DBP_LLM_CMD='cat > /tmp/payload.txt'`
    驗證外送內容，寫到一半發現：**這條驗收自己就是死碼的溫床**。
    如果哪天歸納器改成把 payload 塞進 argv，`cat` 什麼都收不到 → payload.txt 是空的
    → `grep -c 'sk-'` 回 0 → **驗收通過，機密照樣外送**。
    「空檔案」和「乾淨的檔案」在 `grep -c` 眼裡完全一樣。
    處置：改成先斷言 payload 檔**必須非空且必須含得到 ledger 的內容**（證明攔到了真東西），
    才去斷言它不含機密。已寫進 A15。
  - **預期 bug #1 立刻命中。** 第一版遮罩只寫了 `sk-[A-Za-z0-9]{8,}`，
    實測 ledger 裡 plan/001 那筆紀錄含 `/tmp/inst-broken/.local/bin/dbp` 這種絕對路徑 ——
    不是密鑰但是使用者的目錄結構，一樣不該外送。已加入路徑正規化。
  - **未命中：#2。** 因為第一階段刻意不裝 crontab（見「不解決什麼」），
    所以 PATH 問題尚未有機會發作。**這不代表它不存在** ——
    它只是被延後到使用者真的排程那一天。已記一筆 `dbp open` 追蹤。

- **新開的 ledger 條目**：見 `dbp find cron` 與 `dbp find 遮罩`。

- **推翻了本案哪些判斷**：
  推翻了「用 `cat > file` 攔 payload 就能驗證沒有外送機密」這個驗收設計 ——
  它把「沒攔到」和「攔到了但很乾淨」混為一談。
  這跟今天 attack 001 的假 SEALED、smoke A06 的假斷言是**同一個病**：
  **拿「某個東西不存在」當證據，卻沒有先證明「檢查真的執行到了」。**
  一天之內第四次。已升格為一條規則寫進 `cron/README.md`。
