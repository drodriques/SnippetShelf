import Foundation

/// Serialize the complete read/modify/write/publish transaction across awaits.
/// Queued edits read state after earlier edits have committed, preventing lost updates.
@MainActor
public final class AsyncMutationQueue {
    private var tail: Task<Void, Never>?
    private var generation: UInt64 = 0
    public var hasPendingOperations: Bool { tail != nil }
    public init() {}

    public func run<Value: Sendable>(_ operation: @escaping @MainActor () async -> Value) async -> Value {
        let previous = tail
        generation &+= 1
        let current = generation
        let work = Task { @MainActor in
            await previous?.value
            return await operation()
        }
        tail = Task { @MainActor [weak self] in
            _ = await work.value
            if self?.generation == current { self?.tail = nil }
        }
        return await work.value
    }

    public func finishPendingOperations() async {
        await tail?.value
    }
}
