#!/usr/bin/env python3
"""generalize.py — 借 LLM 的推理力，把錯誤史歸納成「可攻擊的假說」。

╔══════════════════════════════════════════════════════════════════╗
║  鐵律三的下一段：單次抓到是事件，累積起來才是知識 ——              ║
║  但知識躺在 ledger 裡不會自己變成防線。                            ║
║  這支負責把「累積」翻譯成「紅隊打得動的假說」。                     ║
╚══════════════════════════════════════════════════════════════════╝

為什麼需要 LLM（`dbp rules` 不夠）：
    `dbp rules` 做的是統計 —— 「shell 標籤出現 7 次」。
    餵不動紅隊。紅隊要的是結構：
    「這 7 次的共同結構是『退出碼被複合指令吃掉』，
      所以任何 `if cmd; then` 後面取 $? 的地方都該有一支攻擊。」
    第二句是推理，統計做不到。

為什麼**不**自動產生 attack 檔（案 002 的核心判斷）：
    2026-07-27 一天之內，一個有完整 repo 上下文的 agent
    在專門偵測假綠的程式碼裡產了兩個假綠（attack 001 的假 SEALED、
    smoke A06 的永遠綠斷言）。一個只讀得到 ledger 摘要的 LLM 只會更糟。
    而假紅在紅隊裡的傷害是複利的 —— redteam/README.md 自己寫了
    「假紅會訓練人忽略全部的紅」。所以人必須在中間。

絕對約束：
    · 送出前必須去識別化。ledger 有 cwd / evidence，且 P1-6（機密遮罩）
      還沒修 —— 在那之前原封不動送出等於把使用者的機密外送。
    · LLM 不可用、回傳格式不對 → **非零退出**。不接受「盡力解析」。
      一個能容忍垃圾輸入的解析器，會把垃圾當成知識存起來。
    · 候選**不寫進 ledger 的錯誤紀錄**。候選是假說不是錯誤，
      混進去會污染 dbp stats 的分母（P0-1b 的同型錯誤）。
"""

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
DIR = Path(os.environ.get("DEBUGPEDIA_DIR", Path.home() / ".debugpedia")).expanduser()
CAND = HERE / "candidates"
LLM_CMD = os.environ.get("DBP_LLM_CMD", "").strip()
MAX_RECORDS = int(os.environ.get("DBP_LLM_MAX_RECORDS", "120"))


def fail(msg):
    print(f"generalize.py: {msg}", file=sys.stderr)
    sys.exit(1)


# ─────────────────────────────────────────────────────────────────────
# 去識別化
# ─────────────────────────────────────────────────────────────────────
# 預期 bug #1（自評「高 · 長期」）：這組正則一定漏。
# 世界上的 key 格式比我想得到的多，而漏掉一種就是不可逆的外送。
#
# 所以策略不是「列舉所有密鑰格式」（那是註定失敗的白名單思維），
# 而是**兩層**：
#   1. 已知格式精準遮罩
#   2. 對任何「長度 >= 20 的高熵連續字串」一律遮罩 —— 寧可誤遮，不可漏送
# 誤遮的代價是 LLM 少看到一點細節；漏送的代價是使用者的 key 進了別人的日誌。
SECRET_PATTERNS = [
    (re.compile(r"\b(sk|pk|rk)-[A-Za-z0-9_\-]{8,}", re.I), "«KEY»"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{8,}"), "«GHTOKEN»"),
    (re.compile(r"\bxox[baprs]-[A-Za-z0-9\-]{8,}"), "«SLACK»"),
    (re.compile(r"\bAKIA[0-9A-Z]{12,}"), "«AWSKEY»"),
    (re.compile(r"\bey[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]+"), "«JWT»"),
    (re.compile(r"(?i)\b(authorization|api[_\-]?key|token|secret|password|passwd)"
                r"\s*[:=]\s*\S+"), r"\1=«REDACTED»"),
    (re.compile(r"(?i)\bbearer\s+\S+"), "Bearer «REDACTED»"),
    (re.compile(r"://[^/\s:@]+:[^/\s@]+@"), "://«USER:PW»@"),
]

# 高熵兜底：>=20 字元、混合大小寫與數字、沒有空白 —— 典型的 key 長相。
HIGH_ENTROPY = re.compile(r"\b(?=[A-Za-z0-9_\-]{20,}\b)(?=[^\s]*[a-z])(?=[^\s]*[A-Z])"
                          r"(?=[^\s]*[0-9])[A-Za-z0-9_\-]{20,}\b")

HOME = str(Path.home())


def scrub(text):
    """去識別化。回傳 (清理後文字, 命中的規則數)。

    命中數要回傳，因為「遮了幾條」必須被印出來 ——
    抑制必須可見。一個安靜遮罩的東西，沒人知道它有沒有在工作。
    """
    if not text:
        return "", 0
    s = str(text)
    hits = 0
    for pat, rep in SECRET_PATTERNS:
        s, n = pat.subn(rep, s)
        hits += n
    s, n = HIGH_ENTROPY.subn("«HIENT»", s)
    hits += n

    # 路徑正規化。
    # 預期 bug #1 執行時的實際落差：ledger 裡有 /tmp/inst-broken/.local/bin/dbp
    # 這種絕對路徑 —— 不是密鑰，但是使用者的目錄結構，一樣不該外送。
    # 而且對歸納完全沒幫助：LLM 要的是「install.sh 的哪一行」，不是「誰的家目錄」。
    s = s.replace(HOME, "~")
    s = re.sub(r"/(?:tmp|var/folders)/[A-Za-z0-9._\-]+", "/«TMP»", s)
    s = re.sub(r"/Users/[^/\s]+", "/«USER»", s)
    s = re.sub(r"/home/[^/\s]+", "/«USER»", s)
    return s, hits


# evidence 必須在這裡。
#
# 第一版把它排除掉，理由是「evidence 最可能含機密」。實測後發現那是錯的處置：
#   驗收時我 grep payload 找 AKIA…，得到 0，判定「遮罩有效」——
#   但真正的原因是**整個欄位沒被送出**。遮罩那條正則根本沒被執行到。
#   我拿「某字串不存在」當證據，卻沒先證明檢查真的執行到了。
#   （同一天第五次犯這個錯：attack 001 假 SEALED、smoke A06 假斷言、
#     plan/002 的 payload 驗收設計、這裡。已升格成 cron/README.md 的一條規則。）
#
# 排除欄位是把問題藏起來，不是解決：
#   · evidence 是錯誤的實際證據，對歸納最有價值（少了它 LLM 只能看標題猜）
#   · 真正的防線必須是「送出前遮罩」，而遮罩只有在**真的有東西經過它**時才會被驗證
# 所以：送，但先過 scrub。讓那條防線每天都被實際使用一次。
KEEP = ("what", "where", "tags", "who", "kind", "fix", "repo", "evidence")


def load_records():
    if not DIR.is_dir():
        fail(f"ledger 目錄不存在: {DIR} —— 先用 dbp 記幾筆再來歸納")
    rows = []
    for f in sorted(DIR.glob("*.jsonl")):
        # 跳過 _ 開頭：那是機械 log（_edits / _runs），不是錯誤紀錄。
        # 混進來會讓 LLM 以為「每次編輯」都是一個錯誤（P0-1b 的同型錯誤）。
        if f.name.startswith("_"):
            continue
        for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    if not rows:
        fail(f"{DIR} 裡沒有任何錯誤紀錄，沒東西可歸納")
    return rows


def build_payload(rows):
    total_hits = 0
    slim = []
    for r in rows[-MAX_RECORDS:]:
        item = {}
        for k in KEEP:
            v = r.get(k)
            if not v:
                continue
            cleaned, h = scrub(v)
            total_hits += h
            item[k] = cleaned
        if item.get("what"):
            slim.append(item)
    return slim, total_hits


PROMPT = """你在協助一個叫「陰陽眼」的反幻覺工具鏈做紅隊測試設計。

下面是它的錯誤帳本（debug 百科）節錄。每一筆是曾經真實發生過的錯誤。

你的任務**不是**總結「常犯什麼錯」那種泛泛之論。
你要找出**跨越多筆紀錄的共同結構**，並把它翻譯成一個**可以寫成攻擊腳本的假說**。

一個好的假說長這樣：
  結構：「退出碼被 shell 複合指令吞掉」
  假說：「任何 `if cmd; then ... fi` 之後取 $? 的地方，拿到的都是 if 的 0
          而不是 cmd 的真實退出碼」
  怎麼打：「弄壞被檢查的目標，斷言錯誤訊息裡出現的是真實退出碼而非 0」
  預期：BREACH（洞還在）

一個沒用的假說長這樣（**不要產出這種**）：
  「應該加強測試覆蓋率」「要注意錯誤處理」—— 正確但打不動任何東西。

紅隊的三態語意（你建議的 EXPECT 必須是其中之一）：
  BREACH = 攻擊成功、洞還在（尚未修的洞用這個）
  SEALED = 攻擊失敗、洞已補（已修好、要防回歸的用這個）
  BROKEN = 攻擊自己跑不起來（你不該建議這個）

**只輸出 JSON，不要 markdown 圍欄、不要任何解釋文字。** 格式：
{"generalizations":[{"structure":"...","hypothesis":"...","how_to_attack":"...",
"expect":"BREACH","target":"檔名:行號 或 檔名","evidence_count":3,
"why_statistics_misses_it":"..."}]}

至少 1 條，最多 6 條。evidence_count 是這條結構涵蓋幾筆紀錄。

錯誤帳本：
"""


def call_llm(payload_text):
    if not LLM_CMD:
        fail("未設定 DBP_LLM_CMD —— 這支腳本刻意不預設任何 LLM 供應商。\n"
             "  設定方式（指令從 stdin 收 prompt，把回應印到 stdout）：\n"
             "    export DBP_LLM_CMD='llm -m gpt-4o'\n"
             "    export DBP_LLM_CMD='claude -p'\n"
             "  硬綁一家等於幫你決定你的帳單。見 cron/README.md")
    try:
        p = subprocess.run(LLM_CMD, shell=True, input=payload_text,
                           capture_output=True, text=True, timeout=180)
    except subprocess.TimeoutExpired:
        fail(f"LLM 指令超過 180 秒沒回應: {LLM_CMD}")
    except Exception as e:
        fail(f"LLM 指令無法執行: {LLM_CMD} · {e}")
    if p.returncode != 0:
        tail = (p.stderr or p.stdout or "").strip().splitlines()
        fail(f"LLM 指令非零退出（rc={p.returncode}）: {tail[-1] if tail else '無輸出'}")
    if not p.stdout.strip():
        fail("LLM 指令 exit 0 但沒有任何輸出 —— 這是最危險的一種失敗，"
             "看起來成功了但什麼都沒發生")
    return p.stdout


def parse_strict(raw):
    """嚴格校驗。**不接受「盡力解析」。**

    一個能容忍垃圾輸入的解析器，會把垃圾當成知識存起來，
    而存起來的垃圾長得跟知識一模一樣。
    唯一容忍的是 markdown 圍欄 —— 那是 LLM 的普遍習慣，不是格式錯誤。
    """
    s = raw.strip()
    m = re.search(r"```(?:json)?\s*(.*?)```", s, re.S)
    if m:
        s = m.group(1).strip()
    # 取第一個 { 到最後一個 }，擋掉「好的，這是您要的 JSON：」這類前言
    i, j = s.find("{"), s.rfind("}")
    if i < 0 or j <= i:
        fail(f"LLM 回應裡找不到 JSON 物件（前 200 字: {s[:200]!r}）")
    try:
        data = json.loads(s[i:j + 1])
    except json.JSONDecodeError as e:
        fail(f"LLM 回應不是合法 JSON: {e}（前 200 字: {s[i:i+200]!r}）")

    gs = data.get("generalizations")
    if not isinstance(gs, list) or not gs:
        fail("LLM 回應缺少非空的 generalizations 陣列")

    required = ("structure", "hypothesis", "how_to_attack", "expect", "target")
    ok = []
    for n, g in enumerate(gs, 1):
        if not isinstance(g, dict):
            fail(f"第 {n} 條歸納不是物件")
        missing = [k for k in required if not str(g.get(k, "")).strip()]
        if missing:
            fail(f"第 {n} 條歸納缺欄位: {', '.join(missing)}")
        if g["expect"] not in ("BREACH", "SEALED"):
            # BROKEN 不接受：那是「攻擊自己壞了」，不可能是設計目標。
            fail(f"第 {n} 條的 expect='{g['expect']}' 不在 BREACH/SEALED 之內")
        ok.append(g)
    return ok


def write_candidates(gs, n_records, scrub_hits):
    CAND.mkdir(parents=True, exist_ok=True)
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    out = CAND / f"{today}.md"
    L = []
    L.append(f"# 攻擊候選 · {today}")
    L.append("")
    L.append("> **機器產出的假說，不是攻擊。** 一條候選要變成 `redteam/attacks/`，")
    L.append("> 必須經過 `redteam/README.md` 的規矩：**反向驗證證明它會紅**。")
    L.append(">")
    L.append("> 為什麼不自動生成：見 `plan/002`。摘要 —— 2026-07-27 一天之內，")
    L.append("> 一個有完整 repo 上下文的 agent 在專門偵測假綠的程式碼裡產了兩個假綠。")
    L.append("> 只讀得到 ledger 摘要的 LLM 只會更糟，而假紅的傷害是複利的。")
    L.append("")
    L.append(f"- 歸納自 **{n_records}** 筆紀錄")
    L.append(f"- 送出前遮罩命中 **{scrub_hits}** 處（抑制必須可見）")
    L.append(f"- LLM 指令：`{LLM_CMD}`")
    L.append("")
    L.append("---")
    L.append("")
    for i, g in enumerate(gs, 1):
        L.append(f"## 候選 {i} · {g['structure']}")
        L.append("")
        L.append(f"| | |")
        L.append(f"|---|---|")
        L.append(f"| 建議 EXPECT | `{g['expect']}` |")
        L.append(f"| 建議 TARGET | `{g['target']}` |")
        L.append(f"| 涵蓋紀錄數 | {g.get('evidence_count', '?')} |")
        L.append("")
        L.append(f"**假說**：{g['hypothesis']}")
        L.append("")
        L.append(f"**怎麼打**：{g['how_to_attack']}")
        L.append("")
        if g.get("why_statistics_misses_it"):
            L.append(f"**為什麼 `dbp rules` 抓不到**：{g['why_statistics_misses_it']}")
            L.append("")
        L.append("**採用前必須做的事**（缺一不可）：")
        L.append("")
        L.append("1. 讀被指的那個檔，確認假說**針對真實程式碼**而非想像的程式碼")
        L.append("2. 寫成攻擊後，**故意把洞補起來**，確認它翻成另一態（不會紅的測試不是測試）")
        L.append("3. 確認它不是既有攻擊的重複 —— 重複的紅跟假紅一樣會訓練人忽略")
        L.append("")
        L.append("---")
        L.append("")
    out.write_text("\n".join(L), encoding="utf-8")
    return out


def note_open(out, n):
    """記一筆 dbp open —— 未收尾的事會過期、會叫。

    刻意用 open 而不是 add：候選是**假說**不是錯誤。
    寫成錯誤紀錄會污染 dbp stats 的分母（P0-1b 的同型錯誤）。
    """
    dbp = Path.home() / ".local/bin/dbp"
    if not dbp.exists():
        # 不是致命錯 —— 但也不准安靜。印出來讓人知道這條路斷了。
        print(f"  ⚠️  找不到 {dbp}，候選沒有登記成未收尾項目（它不會自己來提醒你）")
        return
    try:
        subprocess.run([str(dbp), "open",
                        f"cron 產出 {n} 條攻擊候選待人工審核: {out.name}",
                        "-w", str(out), "-b", "等人工審核（機器不得自行採用）",
                        "-t", "cron,redteam,candidate"],
                       timeout=10, capture_output=True, text=True)
    except Exception as e:
        print(f"  ⚠️  登記未收尾項目失敗（已忽略）: {e}")


def main():
    rows = load_records()
    slim, hits = build_payload(rows)
    if not slim:
        fail("去識別化後沒有剩下任何可用紀錄")

    payload_text = PROMPT + json.dumps(slim, ensure_ascii=False, indent=1)

    # 抑制必須可見：遮了幾處一定要印出來。
    # 一個安靜遮罩的東西，沒人知道它到底有沒有在工作 ——
    # 包括「正則全都不匹配所以一處都沒遮」這種最危險的情況。
    print(f"  歸納 {len(slim)} 筆紀錄（ledger 共 {len(rows)} 筆）")
    print(f"  去識別化命中 {hits} 處")
    if hits == 0:
        print("      注意：0 處命中。可能真的沒有機密，也可能是正則全部失效。")
        print("      驗證方式在 tests/smoke.sh 的 A15（種一筆假 key 進去看攔不攔）。")

    raw = call_llm(payload_text)
    gs = parse_strict(raw)
    out = write_candidates(gs, len(slim), hits)
    print(f"  ✓ {len(gs)} 條候選 → {out}")
    note_open(out, len(gs))
    print("  候選不會自動變成攻擊。人必須在中間 —— 見 plan/002。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
