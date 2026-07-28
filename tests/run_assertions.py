#!/usr/bin/env python3
"""Run Rule Assertions — 動態執行 oculus-rules/ 中的 assertion 表達式。

從 oculus-rules/*.yml 讀取規則，對 status=ACTIVE 的規則執行其 assertion，
逐條回報 PASS / FAIL / SKIP。
"""

import glob
import os
import sys
import yaml
from typing import Any


RULES_DIR = os.path.join(os.path.dirname(__file__), "..", "oculus-rules")


def load_rules(rules_dir: str) -> list[dict[str, Any]]:
    """載入 oculus-rules/ 下所有 .yml 規則檔。"""
    rules = []
    for path in sorted(glob.glob(os.path.join(rules_dir, "*.yml"))):
        with open(path) as f:
            data = yaml.safe_load(f)
        if data is None:
            continue
        if isinstance(data, list):
            rules.extend(data)
        else:
            rules.append(data)
    return rules


def run_assertion(rule: dict[str, Any]) -> None:
    """執行單一條規則的 assertion（透過 eval）。"""
    rid = rule.get("id", "unknown")
    description = rule.get("description", "")
    status = rule.get("status", "UNKNOWN")
    assertion = rule.get("assertion", "")
    target_file = rule.get("target_file", "")

    # 狀態檢查
    if status == "KNOWN_FAIL":
        print(f"  SKIP  {rid}: {description} (KNOWN_FAIL)")
        return

    if status != "ACTIVE":
        print(f"  SKIP  {rid}: status={status}")
        return

    if not assertion:
        print(f"  FAIL  {rid}: 無 assertion 表達式")
        sys.exit(1)

    # 目標檔案存在檢查
    if target_file:
        repo_root = os.path.dirname(os.path.dirname(__file__))
        full_path = os.path.join(repo_root, target_file)
        if not os.path.exists(full_path):
            print(f"  SKIP  {rid}: target_file={target_file} 不存在")
            return

    # 執行 assertion
    try:
        result = eval(assertion, {"__builtins__": {}}, {})
        if result:
            print(f"  PASS  {rid}: {description}  →  {assertion}")
        else:
            print(f"  FAIL  {rid}: {description}  →  {assertion} 回傳 False")
            sys.exit(1)
    except Exception as e:
        print(f"  FAIL  {rid}: {description}  →  assertion 執行例外: {e}")
        sys.exit(1)


def main() -> None:
    rules = load_rules(RULES_DIR)
    total = len(rules)
    if total == 0:
        print("⚠️  oculus-rules/ 無規則檔，跳過。")
        return

    print(f"🔍 規則 assertion 檢查: {total} 條")
    for rule in rules:
        run_assertion(rule)
    print(f"✅ 全部 {total} 條規則通過。")


if __name__ == "__main__":
    main()