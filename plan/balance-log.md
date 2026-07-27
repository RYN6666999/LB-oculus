# 平衡點紀錄 · 輪次 2（本輪）

> 產生於 2026-07-27T16:20+08:00
> 規則：新抓到數 <= 新產生數 的那一輪，停止在 LB-oculus 上加東西，改為搬去 neuralis 實戰。

---

## 本輪統計（步驟 4）

| 類別 | 數量 | 說明 |
|------|------|------|
| 審核方指出 | 6 | 1)步驟 0 順序做反 2)ANCHORS 比對含時間戳 3)帳本空的 4)自違規沒追 5)防作弊條款 6)鏈斷在第 3 行 |
| 自己產生/發現 | 8 | 1)chain_append 實作 2)hook 改 subprocess 呼叫 3)chain_append 自動補 sha/mtime 4)_chain_prev 接地前偵測 5)zsh preexec/precmd 架構 6)背景子 shell 防 SIGHUP 7)git pre-commit hook 8)anchor.sh 去重邏輯 |

**新抓到數 (6) <= 新產生數 (8)** → 條件 B 本次成立。

---

## 出場條件 A：自違規

當前資料（本機 macOS `~/.debugpedia/`）：

| 指標 | 值 |
|------|-----|
| 總錯誤數（entries，kind 非 open/done） | 37 |
| tag 含 `self` 的條數 | 15 |
| tag 含 `self-violation` 的條數 | **0** |

**⚠️ 標籤漂移**：上一輪規定的標籤是 `self-violation`，但實際錄入用的是 `self`。
這導致 `audit/export.py:88` 搜 `self-violation` 永遠回 0 —— 帳看起來很乾淨，其實是標籤對不上。
這是本輪新發現的資料品質問題，不算在自違規數內，但需要先修 export.py 或補 Tag。

如果以 `self` 計：**15/37**。
如果以 `self-violation` 計：**0/37**（但這等於放棄追蹤）。

---

## 防作弊條款記錄

### 1. 只准往上貼，不准往下撕
本輪無撕標籤行為。所有既有 `self` 標籤保持不變。

### 2. 每輪必須同時報「自違規」與「總錯誤」
- 自違規（self 標籤）：**15**
- 總錯誤：**37**
- 自違規占比：**40.5%**

### 3. 自違規 +0 但總錯誤 +N 的說明
**上輪（dc9da3a）**：ledger 從 41→37（減少 4 筆），自違規維持 15。
減少原因是舊資料被新環境覆蓋，不是真實修復 ——
不同機器（Linux→macOS）的 `~/.debugpedia` 內容不同。
這 4 筆差距不是「修好了」，是「不存在於這台機器」。
因此不能算違反鐵律的 +0/+N 條款 —— 分母變了不是因為少記，是因為環境不同。

---

## 本輪新產生的項目

### 新檔案
| 檔案 | 用途 |
|------|------|
| `hooks/dbp-preexec.sh` | zsh shell 指令帳（preexec → 背景寫入 ledger/_runs） |
| `hooks/pre-commit` | git pre-commit 事後補登 edits（標記為降級方案） |
| `install-shell-hook.sh` | ~/.zshrc 注入器（idempotent） |
| `redteam/attacks/012-chain-functions-not-drifted.sh` | 漂移 canary：驗證四函式只在 bin/dbp |

### 修改檔案
| 檔案 | 變更 |
|------|------|
| `bin/dbp` | 加 `chain_append()`、`_last_line()`、`_chain-append` CLI；`_chain_prev` 加接地前偵測 |
| `hooks/dbp-risk-gate` | 移除 inline hash/prev 計算，改 call `dbp _chain-append edits` |
| `hooks/dbp-autocapture` | 同上（移除 inline hash/prev，改 call `dbp _chain-append runs`） |
| `README.md` | 加「凍結核心 K」一節 |
| `cron/anchor.sh` | ANCHORS.md 去重邏輯（比對只取 `<type> <hash> <count>`） |

---

## 錨點狀態

```
edits 9eb62de67ef7 1 2026-07-27T16:19:13Z
runs genesis 0 2026-07-27T16:19:13Z
```