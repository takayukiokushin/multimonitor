import Foundation

// コマンドラインツールだけの環境には XCTest がないため、最小限の確認の仕組みを自前で持つ。
// `make test`(= swift run OLEDGuardCoreChecks)で実行する。

enum Harness {
    static var testCount = 0
    static var failedTests: [String] = []
    static var currentFailures: [String] = []
}

func test(_ name: String, _ body: () throws -> Void) {
    Harness.testCount += 1
    Harness.currentFailures = []
    do {
        try body()
    } catch {
        Harness.currentFailures.append("例外: \(error)")
    }
    if Harness.currentFailures.isEmpty {
        print("✓ \(name)")
    } else {
        Harness.failedTests.append(name)
        print("✗ \(name)")
        for failure in Harness.currentFailures {
            print("    \(failure)")
        }
    }
}

private func fail(_ message: String, _ file: StaticString, _ line: UInt) {
    let fileName = ("\(file)" as NSString).lastPathComponent
    Harness.currentFailures.append("\(fileName):\(line): \(message)")
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    if actual != expected {
        fail("\(actual) と \(expected) が一致しません", file, line)
    }
}

func expectTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if !value {
        fail("true であるべきところが false です", file, line)
    }
}

func expectFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if value {
        fail("false であるべきところが true です", file, line)
    }
}

func expectNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
    if let value {
        fail("nil であるべきところが \(value) です", file, line)
    }
}
