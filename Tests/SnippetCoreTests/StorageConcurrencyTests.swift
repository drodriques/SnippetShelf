import XCTest
@testable import SnippetCore

final class StorageConcurrencyTests: XCTestCase {
    @MainActor
    func testOverlappingEditsReadCommittedStateAndDoNotLoseEitherEdit() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = SnippetStorage(fileURL: directory.appendingPathComponent("snippets.json"))
        let queue = AsyncMutationQueue()
        var visible = SnippetLibrary()
        let started = expectation(description: "First edit is suspended")
        let first = Task {
            await queue.run {
                var next = visible
                started.fulfill()
                try? await Task.sleep(for: .milliseconds(60))
                next.snippets.append(Snippet(title: "First", content: "1"))
                do { try await storage.save(next) } catch { return false }
                visible = next
                return true
            }
        }
        await fulfillment(of: [started], timeout: 2)
        let second = Task {
            await queue.run {
                var next = visible
                next.snippets.append(Snippet(title: "Second", content: "2"))
                do { try await storage.save(next) } catch { return false }
                visible = next
                return true
            }
        }
        let firstSaved = await first.value
        let secondSaved = await second.value
        await queue.finishPendingOperations()
        XCTAssertTrue(firstSaved)
        XCTAssertTrue(secondSaved)
        XCTAssertFalse(queue.hasPendingOperations)
        let restored = try await storage.load()
        XCTAssertEqual(restored.snippets.map(\.title), ["First", "Second"])
        XCTAssertEqual(visible, restored)
    }

    @MainActor
    func testFinishingPendingOperationsWaitsForWriteEvenIfCallerIsCancelled() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = WordStorage(fileURL: directory.appendingPathComponent("words.json"))
        let queue = AsyncMutationQueue()
        let started = expectation(description: "Save is pending")
        let caller = Task {
            await queue.run {
                started.fulfill()
                try? await Task.sleep(for: .milliseconds(60))
                var words = WordLibrary()
                _ = try? words.add(word: "Durable", definition: "Saved before shutdown.")
                do { try await storage.save(words) } catch { return false }
                return true
            }
        }
        await fulfillment(of: [started], timeout: 2)
        caller.cancel()
        await queue.finishPendingOperations()
        let saved = await caller.value
        let restored = try await storage.load()
        XCTAssertTrue(saved)
        XCTAssertEqual(restored.current?.word, "Durable")
        XCTAssertFalse(queue.hasPendingOperations)
    }

    func testBackgroundStorageStillRefusesToOverwriteCorruptFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("snippets.json")
        let corrupt = Data("unreadable saved data".utf8)
        try corrupt.write(to: file)
        let storage = SnippetStorage(fileURL: file)
        do {
            try await storage.save(SnippetLibrary())
            XCTFail("Unreadable files must not be overwritten")
        } catch {
            XCTAssertEqual(try Data(contentsOf: file), corrupt)
        }
    }
}
