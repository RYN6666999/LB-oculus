# 紅隊攻擊索引

**自動產生 —— 不要手改。** 來源是 `attacks/*.sh` 的檔頭宣告。

> 產生於 2026-07-27T15:22:51+00:00
> 重建：`python3 redteam/index.py` · 檢查過期：`python3 redteam/index.py --check`

---

共 **12** 支 · 預期 BREACH（洞還在）**8** 支 · 監視 harness 自己的 canary **2** 支

> BREACH 是綠色的。洞還在 = 符合預期。洞消失才要停下來查。

---

## `001-install-green-while-broken.sh`

| | |
|---|---|
| **EXPECT** | `SEALED` |
| **標的** | `install.sh:16（已於 plan/001 處置）` |
| **相關文件** | `audit/2026-07-27-verification.md` · `audit/LEDGER-SNAPSHOT.md` · `plan/001-restore-executability.md` · `plan/002-llm-generalizer-cron.md` · `plan/README.md` |

**宣稱**：install.sh 曾用 test -e 定義成功，所以 shebang 壞掉時照樣印 ✓ 並 exit 0

**為什麼值得一支攻擊**：這是整個 repo 最嚴重的洞 —— 安裝成功即失敗。只有真的安裝才看得到。

單獨跑：`./redteam/run.sh 001`

---

## `002-ledger-forgeable.sh`

| | |
|---|---|
| **EXPECT** | `BREACH` |
| **標的** | `~/.debugpedia/*.jsonl（append-only 只是口頭約定）` |
| **相關文件** | `audit/2026-07-27-verification.md` · `audit/LEDGER-SNAPSHOT.md` · `plan/001-restore-executability.md` |

**宣稱**：任何人可以直接改寫 ledger，dbp 事後完全看不出來

**為什麼值得一支攻擊**：篡改不可觀測，比「可篡改」更嚴重 —— 帳本失去證據力。

單獨跑：`./redteam/run.sh 002`

---

## `003-verify-cmd-forgeable.sh`

| | |
|---|---|
| **EXPECT** | `BREACH` |
| **標的** | `bin/dbp:202 VERIFY_CMD` |
| **相關文件** | `audit/2026-07-27-verification.md` · `audit/LEDGER-SNAPSHOT.md` |

**宣稱**：鐵律二的機械化靠字串比對，跑一條「空殼的」pytest 也算驗過

**為什麼值得一支攻擊**：只認指令長相、不認退出碼，等於獎勵造假 —— 造假比做對便宜。

單獨跑：`./redteam/run.sh 003`

---

## `004-gate-common-failure-point.sh`

| | |
|---|---|
| **EXPECT** | `BREACH` |
| **標的** | `hooks/dbp-risk-gate:41-42` |
| **相關文件** | `audit/2026-07-27-verification.md` · `audit/LEDGER-SNAPSHOT.md` · `plan/001-restore-executability.md` |

**宣稱**：ledger 寫入被擋在 os.path.exists(DBP) 之後，dbp 不在時 gate 靜默放行且不留痕

**為什麼值得一支攻擊**：共同失效點讓複式簿記歸零 —— 帳本 B 依賴帳本 A 的工具存在。

單獨跑：`./redteam/run.sh 004`

---

## `005-unverified-is-dead-code.sh`

| | |
|---|---|
| **EXPECT** | `BREACH` |
| **標的** | `bin/dbp:223 unverified() / main()` |
| **相關文件** | `audit/2026-07-27-verification.md` · `audit/LEDGER-SNAPSHOT.md` · `plan/001-restore-executability.md` |

**宣稱**：兩本帳從未對帳 —— unverified() 沒有任何 CLI 路由，是死碼

**為什麼值得一支攻擊**：帳本 B 對防漂移的貢獻是「零」，不是「弱」。複式簿記名存實亡。

單獨跑：`./redteam/run.sh 005`

---

## `006-sweep-blind-to-self.sh`

| | |
|---|---|
| **EXPECT** | `BREACH` |
| **標的** | `bin/dbp:361 SWEEP_EXT` |
| **相關文件** | `audit/2026-07-27-verification.md` · `audit/LEDGER-SNAPSHOT.md` |

**宣稱**：sweep 只看白名單副檔名，看不見「無副檔名的可執行檔」—— 包含它自己

**為什麼值得一支攻擊**：屠龍者對自己完全瞎。repo 的核心資產 bin/dbp、hooks/* 全都無副檔名。

單獨跑：`./redteam/run.sh 006`

---

## `007-ls-crashes-on-harness-ledger.sh`

| | |
|---|---|
| **EXPECT** | `BREACH` |
| **標的** | `bin/dbp:69 _all() glob("*.jsonl") → bin/dbp:183 ls()` |
| **相關文件** | `audit/2026-07-27-verification.md` · `audit/LEDGER-SNAPSHOT.md` · `plan/001-restore-executability.md` |

**宣稱**：_all() 把 harness 帳本（_edits/_runs）也當成 bug 紀錄讀進來，

**為什麼值得一支攻擊**：這是「兩本帳混成一本」的直接後果。

單獨跑：`./redteam/run.sh 007`

---

## `008-unknown-subcmd-becomes-bug.sh`

| | |
|---|---|
| **EXPECT** | `BREACH` |
| **標的** | `bin/dbp:573 main() fallthrough` |
| **相關文件** | `audit/2026-07-27-verification.md` · `audit/LEDGER-SNAPSHOT.md` · `plan/001-restore-executability.md` |

**宣稱**：打錯的子指令會被當成 bug 描述寫進帳本，且回報成功

**為什麼值得一支攻擊**：這是紅隊 005 誤判時意外挖出來的新洞。

單獨跑：`./redteam/run.sh 008`

---

## `009-cron-silent-noop.sh`

| | |
|---|---|
| **EXPECT** | `SEALED` |
| **標的** | `cron/generalize.sh · cron/generalize.py（案 002 第一階段）` |
| **相關文件** | `audit/LEDGER-SNAPSHOT.md` · `plan/002-llm-generalizer-cron.md` · `plan/README.md` |

**宣稱**：接外部 LLM 的排程最可能的失效不是「歸納得不好」，是「失敗了但沒人知道」

**為什麼值得一支攻擊**：「從沒跑過」和「每天跑但每次都失敗」在使用者眼裡長得一模一樣 —— 什麼都沒發生。

單獨跑：`./redteam/run.sh 009`

---

## `010-ledger-dir-swappable.sh`

| | |
|---|---|
| **EXPECT** | `BREACH` |
| **標的** | `~/.debugpedia/ledger/（目錄層 — 002 只驗了檔案層）` |
| **相關文件** | `audit/2026-07-27-verification.md` · `audit/LEDGER-SNAPSHOT.md` · `plan/001-restore-executability.md` · `plan/002-llm-generalizer-cron.md` · `plan/README.md` |

**宣稱**：sappnd 鎖檔案不夠：mv ledger /tmp/ 再建空目錄，整本帳無聲消失

**為什麼值得一支攻擊**：檔案鎖得再好，目錄沒鎖等於沒鎖。這就是 002 自己寫的手段。

單獨跑：`./redteam/run.sh 010`

---

## `900-canary-must-be-sealed.sh`

| | |
|---|---|
| **EXPECT** | `SEALED` |
| **標的** | `（無 —— 這支不攻擊 repo，攻擊的是 redteam 自己）` |
| **相關文件** | `redteam/README.md`（harness 自檢） |

**宣稱**：對一個「確定不存在的洞」發動攻擊，harness 必須回報 SEALED

**為什麼值得一支攻擊**：假紅會訓練人忽略所有紅燈。如果這支報 BREACH，代表 harness 會憑空

單獨跑：`./redteam/run.sh 900`

---

## `901-canary-must-be-broken.sh`

| | |
|---|---|
| **EXPECT** | `BROKEN` |
| **標的** | `（無 —— 這支攻擊 redteam 自己）` |
| **相關文件** | `redteam/README.md`（harness 自檢） |

**宣稱**：前置條件不成立時，harness 必須回報 BROKEN，不可以誤報成 SEALED

**為什麼值得一支攻擊**：這是整份 redteam 最重要的一支。

單獨跑：`./redteam/run.sh 901`

---

## 這份索引證明什麼、不證明什麼

**證明**：每支攻擊都宣告了預期，且宣告與索引不會漂移（索引是推導出來的）。

**不證明**：攻擊寫得對。攻擊會不會說謊由 `900`/`901` 兩支 canary 守，
而 canary 會不會失效，目前只能靠人手動閹割 `lib.sh` 來驗（見 `redteam/README.md`）。

