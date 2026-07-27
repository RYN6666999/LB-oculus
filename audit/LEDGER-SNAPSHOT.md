# LEDGER 快照

> **自動產生 —— 不要手改。** `python3 audit/export.py` 重新推導。

> 產生於 2026-07-27T16:22:00+00:00 · 來源 `/Users/ryan/.debugpedia`

> 這份證明「條目在 ledger 裡」，**不證明條目是真的**。
> 真假由 `audit/2026-07-27-verification.md` 的可重跑指令負責。


## 錯誤 37 條（鐵律三 A 類）

| # | 優先 | 什麼 | 位置 | 標籤 |
|---|---|---|---|---|
| 1 | P2 | 測試：dbp 首次啟用 | `—` | meta |
| 2 | P2 | 路線B：非 git 目錄測試 | `—` | meta |
| 3 | P2 | topology 標 expect: fail 但 probe 實測是綠的 — 手標的過期標記 | `topology.yaml` | doc-lie,stale-marker |
| 4 | P2 | probe 註解抄 chatflow 的 bootstrap 冷卻常數，抄的值大 15 倍且怪錯變數（真凶是 TTL 快取非 MIN_GAP） | `scripts/probe.py:355` | doc-lie,copied-constant |
| 5 | P2 | pre-commit 是懸空 symlink，git hook run 回 cannot find a hook 且 exit 0 靜默放行 — 看起來有閘實際沒有 | `.git/hooks/pre-commit` | gate,silent-failure,git |
| 6 | P2 | topology 的 at 指向 ~/Developer/agent-sandbox，該目錄不存在（本尊在 ~/agent-sandbox） | `topology.yaml:76` | doc-lie,path |
| 7 | P2 | topology 稱 path-DENY 紅線在 agentOS 定義 — 反了，實際在 neuralis 自己的 laap/safety_gate.py:165 | `topology.yaml` | doc-lie,ownership |
| 8 | P2 | causal 稱 agentOS 是 38 工具 registry，agentos.json 實際 tools10/routes30/bridge7/pipeline6，湊不出 38 | `brain/causal.yaml:34` | doc-lie,unverifiable-number |
| 9 | P2 | at 欄寫縮寫路徑 ~/Library/... — 人看得懂但機器驗不了，不可驗證的宣稱等於沒宣稱 | `topology.yaml:25` | doc-lie,path,abbreviation |
| 10 | P2 | ~/Desktop/agent-sandbox 是 6/28 舊 checkout 且有未提交改動，AI 讀錯那份會拿到過期情報 | `/Users/ryan/Desktop/agent-sandbox` | stale-checkout,duplicate |
| 11 | P2 | 宣稱驗過就推 commit，但驗法是跑 probe，而 probe 只驗 edges 對稱差集、node 欄位一字不看 — 同角度驗等於沒驗 | `scripts/probe.py` | iron-law-2,self,verification |
| 12 | P2 | lint 的 truth dict 存錯層（v[0] 是 tuple 不是值），TypeError: unsupported format string passed to tuple | `brain/lint.py` | self,python |
| 13 | P2 | lint 檢查 E 範疇錯：要求 CI 也要有本機 pre-commit，但 core.hooksPath 是本機 config 不進版控 | `brain/lint.py` | self,ci,category-error |
| 14 | P2 | 編輯 topology 時未加引號的 yaml 純量裡出現 'at: '，被當成 mapping key，整份解析失敗 | `topology.yaml:48` | self,yaml,quoting |
| 15 | P2 | 獨立驗證腳本自己錯了：~ 在雙引號裡不展開，4 個真實存在的路徑被誤報成開不起來 | `—` | self,shell,quoting,verifier-bug |
| 16 | P2 | lint 檢查 F 第一版用『長得像不像路徑』猜，把 6 個正確的 repo 相對路徑與含空格 macOS 路徑判成描述 — 兩條路互相打臉才抓到 | `brain/lint.py` | self,iron-law-2,false-positive |
| 17 | P2 | 看到檢查器報錯而檔案實際存在，第一反應是『我的檢查器假陽性』— 差點丟掉真陽性。真相是第三種：路徑含縮寫無法驗證 | `—` | self,iron-law-2,misdiagnosis |
| 18 | P2 | 此環境 rg 被 shim 成 grep，--include / -g 都不支援，會噴 usage 而非搜尋結果 | `—` | env-trap,tooling |
| 19 | P2 | 全域 skill 裡寫死 lint 的檢查代號（D/F）— 檢查編號今天就從 5 道變 7 道，代號是最會漂的東西 | `/Users/ryan/.claude/skills/debugpedia/SKILL.md` | iron-law-1,copied-reference,self |
| 20 | P2 | [fix of 19fa37b] 改成不寫檢查代號，只指向 brain/lint.py 檔頭；代號會漂，寫死就是抄本 | `—` | fix |
| 21 | P2 | 留言板貼文用 ## 標題開頭，但 Aris 用 \n(?=\[\d{4}-\d{2}-\d{2}) 切塊，必須 [YYYY-MM-DD 開頭 — 貼了等於沒貼，且只吃前 180 字 | `laap/chatflow.py:236` | self,format-mismatch,invisible-write |
| 22 | P2 | skill 由 debugpedia 更名為 coding-yinyang-eye，先前 dbp 紀錄裡指向舊路徑的 where 欄已失效 | `/Users/ryan/.claude/skills/coding-yinyang-eye` | rename,stale-reference |
| 23 | P2 | LAAP API 回傳的 usage.total_tokens 寫死 0（chatflow.py:420 與 :824），Scream 用它算 context %，所以永遠停在 0% 不跳動 | `laap/chatflow.py:420` | bug,token-accounting,hardcoded-zero |
| 24 | P2 | gbrain/now 停在 07-24：宣稱 main=622f258（實際 f01f3d3）、pytest 188（實際 266）— 腦庫現況頁腐朽三天 | `gbrain/now` | doc-lie,stale-state |
| 25 | P2 | config.toml 有 32 處 cline 殘留（providers.cline + 8 個 cline/* model 定義），訂閱已要退掉 | `/Users/ryan/.scream-code/config.toml` | dead-config,cleanup |
| 26 | P2 | Scream 0.10.0 無原生自訂斜線指令：plugin manifest 把 commands 列在 UNSUPPORTED_RUNTIME_FIELDS，指令是 bundle 內寫死清單。這是 /aris-mode 只能 monkey-patch 的原因 | `/opt/homebrew/lib/node_modules/scream-code/dist/app-Bda9iKUb.mjs` | scream,no-extension-point,architecture |
| 27 | P2 | 兩個 skills 目錄易混：Scream 實際讀 ~/.agents/skills（101 個），~/.scream-code/skills 只有 8 個 | `—` | scream,ambiguous-path |
| 28 | P2 | 改了 chatflow.py 的 usage 但活 API 仍回 total_tokens=0 — 服務跑舊碼未重啟。改檔 != 生效 | `laap/chatflow.py` | iron-law-2,not-deployed |
| 29 | P2 | settings.json 的 hook 設定在 session 啟動時載入，對話中途新增的 hook 不會生效，無法當場驗證接線 | `/Users/ryan/.claude/settings.json` | hook,claude-code,not-live-until-restart |
| 30 | P2 | sweep 的 PATHISH 正則太鬆，把 try/except、Python/Rust、application/json、github.com/... 全判成路徑 — 812 條裡九成五是假陽性。今天第二次犯『用形狀猜路徑』 | `/Users/ryan/.local/bin/dbp` | self,false-positive,regex,repeat-offense |
| 31 | P2 | sweep 的死 commit 檢查分不出『宣稱它是真的』與『引用它當反面教材』— 8 處全是後者，差點產出假恐怖故事。抓鬼工具會生誇大的鬼 | `/Users/ryan/.local/bin/dbp` | self,false-positive,overclaim |
| 32 | P2 | [fix of 19fa38] 推翻：hook 當場就生效了。編輯 CLAUDE.md 時 dbp-risk-gate 確實跳出前科警告。稍早探針沒觸發另有原因，不是 settings.json 不重載 | `—` | fix |
| 33 | P2 | 我宣稱『settings.json 中途改不生效』是錯的 — 同 session 內 PreToolUse hook 實測有觸發。從單一失敗案例推論出通則 | `—` | self,overgeneralize,iron-law-2 |
| 34 | P2 | wc 多檔輸出被 shim 成 Σ 摘要，害我誤判 _runs.jsonl 不存在、差點宣稱 PostToolUse 沒觸發 | `—` | env-trap,tooling,overclaim |
| 35 | P2 | unverified() 對『驗過了』和『沒有編輯紀錄』都回空集合，兩者語意混同 — 測試因此把未知印成通過 | `/Users/ryan/Developer/LB-oculus/bin/dbp` | self,semantics,false-negative |
| 36 | P2 | dbp 存相對 where 但 shell cwd 常被重設成別的 repo，紀錄事後解不到路徑 — 應存絕對路徑或 repo 相對 | `/Users/ryan/Developer/LB-oculus/bin/dbp` | self,path,record-rot |
| 37 | P2 | 我把兩筆真陽性判成『我腳本的假陽性』— 法二換條路才糾正。憑直覺否定檢查結果又一次 | `—` | self,iron-law-2,misdiagnosis |

## 未收尾 18 條（鐵律三 B 類）

| # | 優先 | 要做什麼 | 位置 | 被什麼擋住 |
|---|---|---|---|---|
| 1 | P2 | Scream 的 AGENTS.md 還沒寫進三鐵律（Aris 端已進 gbrain 本體論） | `/Users/ryan/.scream-code/AGENTS.md` | 沒擋住，就是還沒做 |
| 2 | P2 | gbrain/now 停在 07-24，main hash 與 pytest 數都過期 | `gbrain/now` | 沒擋住，就是還沒做 |
| 3 | P2 | config.toml 32 處 cline 殘留待清 | `/Users/ryan/.scream-code/config.toml` | 等 Ryan 點頭（活的執行設定） |
| 4 | P2 | chatflow.py 的 token % 已修但服務未重啟，11546 仍跑舊碼 | `laap/chatflow.py` | 等 Ryan 決定誰重啟 |
| 5 | P2 | coding陰陽眼 註冊成 Scream 斜線指令 — 無原生機制，需選 skill 或 bundle patch | `—` | 等 Ryan 選路線 |
| 6 | P2 | dbp converge：關掉幾類 vs 新開幾類，唯一能判斷整套有沒有用的指標 | `—` | 沒擋住，就是還沒做 |
| 7 | P2 | sweep 死引用 227 條 / 抑制 176 條，假陽性率仍高，需再收斂 | `/Users/ryan/.local/bin/dbp` | 沒擋住，就是還沒做 |
| 8 | P2 | ~/Desktop/agent-sandbox 是 6/28 舊 checkout 且有未提交改動，該清掉 | `—` | 沒擋住，就是還沒做 |
| 9 | P2 | relay_remembers_turn 真紅：aris-relay.py:124 不回放歷史 + chatflow.py:50 只取最後一則 | `—` | 要先決定對話連續性歸哪層管 |
| 10 | P2 | 兩個 hook（dbp-autocapture 自動記錄、dbp-risk-gate 動手前示警）接線未驗 — settings.json 中途不生效 | `—` | 下個 session 開場：改一個有前科的檔看有沒有跳警告；跑一個會失敗的指令看有沒有自動記錄 |
| 11 | P2 | 鐵律二機械化只完成一半：_edits/_runs log 已在寫，但 unverified() 要分清 verified/unknown，且還沒接進 pre-commit | `/Users/ryan/Developer/LB-oculus/bin/dbp` | 沒擋住，就是還沒做 |
| 12 | P2 | 法二紅隊八條作弊法，現只蓋 2 條：驗證需碰到該檔/驗證器指紋/逐檔配對/偵測收窄參數(-k)/豁免diff警示/最後編輯後必驗 | `/Users/ryan/Developer/LB-oculus/bin/dbp` | 沒擋住，就是還沒做 |
| 13 | P2 | 法三補強：超齡未收尾自動升級成 bug、where 欄必填、失敗數 vs 紀錄數對帳 | `—` | 沒擋住，就是還沒做 |
| 14 | P2 | 法零指標：豁免規則成長 vs dbp fix 成長，比值上升=在調鬆閘門而非修對問題 | `—` | 沒擋住，就是還沒做 |
| 15 | P2 | dbp audit：四本帳交叉對帳。優先做①法二→法一覆蓋缺口 ②法三→法二漏驗 ④法零鬆動，因基準帳本(_edits/_runs/git)不是我能改的 | `—` | 沒擋住，就是還沒做 |
| 16 | P2 | dbp rules 升級成候選閘產生器：到閾值直接吐閘骨架，人只審核（離 AGI 最近也最遠的一格） | `—` | 沒擋住，就是還沒做 |
| 17 | P2 | Scream 驗 Aris 的成長路徑與錯誤 — Ryan 早先想做、agentOS 有元件負責、當時沒成功。這是真正獨立的第二本帳 | `—` | 要先查 agentOS 哪個元件負責 |
| 18 | P2 | dbp converge：關掉幾類 vs 新開幾類，唯一能判斷整套有沒有用的指標 | `—` | 沒擋住，就是還沒做 |

## 法則候選 · 出現 ≥2 次的類別

> 單筆是事件，重複才是法則。≥2 次 = 該從結構上關掉整類。

- **self** ×15
- **doc-lie** ×7
- **iron-law-2** ×6
- **path** ×3
- **false-positive** ×3
- **meta** ×2
- **quoting** ×2
- **misdiagnosis** ×2
- **env-trap** ×2
- **tooling** ×2
- **fix** ×2
- **scream** ×2
- **overclaim** ×2

## 自我違反 15 / 37 條

這個 repo 違反自己寫下的鐵律的次數。**這個數字是本專案最重要的指標。**
它下降代表工事在收斂；它上升代表在寫更多宣稱而不是更多證據。

