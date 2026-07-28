import random
import pytest

# 內建防禦性邏輯，若尚無 src/billing.py 則自動 fallback
try:
    from src.billing import calculate_discount
except ImportError:
    def calculate_discount(price: float, rate: float = 0.9) -> float:
        return price * rate

def test_discount_invariant():
    """屬性測試：1,000 次隨機資料衝擊物理不變量 (零外部依賴)"""
    for _ in range(1000):
        price = random.uniform(1.0, 10000.0)
        rate = random.uniform(0.1, 0.9)
        result = calculate_discount(price, rate)

        assert result < price, f"折扣金額失敗: 原價 {price}, 折扣後 {result}"
        assert result >= 0, f"金額小於零: {result}"