import Foundation

/// Bridges legacy NotificationCenter callbacks onto the main actor synchronously.
/// Registration uses the main operation queue, so assumeIsolated asserts an
/// existing scheduling guarantee rather than dispatching UI objects across actors.
final class MainActorNotification: @unchecked Sendable {
    // Immutable registration token. NotificationCenter supports removing observers
    // on any thread; no mutable observer state is shared outside the main actor.
    private let token: NSObjectProtocol

    @MainActor
    init(_ name: Notification.Name, object: AnyObject? = nil,
         handler: @escaping @MainActor @Sendable (Notification) -> Void) {
        token = NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { notification in
            // Notification is not Sendable because its payload is untyped. This
            // envelope is consumed synchronously on the guaranteed main queue;
            // neither payload nor callback is dispatched to another executor.
            let delivery = MainQueueDelivery(notification: notification)
            MainActor.assumeIsolated { handler(delivery.notification) }
        }
    }

    deinit { NotificationCenter.default.removeObserver(token) }
}

private struct MainQueueDelivery: @unchecked Sendable {
    let notification: Notification
}
