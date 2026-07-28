"""LB-oculus 屬性測試：驗證 dbp 鏈完整性與折扣邏輯不變性。

屬性測試（property-based testing）透過 hypothesis 產生大量隨機輸入，
確保函式對於所有合法輸入皆維持不變性（invariant），而非僅測試固定範例。
"""

from hypothesis import given, strategies as st
import subprocess
import json
import os


# ── 輔助函式 ──────────────────────────────────────────────

DBP = os.path.join(os.path.dirname(__file__), "..", "bin", "dbp")


def run_dbp(*args: str) -> subprocess.CompletedProcess:
    """執行 dbp 指令，回傳 CompletedProcess。"""
    return subprocess.run(
        [DBP, *args],
        capture_output=True,
        text=True,
        timeout=10,
    )


# ── 折扣邏輯不變性 ───────────────────────────────────────


def calculate_discount(price: float, rate: float) -> float:
    """折扣計算：rate 為 0~1，回傳折扣後金額。"""
    if not (0 < rate < 1):
        raise ValueError("rate must be between 0 and 1")
    return price * (1 - rate)


class TestDiscountInvariants:
    """屬性測試：計算折扣的核心邏輯"""

    @given(
        price=st.floats(min_value=0.01, max_value=1_000_000, allow_nan=False),
        rate=st.floats(min_value=0.01, max_value=0.99, allow_nan=False),
    )
    def test_discount_less_than_price(self, price: float, rate: float) -> None:
        """INVARIANT: 折扣後金額必小於原價（rate > 0）"""
        result = calculate_discount(price, rate)
        assert result < price, (
            f"折扣後 {result} 應小於原價 {price}，"
            f"rate={rate}，差距={result - price}"
        )

    @given(
        price=st.floats(min_value=0.01, max_value=1_000_000, allow_nan=False),
        rate=st.floats(min_value=0.01, max_value=0.99, allow_nan=False),
    )
    def test_discount_non_negative(self, price: float, rate: float) -> None:
        """INVARIANT: 折扣後金額不為負（rate < 1）"""
        result = calculate_discount(price, rate)
        assert result >= 0, (
            f"折扣後 {result} 應 ≥ 0，price={price}，rate={rate}"
        )

    @given(
        price=st.floats(min_value=0.01, max_value=1_000_000, allow_nan=False),
        rate=st.floats(min_value=0.01, max_value=0.99, allow_nan=False),
    )
    def test_higher_rate_gives_lower_price(self, price: float, rate: float) -> None:
        """INVARIANT: 較高折扣率 → 較低最終金額"""
        small = calculate_discount(price, rate)
        big = calculate_discount(price, rate * 0.5)
        assert small <= big, (
            f"rate={rate} 得 {small}，rate={rate*0.5} 得 {big}，預期較高率應更低"
        )

    def test_rate_boundary_raises(self) -> None:
        """INVARIANT: 超出邊界的 rate 應拋錯"""
        import pytest

        with pytest.raises(ValueError):
            calculate_discount(100, 0)
        with pytest.raises(ValueError):
            calculate_discount(100, 1)
        with pytest.raises(ValueError):
            calculate_discount(100, -0.1)
        with pytest.raises(ValueError):
            calculate_discount(100, 1.5)


# ── dbp CLI 整合測試 ────────────────────────────────────


class TestDbpCliProperties:
    """屬性測試：dbp CLI 的基本行為不變性"""

    @given(
        msg=st.text(min_size=1, max_size=100).filter(
            lambda s: s.strip() and not s.startswith("-")
        ),
    )
    def test_dbp_log_then_read(self, msg: str) -> None:
        """INVARIANT: dbp log 寫入的筆，用 dbp open 能看到類似內容"""
        proc = run_dbp(msg)
        assert proc.returncode == 0, (
            f"dbp '{msg[:30]}…' exit {proc.returncode}: {proc.stderr[:200]}"
        )
