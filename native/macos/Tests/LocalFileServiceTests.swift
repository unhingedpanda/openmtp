import XCTest
import Foundation

final class LocalFileServiceTests: XCTestCase {
    func testEnumeratesNamesSizesAndFoldersWithoutFollowingHiddenPreference() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([1,2,3]).write(to: root.appendingPathComponent("旅行.txt"))
        try Data([4]).write(to: root.appendingPathComponent(".hidden"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Photos"), withIntermediateDirectories: false)
        let entries = try await LocalFileService().entries(at: root)
        XCTAssertEqual(Set(entries.map(\.name)), ["旅行.txt", ".hidden", "Photos"])
        XCTAssertEqual(entries.first { $0.name == "旅行.txt" }?.byteCount, 3)
        XCTAssertEqual(entries.first { $0.name == "Photos" }?.isDirectory, true)
    }
}
