#!/usr/bin/env python3
"""從 ~/.debugpedia 匯出成 repo 內的稽核快照。

為什麼是「匯出」不是「手寫」：
  手抄一份到 markdown 就是鐵律一禁的事 —— 抄本不會跟著本體變。
  這支讓 audit/*.md 永遠是 ledger 的投影，重跑就重新推導。

  但注意它的界線：它證明「這些條目在 ledger 裡」，
  不證明「這些條目是真的」。真假由 audit/2026-07-27-verification.md
  裡的每一條可重跑指令負責。
"""
import json, os, sys
from datetime import datetime, timezone
from pathlib import Path

DIR = Path(os.environ.get("DEBUGPEDIA_DIR", Path.home() / ".debugpedia"))
OUT = Path(__file__).parent / "LEDGER-SNAPSHOT.md"


def rows():
    out = []
    for f in sorted(DIR.glob("*.jsonl")):
        if f.name.startswith("_"):        # ledger 不是 debug 紀錄（P0-1 同一個坑）
            continue
        for ln in f.read_text(encoding="utf-8", errors="replace").splitlines():
            ln = ln.strip()
            if ln:
                try:
                    out.append(json.loads(ln))
                except json.JSONDecodeError:
                    pass
    return out


def main():
    rs = rows()
    if not rs:
        print("ledger 為空，不產出快照（避免生出一份空的假證據）", file=sys.stderr)
        return 1
    errs = [r for r in rs if r.get("kind") not in ("open", "done")]
    opens = [r for r in rs if r.get("kind") == "open"]
    closed = {r.get("closes") for r in rs if r.get("kind") == "done"}
    todo = [r for r in opens if r["id"] not in closed]

    def prio(r):
        t = r.get("tags") or ""
        return ("P0" not in t, "P1" not in t, r.get("ts", ""))

    L = []
    L.append("# LEDGER 快照\n")
    L.append(f"> **自動產生 —— 不要手改。** `python3 audit/export.py` 重新推導。\n")
    L.append(f"> 產生於 {datetime.now(timezone.utc).isoformat(timespec='seconds')}"
             f" · 來源 `{DIR}`\n")
    L.append("> 這份證明「條目在 ledger 裡」，**不證明條目是真的**。")
    L.append("> 真假由 `audit/2026-07-27-verification.md` 的可重跑指令負責。\n")
    L.append(f"\n## 錯誤 {len(errs)} 條（鐵律三 A 類）\n")
    L.append("| # | 優先 | 什麼 | 位置 | 標籤 |")
    L.append("|---|---|---|---|---|")
    for i, r in enumerate(sorted(errs, key=prio), 1):
        t = r.get("tags") or ""
        p = "P0" if "P0" in t else "P1" if "P1" in t else "P2"
        w = (r.get("where") or "—").replace("|", "\\|")
        L.append(f"| {i} | {p} | {r['what'].replace('|','\\|')} | `{w}` | {t} |")

    L.append(f"\n## 未收尾 {len(todo)} 條（鐵律三 B 類）\n")
    L.append("| # | 優先 | 要做什麼 | 位置 | 被什麼擋住 |")
    L.append("|---|---|---|---|---|")
    for i, r in enumerate(sorted(todo, key=prio), 1):
        t = r.get("tags") or ""
        p = "P0" if "P0" in t else "P1" if "P1" in t else "P2"
        w = (r.get("where") or "—").replace("|", "\\|")
        L.append(f"| {i} | {p} | {r['what'].replace('|','\\|')} | `{w}` "
                 f"| {r.get('blocked') or '沒擋住，就是還沒做'} |")

    tags = {}
    for r in errs:
        for t in (r.get("tags") or "").split(","):
            t = t.strip()
            if t and t not in ("P0", "P1", "P2"):
                tags[t] = tags.get(t, 0) + 1
    hot = {k: v for k, v in tags.items() if v >= 2}
    if hot:
        L.append("\n## 法則候選 · 出現 ≥2 次的類別\n")
        L.append("> 單筆是事件，重複才是法則。≥2 次 = 該從結構上關掉整類。\n")
        for k, v in sorted(hot.items(), key=lambda x: -x[1]):
            L.append(f"- **{k}** ×{v}")

    sv = sum(1 for r in errs if "self-violation" in (r.get("tags") or "") or "self" in (r.get("tags") or "").split(","))
    L.append(f"\n## 自我違反 {sv} / {len(errs)} 條\n")
    L.append("這個 repo 違反自己寫下的鐵律的次數。**這個數字是本專案最重要的指標。**")
    L.append("它下降代表工事在收斂；它上升代表在寫更多宣稱而不是更多證據。\n")
    OUT.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"→ {OUT}  ({len(errs)} 錯誤 / {len(todo)} 未收尾 / {sv} 自我違反)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
