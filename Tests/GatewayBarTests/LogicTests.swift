import Foundation
import XCTest
@testable import GatewayBar

final class BudgetTests: XCTestCase {
    func testFractionIsSpendOverMax() {
        let b = BudgetInfo(spend: 84, maxBudget: 120)
        XCTAssertEqual(b.fraction ?? 0, 0.7, accuracy: 0.0001)
    }

    func testFractionIsNilWithoutOrZeroBudget() {
        XCTAssertNil(BudgetInfo(spend: 5, maxBudget: nil).fraction)
        XCTAssertNil(BudgetInfo(spend: 5, maxBudget: 0).fraction)
    }

    func testPeriodLabels() {
        let cases: [(String, String)] = [
            ("7d", "wekelijks"), ("1w", "wekelijks"), ("30d", "maandelijks"),
            ("1mo", "maandelijks"), ("1d", "dagelijks"), ("24h", "dagelijks"), ("3d", "3d"),
        ]
        for (duration, label) in cases {
            XCTAssertEqual(BudgetInfo(spend: 0, maxBudget: 120, duration: duration).period, label, duration)
        }
    }

    func testPeriodIsNilWhenMissing() {
        XCTAssertNil(BudgetInfo(spend: 0, maxBudget: 120, duration: nil).period)
        XCTAssertNil(BudgetInfo(spend: 0, maxBudget: 120, duration: "").period)
    }
}

final class HelperTests: XCTestCase {
    func testNumParsesNumbersAndStrings() {
        XCTAssertEqual(num(1.5), 1.5)
        XCTAssertEqual(num(3), 3.0)
        XCTAssertEqual(num("2.25"), 2.25)
        XCTAssertNil(num(nil))
        XCTAssertNil(num("abc"))
    }

    func testMoneyFormatting() {
        XCTAssertEqual(money(4.2), "$4.20")
        XCTAssertEqual(money(120), "$120.00")
        XCTAssertEqual(money(1500), "$1500")
    }
}
