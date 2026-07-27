# LEDGER 快照

> **自動產生 —— 不要手改。** `python3 audit/export.py` 重新推導。

> 產生於 2026-07-27T15:04:06+00:00 · 來源 `/home/user/.debugpedia`

> 這份證明「條目在 ledger 裡」，**不證明條目是真的**。
> 真假由 `audit/2026-07-27-verification.md` 的可重跑指令負責。


## 錯誤 41 條（鐵律三 A 類）

| # | 優先 | 什麼 | 位置 | 標籤 |
|---|---|---|---|---|
| 1 | P0 | install.sh 印 6 個綠勾且 exit 0，但 dbp/hooks 全部 exit 127 不可執行 —— 綠勾由 test -e 定義而非由執行定義 | `install.sh:16` | install,false-green,P0,self-violation |
| 2 | P0 | shebang 硬寫 /opt/homebrew/bin/python3，非 macOS 環境全套靜默死亡 | `bin/dbp:1,hooks/dbp-risk-gate:1,hooks/dbp-autocapture:1` | portability,shebang,P0 |
| 3 | P0 | _all() 的 glob(*.jsonl) 把 _edits/_runs ledger 讀成 debug 紀錄，ls/find 噴 KeyError: id | `bin/dbp:69` | glob,crash,P0 |
| 4 | P0 | stats 灌水 3.5 倍：4 筆真 bug 印成 14 筆，10 筆幽靈掛在 who=? | `bin/dbp:350` | metrics,inflation,P0 |
| 5 | P0 | fix() append [fix of id] 但無記錄有 fix 欄位，ls 的✔/find 的→/stats 的%永遠不出現，且 fix 自己被算成新錯誤 | `bin/dbp:523` | metrics,dead-indicator,P0 |
| 6 | P0 | risk-gate 只認 Edit\|Write\|NotebookEdit\|MultiEdit，Bash heredoc/sed -i/python - <<EOF 改檔完全不進帳本也不觸發前科 | `hooks/dbp-risk-gate:26` | gate,bypass,P0 |
| 7 | P0 | 帳本 B 依賴帳本 A：risk-gate 的 exists(DBP) 檢查在記帳之前，dbp 一斷兩本帳同時歸零 —— 複式簿記出現共同失效點 | `hooks/dbp-risk-gate:41` | double-entry,common-failure,P0,self-violation |
| 8 | P0 | 帳本可篡改且篡改不可觀測：偽造假 pytest 證據、grep -v 滅證、整本移走三種攻擊全成功，dbp stats 對帳本消失零抗議 | `~/.debugpedia/` | double-entry,tamper,observability,P0,self-violation |
| 9 | P0 | repo 零測試 —— 這是上述 17 條的共同成因，不是第 18 條 | `.` | no-test,root-cause,P0 |
| 10 | P0 | dbp ls 崩潰 KeyError 之後 exit code 仍為 0 —— 自動化與 CI 完全偵測不到崩潰 | `bin/dbp:183` | P0,exit-code,silent-failure |
| 11 | P0 | plan/001 提議的 verify() 用 "$1" --help 驗證，但 hooks 讀 stdin：dbp-risk-gate --help 在無 stdin 時永久掛住（實測 >120s），install.sh 會直接凍結。這是預期 bug #1 命中且比預期嚴重 | `plan/001-restore-executability.md` | P0,plan-001,hang,verify-design |
| 12 | P1 | unverified() 是死碼，main() 零路由；但 dbp/risk-gate/autocapture 三處宣稱 pre-commit 會用它，repo 內零實作 | `bin/dbp:223` | dead-code,phantom-claim,P1 |
| 13 | P1 | VERIFY_CMD 只比對指令字串不看 exit code：echo pytest / # pytest / printf curl 全被判定已驗過 | `bin/dbp:202` | verification,forgeable,P1 |
| 14 | P1 | _runs.jsonl 明文存 cmd[:500]，Stripe live key 與 psql 連線字串落盤，權限 644，無遮罩無輪替無上限 | `hooks/dbp-autocapture:94` | secrets,security,P1 |
| 15 | P1 | README 教的 matcher 漏 MultiEdit，與程式碼 WATCH 集合不一致 —— 同一事實抄兩處已漂移 | `README.md:83,hooks/dbp-risk-gate:26` | drift,doc-code-mismatch,P1,self-violation |
| 16 | P1 | risk() 的 len(stem)>3 讓 dbp（剛好3字元）永遠無前科，加上無副檔名 → risk 對自己三個核心檔完全瞎 | `bin/dbp:272` | risk,self-blind,boundary,P1,self-violation |
| 17 | P1 | main() fallthrough 把未知子指令當 what 記成新 bug：dbp unverified x 會靜默污染帳本，分母永久失真 | `bin/dbp:573` | cli,silent-pollution,P1 |
| 18 | P1 | dbp sweep 用「掃描目標目錄」而非 repo 根解析相對路徑，掃子目錄時 redteam/index.py 被當成 redteam/redteam/index.py → 63 條假陽性（根目錄掃只有 30 條）。假紅訓練人忽略紅燈 | `bin/dbp:436` | P1,sweep,false-positive,self-violation |
| 19 | P2 | SWEEP_EXT 只認副檔名，bin/dbp 與兩個 hook 無副檔名 → sweep 掃 3/7 檔，810 行核心碼免疫於自己的檢查 | `bin/dbp:361` | sweep,self-blind,P2,self-violation |
| 20 | P2 | sweep 掃自己 5 報 5 假 = 100% 假陽性，而 README 自稱假紅要當 P0 修 | `bin/dbp:399` | sweep,false-positive,P2,self-violation |
| 21 | P2 | PATHISH 的 CODE_EXT 交替把 json 排在 jsonl 前，.jsonl 被截成 .json —— 抓幻覺工具的證據欄位自己是幻覺 | `bin/dbp:370` | sweep,regex,hallucination,P2,self-violation |
| 22 | P2 | done(rid) 不驗證 id 是否存在，dbp done <typo> 印成功 exit 0 但什麼都沒關 | `bin/dbp:134` | cli,false-success,P2 |
| 23 | P2 | 案 001 的驗收指令引用 tests/smoke.sh，但該檔尚未存在 —— 我在批評幻影引用的同一份文件裡製造了幻影引用 | `plan/001-restore-executability.md:126` | self-violation,phantom-claim,my-own-bug |
| 24 | P2 | [redteam] 攻擊 005 用「dbp unverified 有回應」判定功能存在 → 假 SEALED。真因是 fallthrough 把它當 bug 記進帳。有輸出 != 功能存在 | `—` | self-violation,redteam,false-green,my-own-bug |
| 25 | P2 | [redteam] 攻擊 007 誤以為 dbp ls 崩潰的觸發條件是 open 紀錄 → 實測 open 完全正常，假 SEALED。真正觸發條件是 _edits.jsonl 存在 | `—` | self-violation,redteam,wrong-hypothesis,my-own-bug |
| 26 | P2 | [redteam] 攻擊 006 對 dbp sweep 用 \|\| broken 判斷失敗 → sweep 找到死引用仍 exit 0，正常執行被誤判 BROKEN | `—` | self-violation,redteam,my-own-bug |
| 27 | P2 | [redteam] index.py 的 grep_refs 只取 split('/')[-1]，~/.debugpedia/*.jsonl 只剩 jsonl 被 NOISE 濾掉 → 零鍵 → 索引印「（無）」假陰性，讓人以為這個洞沒人寫過 | `—` | self-violation,redteam,false-negative,my-own-bug |
| 28 | P2 | [redteam] index.py 第一版用 importlib.machinery 未顯式 import → AttributeError，且 traceback 搶先於 sys.exit(3) 導致 BROKEN 訊息空白 | `—` | self-violation,redteam,my-own-bug |
| 29 | P2 | install.sh 的 rc=$? 隔著 if 複合指令取，拿到 if 的 0 而非真實 127；有報錯但診斷指向錯方向 | `install.sh:52` | shell,exitcode,plan001 |
| 30 | P2 | redteam attack 001 假 SEALED：grep 'exit 127' 掃整份輸出，抓到的是結尾無條件印出的說明文字 | `redteam/attacks/001-install-green-while-broken.sh` | redteam,false-green |
| 31 | P2 | smoke A06 假斷言：照抄 plan/001 的「risk bin/dbp 有輸出」，但無副檔名走 base 比對本來就會中，驗不到 len(stem)>3 那個洞 | `tests/smoke.sh` | test,false-green |
| 32 | P2 | plan/002 payload 驗收設計錯：grep -c 分不出「乾淨」與「什麼都沒攔到」，payload 改走 argv 就會綠著放行機密 | `plan/002-llm-generalizer-cron.md` | cron,false-green |
| 33 | P2 | generalize.py 排除 evidence 欄位，導致遮罩正則從未被執行；驗收綠是因為東西沒送而非遮乾淨 | `cron/generalize.py` | cron,遮罩,false-green |
| 34 | P2 | cron 心跳用 2>&1 合併後取最後一行當死因，記下的是 stdout 的「去識別化命中 2 處」進度訊息 | `cron/generalize.sh` | cron,heartbeat |
| 35 | P2 | plan/001 自身矛盾：核心判斷寫「不修任何 bug」，驗收第 4 步卻要求 smoke baseline=0；兩者不可能同時成立 | `plan/001-restore-executability.md` | plan,自我矛盾 |
| 36 | P2 | plan/001 驗收第 4 步的 git stash 手法無法用：tests/smoke.sh 是本案新建檔，stash 會把測試自己一起收走 | `plan/001-restore-executability.md` | plan,驗收 |
| 37 | P2 | hooks 從 stdin 讀 JSON，dbp-risk-gate --help 在無 stdin 環境永久掛住（實測 >120 秒） | `hooks/dbp-risk-gate` | hook,hang |
| 38 | P2 | 反向驗證手法不夠精準：只拆一道防線後行為不變，一度誤判攻擊面 5 是死碼；實際是縱深防禦（零輸出守衛 + parse_strict 空字串）互為備援 | `redteam/attacks/009-cron-silent-noop.sh` | redteam,反向驗證 |
| 39 | P2 | redteam/run.sh 的沙盒白名單會過期：新增 cron/ 後 attack 009 缺檔 BROKEN（此次 BROKEN 是正確行為，沒謊稱 SEALED） | `redteam/run.sh:66` | redteam,白名單 |
| 40 | P2 | 沙盒帶入執行產物（_heartbeat.json / candidates）會讓上次結果被誤認成這次結果，導致攻擊 009 假 SEALED | `redteam/run.sh` | redteam,false-green |
| 41 | P2 | sweep 對 shell 變數展開瞎：把 $REPO/install.sh、$HERE/generalize.py 當字面路徑報死引用，且 .jsonl 被截成 .json；今天新增 tests/ cron/ 後假陽性從 30 增至 59 | `bin/dbp` | sweep,假陽性 |

## 未收尾 30 條（鐵律三 B 類）

| # | 優先 | 要做什麼 | 位置 | 被什麼擋住 |
|---|---|---|---|---|
| 1 | P0 | P0-0 install.sh 綠勾改由實際執行定義（link 後跑一次 --help） | `install.sh` | 等 Ryan 批准修正規劃案 001 |
| 2 | P0 | P0 三個檔 shebang 改 /usr/bin/env python3 | `bin/dbp,hooks/` | 等批准 |
| 3 | P0 | P0 寫第一個 smoke test（17 條裡 11 條可被 30 行測試抓到） | `tests/` | 等批准 |
| 4 | P0 | P0-1 _all() 排除 _ 開頭的 ledger 檔 | `bin/dbp:69` | 等批准 |
| 5 | P0 | P0-3 fix 指標改掃 [fix of 前綴，或改 fix() 寫 fixes 欄位 | `bin/dbp:523` | 等批准 |
| 6 | P0 | 新洞A 記帳移到 exists(DBP) 檢查之前，消除兩本帳共同失效點 | `hooks/dbp-risk-gate:41` | 等批准 |
| 7 | P0 | P0-2 gate 擴及 Bash 改檔（heredoc/sed -i/tee/重導向） | `hooks/dbp-risk-gate:26` | 設計未定：如何從 cmd 字串可靠萃取被改檔案 |
| 8 | P0 | 結構 兩本帳從未被拿來對過 —— 實作對帳動作，或改用 git log + CI exit code | `.` | 設計未定：需先決定用 daemon / 另一台機器 / CI |
| 9 | P0 | 結構 README 表格 _edits/_runs 的『✅真獨立』降級為 ⚠️（在做到之前先降級宣稱） | `README.md:189` | 等批准 |
| 10 | P1 | P1-6 _runs.jsonl 落盤前遮罩機密（在 ledger 搬家之前做） | `hooks/dbp-autocapture:94` | 等批准 |
| 11 | P1 | 新洞E risk() len(stem)>3 改 >=3 或加詞界比對 | `bin/dbp:272` | 等批准 |
| 12 | P1 | 新洞B README matcher 補 MultiEdit（或改為單一來源推導） | `README.md:83` | 等批准 |
| 13 | P1 | P1-4 unverified() 接上 main() 或刪除 + 移除三處 pre-commit 幻影宣稱 | `bin/dbp:223` | 等批准 |
| 14 | P1 | 帳本 append-only 強制 + 篡改可觀測（chattr +a / hash chain / fsync） | `~/.debugpedia/` | 設計未定 |
| 15 | P1 | P1-5b hook heartbeat：stats 開頭印 hook 上次寫入時間（注意不可與被監測物共用 shebang 失效點） | `bin/dbp:334` | 等批准 |
| 16 | P1 | D main() 未知子指令改報錯而非記成 bug | `bin/dbp:573` | 等批准 |
| 17 | P2 | 新洞C CODE_EXT 把 jsonl 移到 json 之前 | `bin/dbp:370` | 等批准 |
| 18 | P2 | P2-b SWEEP_EXT 改為也掃無副檔名的可執行檔（讓 sweep 看見自己） | `bin/dbp:361` | 等批准 |
| 19 | P2 | P2-a README 四條/三條 統一 | `README.md:173` | 等批准 |
| 20 | P2 | P2-c done() 驗證 id 存在 | `bin/dbp:134` | 等批准 |
| 21 | P2 | redteam 只在 Linux/Python3.13 驗過，macOS 未驗 —— 那正是 shebang 洞的所在平台 | `—` | 沒有 macOS 環境 |
| 22 | P2 | redteam 沙盒是 cp -R 複本，不驗 symlink 安裝的真實行為（001 用假 HOME 近似） | `—` | 設計未定 |
| 23 | P2 | runner 沒有 canary 監視「漏跑攻擊」—— 跑了 8 支只回報 5 支目前偵測不到 | `—` | 設計未定 |
| 24 | P2 | redteam 未接進 install.sh 驗收段與 CI，目前要手動跑 | `—` | 等批准 |
| 25 | P2 | 心跳會腐朽：A14 只驗誠實不驗新鮮，cron 停三個月後 _heartbeat.json 仍靜靜宣稱成功 | `tests/smoke.sh` | 需要決定新鮮度門檻（幾天算過期） |
| 26 | P2 | plan/002 預期 bug #2 未驗證：crontab 環境的 PATH 問題尚未有機會發作，第一階段刻意不裝排程 | `cron/README.md` | 等使用者真的排進 crontab |
| 27 | P2 | 候選品質沒有回饋迴路：不知道哪些候選後來真的變成攻擊，所以不知道 cron 這層有沒有用 | `cron/candidates` | 需先累積兩週以上候選 |
| 28 | P2 | smoke test 只在 Linux 驗過（plan/001 預期 bug #3 自評高風險，成因與 shebang 洞相同） | `tests/smoke.sh` | 沒有 macOS 環境 |
| 29 | P2 | 10 條已知紅（A03-A12）尚未修；plan/001 刻意只做可見化不做修復 | `tests/smoke.sh` | 等 plan/003 逐項處置，每項需先有測試護著 |
| 30 | P2 | sweep 假陽性隨 repo 成長而增加，遲早沒人看 sweep 的輸出（屠龍者變惡龍） | `bin/dbp` | 需先決定變數展開的處理策略 |

## 法則候選 · 出現 ≥2 次的類別

> 單筆是事件，重複才是法則。≥2 次 = 該從結構上關掉整類。

- **self-violation** ×15
- **redteam** ×9
- **false-green** ×7
- **my-own-bug** ×6
- **sweep** ×5
- **cron** ×3
- **metrics** ×2
- **phantom-claim** ×2
- **double-entry** ×2
- **self-blind** ×2
- **false-positive** ×2
- **cli** ×2
- **hang** ×2
- **plan** ×2

## 自我違反 15 / 41 條

這個 repo 違反自己寫下的鐵律的次數。**這個數字是本專案最重要的指標。**
它下降代表工事在收斂；它上升代表在寫更多宣稱而不是更多證據。

