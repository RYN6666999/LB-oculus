# 2026-07-27 紅隊複驗 · LB-oculus

**每一條都附可自己重跑的指令。別信這份文件，換一條路驗。**

方法：清除前一輪污染 → 照 `README:68-71` 原文 clone + `./install.sh`
→ **從安裝後的路徑**（`~/.local/bin/dbp`、`~/.claude/hooks/*`）驗。

環境：Linux / Python 3.13.13 / `/bin/sh → dash` / repo `da9d78a`

---

## 最重要的一條：安裝成功即失敗

只有真的裝才會看到，讀碼推不出來。

```bash
git clone <repo> ~/Developer/LB-oculus && cd ~/Developer/LB-oculus && ./install.sh
# → 六個 ✓，exit 0

dbp stats                          # → cannot execute: required file not found  exit=127
~/.claude/hooks/dbp-risk-gate      # → exit=127
ls ~/.debugpedia                   # → No such file or directory
```

根因：`install.sh` 的 `link()` 用 `test -e` 判定成功。

| 判定 | 結果 |
|---|---|
| `test -e ~/.local/bin/dbp` ← install.sh 用的 | **PASS** |
| `test -x ~/.local/bin/dbp` | **PASS** |
| 實際執行 | **FAIL (127)** |

symlink 沒斷、權限沒錯。斷的是 shebang 指向的 interpreter
（`/opt/homebrew/bin/python3` 在非 macOS 不存在），而 `-e`/`-x` 測不到那一層。

**在任何 Linux / Docker / CI / 非 homebrew macOS 上，這個 repo 的完整行為是：
印六個綠勾，然後什麼都不做。**

> `hooks/dbp-autocapture:11` 自己寫著「pre-commit 懸空 symlink 能死那麼久，
> 就是因為它依賴有人記得叫它」。
> install.sh 死於同一機制的變種，**而且它在安裝當下就死了，還印了六個 ✓。**

這條同時違反 repo 自己的鐵律二（`README:38` 產出者不得自驗）：
`ln -sfn` 產出 symlink，`test -e` 驗 symlink —— **同一條路驗，等於沒驗。**

---

## 修好 shebang 後，用真實工作流程重驗

唯一外科修復：三個檔 shebang → `#!/usr/bin/env python3`，零邏輯改動。
然後模擬一輪真實 agent 工作（3 筆手記 + 3 次 Edit 過 gate + 6 條指令過 autocapture）。

### P0-1 · `dbp ls` 爆掉

```bash
dbp ls
# 印完 4 筆真紀錄 → Traceback ... KeyError: 'id'   exit=1
```

`_all()` 的 `glob("*.jsonl")` 把 `_edits.jsonl` / `_runs.jsonl` 讀成 debug 紀錄。
`sorted()` 讓 `_` 開頭排在 `2026-W31` 之後，所以 `[-20:]` 尾端全是 ledger。

**範圍修正**：爆的只有 `ls` 和 `find`（f-string 直取 `r['id']`）。
`risk` / `rules` / `open` **不受影響** —— ledger 行沒有 `where`/`what`/`tags`，
永遠進不了那些分支。誇大範圍會讓修的人多動不必要的碼。

**機制修正**：不是 ASCII 排序，是 `sorted(glob())` 的順序。
講錯機制會讓人去動 `_week_file()` 命名，改錯地方。

### P0-1b · stats 灌水 3.5 倍

```bash
dbp stats
# 總計 14 筆 · 誰抓到: 10 個 "?" / 3 個 ai / 1 個 machine
```
真 bug 4 筆（3 手記 + 1 autocapture），印 14 筆。10 筆幽靈掛在 `?` 名下。

### P0-3 · 已補解法永遠 0%

```bash
dbp fix <id> "改用 $HOME"       # → dbp xxx · [fix of <id>] 改用 $HOME
dbp stats                       # → 總計 15 筆 · 已補解法 0 筆 (0%)   ← 總數+1，指標不動
grep -c '"fix":' ~/.debugpedia/2026-W31.jsonl   # → 0
```
`ls` 的 ✔、`find` 的 `→`、`stats` 的 % 全部讀 `r.get("fix")`，但沒有記錄有這個欄位。
且那筆 fix 本身被算成一個新錯誤。**死指標比沒指標更糟。**

### P0-2 · Bash 繞過 gate

```bash
for c in "cat > f.yaml <<EOF" "sed -i 's/a/b/' f.yaml" "python3 - <<EOF" "tee f.yaml"; do
  echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$c\"}}" | ~/.claude/hooks/dbp-risk-gate
done
wc -l ~/.debugpedia/_edits.jsonl    # → 完全沒增加
```
`WATCH` 只認 `Edit|Write|NotebookEdit|MultiEdit`。
README 第一性原理寫的就是「agent 沿證據最容易製造的方向走」——
在 Edit 這條路上加摩擦，梯度自然把它推去 Bash。**這是它自己的定理。**

### P1-4 · `unverified()` 是死碼，且判定可造假

```bash
grep -n 'unverified' bin/dbp        # → 只有 def 與 docstring，main() 零路由
dbp unverified bin/dbp              # → 不報錯，把整串當成新 bug 記進帳本
grep -rn 'pre-commit' bin/ hooks/ README.md | wc -l   # → 3 處宣稱
find . -name '*pre-commit*' | wc -l                    # → 0 個實作
```
宣稱被抄了三份，實作零份 —— 犯自己的鐵律一。

`VERIFY_CMD` 只比對字串不看 exit code，也不分檔案：

| 指令 | 判定 |
|---|---|
| `echo pytest` | ✅ 算驗過 |
| `# pytest` | ✅ 算驗過 |
| `printf curl` | ✅ 算驗過 |
| `echo 'go test'` | ✅ 算驗過 |

八個字元就能讓所有改過的檔變綠。A repo 跑 pytest 會「驗證」B repo 的編輯。

### P1-6 · 機密明文落盤

```bash
grep -o 'sk-live-[A-Za-z0-9]*' ~/.debugpedia/_runs.jsonl   # → sk-live-9xQ2vAbCdEf
stat -c '%A' ~/.debugpedia/_runs.jsonl                      # → -rw-r--r--
```
`cmd[:500]` 零遮罩。`_week_file()` 只輪替 bug 帳本，ledger 是單檔無限成長 ——
`risk-gate` 每次改檔全讀一遍，用越久越慢，撞到 8s timeout 就是靜默死法。

### P2 三則

```bash
grep -n '四條鐵律\|三條鐵律' README.md      # L6/L23/L27 三條，L173 四條
dbp done ffffffffff "不存在的 id"           # → 印成功 exit=0，什麼都沒關
dbp sweep ~/Developer/LB-oculus | head -3   # → 掃了 3 個檔（repo 實際 7 個）
```

---

## 「間諜之心」測試：帳本說謊，誰會發現

不問「帳本記了什麼」，問「帳本被動過時誰會發現」。三種攻擊在真實安裝路徑執行：

```bash
# 攻擊 1 · 偽造未來時間戳的假 pytest 證據
python3 -c "import json,time;open('$HOME/.debugpedia/_runs.jsonl','a').write(
  json.dumps({'ts':time.time()+86400,'cmd':'pytest -q','code':0})+'\n')"
# → 6 行 → 7 行，零阻力

# 攻擊 2 · 滅證
grep -v '"code": 1' ~/.debugpedia/_runs.jsonl > /tmp/t && mv /tmp/t ~/.debugpedia/_runs.jsonl
# → 失敗紀錄 1 → 0

# 攻擊 3 · 整本帳消失
mv ~/.debugpedia/_edits.jsonl /tmp/ && dbp stats
# → 照印「總計 11 筆」，一句抗議都沒有
```

前兩個是「可篡改」，第三個是**篡改不可觀測**。

**結構結論（比「榮譽制加了個殼」更精確）：**

> 不是帳本不夠獨立。是**兩本帳從未被拿來對過**。
> `unverified()` 是死碼，`main()` 零路由 —— 沒有一行程式碼問過兩本帳
> 「你們說的是同一件事嗎」。
>
> 複式簿記能運作不是因為帳本難改，是因為**改了對不上**。
> 這裡沒有對帳動作，所以帳本 B 對防漂移的貢獻是 **0** ——
> 不是弱，是零。它唯一的作用是讓 README 的表格多兩個綠勾。

### 而共同失效點讓它變成負數

```bash
mv ~/.local/bin/dbp /tmp/ ; echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/x"}}' \
  | ~/.claude/hooks/dbp-risk-gate ; wc -l ~/.debugpedia/_edits.jsonl
# → 4 行 → 4 行（沒記）
mv /tmp/dbp ~/.local/bin/ ; （同一個編輯）→ 5 行
```

`hooks/dbp-risk-gate:41` 的 `if not path or not os.path.exists(DBP): return 0`
在記帳**之前**。帳本 B 依賴帳本 A 的工具存在。

**這違反複式簿記唯一的成立條件：兩本帳不能有共同失效點。**
而那個共同失效點就是 shebang —— **shebang 一壞，兩本帳同時歸零，六個綠勾照亮。
這三件事是同一個故障。**

---

## 這個 repo 對自己完全瞎

```bash
dbp risk bin/dbp                    # → 陰陽眼：dbp 無前科   exit=0
echo '{"tool_name":"Edit","tool_input":{"file_path":".../bin/dbp"}}' \
  | ~/.claude/hooks/dbp-risk-gate   # → 空的
```

原因鏈：
1. `base="dbp"`, `stem="dbp"`, `ext=""`
2. `risk():272` 的 `len(stem) > 3` → `len("dbp") == 3` → **False**，不比對 stem
3. `ext` 為空 → 所有同副檔名族群分支跳過

三個核心檔（`dbp`、`dbp-risk-gate`、`dbp-autocapture`）都沒有副檔名，
而 `dbp` 剛好 3 字元，**卡在 `> 3` 邊界外一格**。

配合 `SWEEP_EXT` 只認副檔名：

> **sweep 看不見自己的程式碼。risk 也看不見。**
> 1255 行裡的 810 行核心邏輯，對這套工具的兩個主要檢查而言完全不存在。
>
> `README:160` 寫「規則必須能套在自己身上。豁免自己的規則系統就是惡龍。」
> 它沒有豁免自己 —— 它**看不到**自己。這比豁免更難發現：
> 豁免會留下一條規則，看不到不留任何痕跡。

### 抓幻覺的工具，證據欄位自己是幻覺

原文是 `~/.debugpedia/YYYY-Www.jsonl`，sweep 報：

```
:144  ~/.debugpedia/YYYY-Www.json   ← 路徑不存在
```

`CODE_EXT` 交替中 `json` 排在 `jsonl` 前，正則優先匹配 `json` 就停。
**它報出一個原文裡不存在的字串，然後說「這個路徑不存在」。**

而「不存在」的判定是對的（那是格式模板不是實體檔），**理由卻是編出來的**。
這比純誤報更毒：人去 grep `YYYY-Www.json` 找不到，
會開始懷疑工具，而不是懷疑那條規則。

sweep 掃自己 **5 報 5 假 = 100% 假陽性**，而 `README:156` 自稱
「`sweep` 第一版誤報率 95%，是重大缺陷不是小問題」。**第二版對自己是 100%。**

---

## 公平起見：有效的部分

`dbp-autocapture` 對真失敗的捕捉**是有效的，設計是對的**：

```
19fa3ce0f82  [machine] 指令失敗 exit=1: python3 -c "import yaml"
```

這是 hook 真的抓到的，不是手記。把呼叫權從 AI 手上拿走這個判斷成立。

`README` 的第一性原理那段站得住（「架構的工作不是要求誠實，是讓造假比做對更貴」）。
`install.sh` 用 symlink 不複製也是對的 —— 我改 repo 的 shebang，
掛載點立刻生效，這個好處是真的。

---

## 被駁回的指控

| 條目 | 為什麼駁回 |
|---|---|
| 「`ls/find/risk/stats` 全部爆」 | `risk`/`rules`/`open` 實測正常 |
| 「ASCII 排序 `_` 在數字後」 | 機制是 `sorted(glob())`，不是 ASCII |
| 「sweep 會把 dbp docstring 裡的 topology.yaml 報成死引用」 | 實測沒有 —— 它**連 bin/dbp 都沒打開** |
| 「`install.sh` 的 `echo "\n"` 不可攜」 | 此環境 `/bin/sh → dash` 正常展開，無法復現。跨平台風險真實但未證實 |

---

## 環境差異聲明

- 本機：Linux / Python 3.13.13 / `/bin/sh → /usr/bin/dash`
- 作者機：macOS + homebrew python3（從 shebang 推斷）
- 上一輪我曾 `cp` 一份改好的 dbp 到 `~/.local/bin/`。這輪開頭已刪除 ——
  **不刪，install.sh 的 `link()` 會走「那裡有東西」的分支，我會得到假綠燈。**
  一個複驗如果踩在自己上一輪的殘留物上，就是同角度驗。

---

## 一句話

> **它是一份精確描述了自己所有病症的病歷，而病歷本身從來沒有被執行過。**

`install.sh` 的六個綠勾是完美標本 —— 一個防幻覺工具鏈，
它的安裝程序在騙自己安裝成功了。
而它罵的每一種病（懸空引用、綠勾造假、產出者自驗、看不見自己），
都在那六個 ✓ 裡同時發作。

**這不是設計失敗，是「從未從安裝後的路徑跑過一次」。**
