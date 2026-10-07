import BitFoundation
import Foundation

/// Release diagnostics deliberately accept typed events, never arbitrary log
/// strings, payloads, nicknames, keys or errors. Storage is bounded and RAM-only.
final class DesktopDebugCapture: @unchecked Sendable {
    enum Event: String, CaseIterable, Sendable {
        case enabled = "Debug mode enabled"
        case connected = "Peer connected"
        case disconnected = "Peer disconnected"
        case handshake = "Handshake requested"
        case authenticated = "Peer authenticated"
        case privateReceived = "Private text received"
        case delivered = "Delivery receipt received"
        case read = "Read receipt received"
        case queued = "Private text retained"
        case transmitted = "Private text handed to transport"
        case retried = "Private text retried"
        case acknowledged = "Outbox entry acknowledged"
        case dropped = "Outbox entry dropped"
        case discovery = "Discovery refresh requested"
        case continuousScan = "Continuous scanning enabled"
        case adaptiveScan = "Adaptive scanning restored"
        case retryRequested = "Pending delivery retry requested"
        case pingStarted = "Mesh ping started"
        case pingReturned = "Mesh ping returned"
        case pingTimeout = "Mesh ping timed out"
    }

    struct Entry: Identifiable, Equatable, Sendable {
        let id: UInt64
        let date: Date
        let event: Event
        let peer: String?
    }

    struct Snapshot: Sendable {
        let entries: [Entry]
        let counts: [Event: Int]
    }

    static let shared = DesktopDebugCapture()
    static let capacity = 300
    private let lock = NSLock()
    private var enabled = false
    private var sequence: UInt64 = 0
    private var entries: [Entry] = []
    private var counts: [Event: Int] = [:]

    var isEnabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return enabled
    }

    func setEnabled(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        enabled = value
        if !value { clearLocked() }
    }

    func record(_ event: Event, peerID: PeerID? = nil, at date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        guard enabled else { return }
        sequence &+= 1
        counts[event, default: 0] += 1
        entries.append(Entry(id: sequence, date: date, event: event, peer: Self.shortPeer(peerID)))
        if entries.count > Self.capacity { entries.removeFirst(entries.count - Self.capacity) }
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(entries: entries, counts: counts)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        clearLocked()
    }

    private func clearLocked() {
        entries.removeAll()
        counts.removeAll()
    }

    static func shortPeer(_ peerID: PeerID?) -> String? {
        guard let id = peerID?.id else { return nil }
        // Never turn a malformed external identifier into arbitrary console text.
        guard !id.isEmpty, id.utf8.allSatisfy({
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }) else { return "peer" }
        return String(id.prefix(8)) + "…"
    }
}
