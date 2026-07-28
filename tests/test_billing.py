import random
import pytest

# 假設這是我們要測試的業務邏輯
# 在實際專案中可以匯入你的模組：from src.billing import calculate_discount

def calculate_discount(price: float, rate: float) -> float:
    """這是 AI 寫的功能程式碼 (範例)"""
    return price * rate

def test_discount_properties():
    """
    屬性測試：自動生成 1,000 組隨機數字衝擊程式碼
    不考死板的答案，而是測試「絕對不變量」
    """
    for _ in range(1000):
        # 隨機產生 1 ~ 10,000 元的金額
        price = random.uniform(1.0, 10000.0)
        # 隨機產生 0.1 ~ 0.9 (一折到九折) 的折扣率
        rate = random.uniform(0.1, 0.9)

        result = calculate_discount(price, rate)

        # 鐵律 1：打折後的價格絕對要比原價便宜
        assert result < price, f"算錯了！原價 {price} 折扣後變成 {result}"

        # 鐵律 2：金額絕對不能小於 0
        assert result >= 0, f"金額出現負數：{result}"
