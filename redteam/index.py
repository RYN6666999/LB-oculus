#!/usr/bin/env python3
"""從 attacks/*.sh 的檔頭推導索引 —— 不手抄（鐵律一）。

手抄的索引是一則排程好的未來謊言：攻擊改了、索引沒改，索引就開始騙人。
所以 INDEX.md 由這支產生，且標明「不要手改」。

同時做一件 README 做不到的事：把每支攻擊接回 audit/ 與 plan/。
沒有反向連結的話，「洞」「攻擊」「規劃」是三份各自漂移的資料。

用法：
  python3 redteam/index.py           產生 INDEX.md
  python3 redteam/index.py --check   只檢查是否過期（CI 用，過期回 1）
"""
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

RT = Path(__file__).parent
ROOT = RT.parent
OUT = RT / "INDEX.md"
FIELDS = ("EXPECT", "TARGET", "CLAIM", "WHY")


def parse(p: Path) -> dict:
    """只讀檔頭連續註解區。攻擊本體改了不影響索引，宣告改了才影響。"""
    rec = {"file": p.name}
    for line in p.read_text(encoding="utf-8").splitlines()[:40]:
        if not line.startswith("#"):
            if line.strip() and not line.startswith("#!"):
                break
            continue
        m = re.match(r"#\s*([A-Z]+):\s*(.+)", line)
        if m and m.group(1) in FIELDS:
            rec[m.group(1)] = m.group(2).strip()
    return rec


# 太常見的字，當搜尋鍵會命中所有文件 → 假陽性。
NOISE = {"dbp", "sh", "py", "md", "install", "hooks", "bin", "jsonl", "*"}


def ref_keys(target: str) -> set:
    """從 TARGET 推導可用的搜尋鍵。

    踩過兩個坑，都留在這裡當教材：
      1. 第一版拿整個 TARGET 當鍵 → `~/.debugpedia/*.jsonl（...）` 配不到任何東西，
         索引印「（無）」。假陰性比沒有更糟：它讓人以為「這個洞沒人寫過」。
      2. 第二版只取 split("/")[-1] → `~/.debugpedia/*.jsonl` 只剩 `jsonl`，
         而 jsonl 在 NOISE 裡，於是又變成零鍵。真正有辨識度的 `.debugpedia`
         是中段，被丟掉了。所以現在收錄「所有」路徑片段。
    """
    t = re.sub(r"[（(].*?[）)]", " ", target)          # 剝掉括號註解
    keys = set()
    for tok in re.split(r"[\s,·→]+", t):
        tok = tok.strip().strip("`'\"")
        if not tok:
            continue
        for seg in tok.split("/"):                    # 收所有片段，不只最後一段
            seg = seg.strip().lstrip("*.~").rstrip("()")
            for k in (seg, seg.split(":")[0]):
                if k and k.lower() not in NOISE and len(k) > 2:
                    keys.add(k)
    return keys


def grep_refs(target: str, where: Path) -> list:
    """在 audit/ plan/ 裡找提到這個標的的檔案 —— 反向連結靠搜尋推導，不靠人維護。"""
    if not where.is_dir():
        return []
    keys = ref_keys(target)
    if not keys:
        # 沒有可用的鍵，就不要假裝「找過了但沒有」—— 沉默的「（無）」會騙人。
        return ["⚠️ 無法從標的產生搜尋鍵"]
    hits = []
    for f in sorted(where.rglob("*.md")):
        try:
            txt = f.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        if any(k in txt for k in keys):
            hits.append(f.relative_to(ROOT).as_posix())
    return hits


def build() -> str:
    atks = sorted((RT / "attacks").glob("*.sh"))
    if not atks:
        # 空索引是假證據 —— 寧可不產出
        raise SystemExit("attacks/ 是空的，不產出索引（避免生出一份空的假證據）")

    recs = [parse(p) for p in atks]
    missing = [r["file"] for r in recs if not all(f in r for f in FIELDS)]

    L = ["# 紅隊攻擊索引", "",
         "**自動產生 —— 不要手改。** 來源是 `attacks/*.sh` 的檔頭宣告。",
         "",
         f"> 產生於 {datetime.now(timezone.utc).isoformat(timespec='seconds')}",
         f"> 重建：`python3 redteam/index.py` · 檢查過期：`python3 redteam/index.py --check`",
         "", "---", ""]

    if missing:
        L += ["## ⚠️ 檔頭不完整",
              "",
              "這些攻擊缺必填欄位，runner 會把它們計為 BROKEN：", ""]
        L += [f"- `{m}`" for m in missing]
        L += [""]

    n_breach = sum(1 for r in recs if r.get("EXPECT") == "BREACH")
    n_canary = sum(1 for r in recs if r.get("TARGET", "").startswith("（無"))
    L += [f"共 **{len(recs)}** 支 · 預期 BREACH（洞還在）**{n_breach}** 支 · "
          f"監視 harness 自己的 canary **{n_canary}** 支", "",
          "> BREACH 是綠色的。洞還在 = 符合預期。洞消失才要停下來查。", "", "---", ""]

    for r in recs:
        tgt = r.get("TARGET", "?")
        L += [f"## `{r['file']}`", "",
              f"| | |", f"|---|---|",
              f"| **EXPECT** | `{r.get('EXPECT','?')}` |",
              f"| **標的** | `{tgt}` |"]

        if tgt.startswith("（無"):
            # canary 攻擊的是 harness 自己，本來就沒有 repo 標的
            L.append("| **相關文件** | `redteam/README.md`（harness 自檢） |")
        else:
            refs = sorted(set(grep_refs(tgt, ROOT / "audit") + grep_refs(tgt, ROOT / "plan")))
            L.append(f"| **相關文件** | {' · '.join(f'`{x}`' for x in refs) if refs else '（無 —— 這個洞還沒有任何文件寫過）'} |")
        L += ["",
              f"**宣稱**：{r.get('CLAIM','?')}", "",
              f"**為什麼值得一支攻擊**：{r.get('WHY','?')}", "",
              f"單獨跑：`./redteam/run.sh {r['file'][:3]}`", "", "---", ""]

    L += ["## 這份索引證明什麼、不證明什麼", "",
          "**證明**：每支攻擊都宣告了預期，且宣告與索引不會漂移（索引是推導出來的）。", "",
          "**不證明**：攻擊寫得對。攻擊會不會說謊由 `900`/`901` 兩支 canary 守，",
          "而 canary 會不會失效，目前只能靠人手動閹割 `lib.sh` 來驗（見 `redteam/README.md`）。", ""]
    return "\n".join(L) + "\n"


def main(argv):
    try:
        new = build()
    except SystemExit as e:
        print(e, file=sys.stderr)
        return 1

    # 比對時忽略時間戳那行，否則永遠顯示過期（假紅）
    def norm(s):
        return "\n".join(l for l in s.splitlines() if not l.startswith("> 產生於"))

    if "--check" in argv:
        if not OUT.exists():
            print("INDEX.md 不存在 —— 跑 python3 redteam/index.py", file=sys.stderr)
            return 1
        if norm(OUT.read_text(encoding="utf-8")) != norm(new):
            print("INDEX.md 已過期（attacks/ 的檔頭變了）—— 跑 python3 redteam/index.py",
                  file=sys.stderr)
            return 1
        print("INDEX.md 是最新的")
        return 0

    OUT.write_text(new, encoding="utf-8")
    print(f"→ {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
