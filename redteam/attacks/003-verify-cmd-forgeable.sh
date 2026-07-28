#!/bin/sh
# EXPECT: BREACH
# TARGET: bin/dbp:202 VERIFY_CMD
# CLAIM: 鐵律二的機械化靠字串比對，跑一條「空殼的」pytest 也算驗過
# WHY: 只認指令長相、不認退出碼，等於獎勵造假 —— 造假比做對便宜。
. "$RT_LIB"

need "$SANDBOX/bin/dbp"
grep -q 'VERIFY_CMD' "$SANDBOX/bin/dbp" || sealed "VERIFY_CMD 已不存在，攻擊失效"

# 直接 import 被攻擊者的模組取用它「真正編譯出來的」正則。
# 不手抄、也不自己解析拼接字串（前一版用 literal_eval 抽，跨三行拼接抽不出來 → BROKEN）。
res=$("$PY" - "$SANDBOX/bin/dbp" << 'PYEOF'
import sys, importlib.util, importlib.machinery   # machinery 要顯式 import
try:
    loader = importlib.machinery.SourceFileLoader("dbp_under_test", sys.argv[1])
    spec = importlib.util.spec_from_loader("dbp_under_test", loader)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
except SystemExit:
    pass
except Exception as e:
    print("LOADFAIL", type(e).__name__, e); sys.exit(3)
rx = getattr(m, "VERIFY_CMD", None)
if rx is None:
    print("NOATTR"); sys.exit(3)
# 這些都明顯沒有驗證任何東西
for fake in ("pytest --version", "echo pytest", "false; curl --help",
             "pytest /nonexistent  # 必定失敗", "make --dry-run"):
    if rx.search(fake):
        print("HIT", fake); break
else:
    print("NOHIT")
PYEOF
) || broken "無法載入被攻擊者的 VERIFY_CMD：$res"

case "$res" in
  HIT*) breach "「$(printf '%s' "$res" | cut -d' ' -f2-)」被 VERIFY_CMD 認定為有效驗證 —— 不看退出碼、不看是否真的驗過東西" ;;
  NOHIT) sealed "VERIFY_CMD 已不接受空殼指令" ;;
  *) broken "非預期回應：$res" ;;
esac
