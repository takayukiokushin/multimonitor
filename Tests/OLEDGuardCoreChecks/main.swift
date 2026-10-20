import Foundation

AllTests.run()

print("")
if Harness.failedTests.isEmpty {
    print("すべて成功: \(Harness.testCount) 件")
    exit(0)
} else {
    print("失敗: \(Harness.failedTests.count) / \(Harness.testCount) 件")
    for name in Harness.failedTests {
        print("  - \(name)")
    }
    exit(1)
}
