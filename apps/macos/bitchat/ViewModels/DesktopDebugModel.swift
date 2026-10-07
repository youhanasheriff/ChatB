import BitFoundation
import Combine
import CoreBluetooth
import Foundation

@MainActor
final class DesktopDebugSettings: ObservableObject {
    static let shared = DesktopDebugSettings()
    static let storageKey = "desktop.debug.enabled"
    @Published private(set) var isEnabled: Bool
    private let defaults: UserDefaults
    private let capture: DesktopDebugCapture

    init(defaults: UserDefaults = .standard, capture: DesktopDebugCapture = .shared) {
        self.defaults = defaults
        self.capture = capture
        isEnabled = defaults.bool(forKey: Self.storageKey)
        capture.setEnabled(isEnabled)
        if isEnabled { capture.record(.enabled) }
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.storageKey)
        capture.setEnabled(enabled)
        if enabled { capture.record(.enabled) }
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    func panicReset() {
        setEnabled(false)
        defaults.removeObject(forKey: Self.storageKey)
        capture.clear()
    }

    static let didChange = Notification.Name("desktop.debug.didChange")
}

struct DesktopBLERadioSnapshot: Sendable {
    var central = "unknown"
    var peripheral = "unknown"
    var scanning = false
    var advertising = false
    var outboundLinks = 0
    var inboundLinks = 0
    var connecting = 0
    var candidates = 0
    var continuousScanning = false
}

@MainActor
final class DesktopDebugModel: ObservableObject {
    struct Peer: Identifiable {
        let id: PeerID
        let shortID: String
        let connected: Bool
        let verifiedAnnounce: Bool
        let session: String
    }

    @Published private(set) var radio = DesktopBLERadioSnapshot()
    @Published private(set) var peers: [Peer] = []
    @Published private(set) var pendingMessages = 0
    @Published private(set) var events: [DesktopDebugCapture.Entry] = []
    @Published private(set) var counts: [DesktopDebugCapture.Event: Int] = [:]
    @Published private(set) var pingResults: [PeerID: String] = [:]
    @Published private(set) var refreshedAt: Date?
    @Published private(set) var isRefreshing = false
    private let transport: Transport
    private let router: MessageRouter
    private let settings: DesktopDebugSettings
    private let capture: DesktopDebugCapture
    private var pingGeneration = 0

    init(transport: Transport, router: MessageRouter,
         settings: DesktopDebugSettings = .shared, capture: DesktopDebugCapture = .shared) {
        self.transport = transport
        self.router = router
        self.settings = settings
        self.capture = capture
    }

    var supportsBluetoothTools: Bool { transport is BLEService }
    var supportsPing: Bool { transport is MeshDiagnosing }
    var buildDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        #if DEBUG && !BITCHAT_INTEROP
        let network = "isolated test mesh"
        #else
        let network = "release mesh"
        #endif
        #if DEBUG
        let configuration = "Debug"
        #else
        let configuration = "Release"
        #endif
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        return "Version \(version) (\(build)) · \(configuration) · \(architecture) · \(network)"
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if let ble = transport as? BLEService {
            radio = await withCheckedContinuation { continuation in
                ble.captureDesktopRadioSnapshot { continuation.resume(returning: $0) }
            }
        }
        peers = transport.currentPeerSnapshots().sorted { $0.peerID < $1.peerID }.map {
            Peer(id: $0.peerID, shortID: DesktopDebugCapture.shortPeer($0.peerID) ?? "peer",
                 connected: $0.isConnected, verifiedAnnounce: $0.isVerified,
                 session: Self.sessionLabel(transport.getNoiseSessionState(for: $0.peerID)))
        }
        pendingMessages = router.pendingPrivateMessageCount
        let snapshot = capture.snapshot()
        events = snapshot.entries.reversed()
        counts = snapshot.counts
        refreshedAt = Date()
    }

    func setContinuousScanning(_ enabled: Bool) {
        guard settings.isEnabled, let ble = transport as? BLEService else { return }
        ble.setDesktopContinuousScanning(enabled)
        capture.record(enabled ? .continuousScan : .adaptiveScan)
    }

    func refreshDiscovery() {
        guard settings.isEnabled, let ble = transport as? BLEService else { return }
        ble.refreshDesktopDiscovery()
        capture.record(.discovery)
    }

    func retryPending() {
        guard settings.isEnabled else { return }
        capture.record(.retryRequested)
        router.flushAllOutbox()
    }

    func ping(_ peerID: PeerID) {
        guard settings.isEnabled, pingResults[peerID] != "Waiting…",
              let diagnostics = transport as? MeshDiagnosing else { return }
        pingResults[peerID] = "Waiting…"
        let generation = pingGeneration
        capture.record(.pingStarted, peerID: peerID)
        diagnostics.sendMeshPing(to: peerID) { [weak self] result in
            guard let self, self.settings.isEnabled, self.pingGeneration == generation else { return }
            if let result {
                self.pingResults[peerID] = "\(result.rttMs) ms · \(result.hops) hop(s)"
                self.capture.record(.pingReturned, peerID: peerID)
            } else {
                self.pingResults[peerID] = "No reply"
                self.capture.record(.pingTimeout, peerID: peerID)
            }
        }
    }

    func clear() {
        capture.clear()
        events = []
        counts = [:]
        pingGeneration += 1
        pingResults = [:]
    }

    func debugModeChanged() {
        if !settings.isEnabled {
            (transport as? BLEService)?.setDesktopContinuousScanning(false)
            clear()
        }
    }

    /// Report omits nicknames, full identities, locations, relay addresses and content.
    var report: String {
        var lines = ["BitChat Desktop diagnostics", buildDescription,
                     "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
                     "Debug mode: \(settings.isEnabled ? "on" : "off")",
                     "Bluetooth central: \(radio.central); peripheral: \(radio.peripheral)",
                     "Scanning: \(radio.scanning); advertising: \(radio.advertising)",
                     "Links: outbound \(radio.outboundLinks), inbound \(radio.inboundLinks), connecting \(radio.connecting)",
                     "Candidates: \(radio.candidates); retained private texts: \(pendingMessages)"]
        for peer in peers {
            lines.append("Peer \(peer.shortID): connected=\(peer.connected), verified announce=\(peer.verifiedAnnounce), session=\(peer.session)")
        }
        lines.append("Events since console reset:")
        for event in DesktopDebugCapture.Event.allCases where counts[event, default: 0] > 0 {
            lines.append("\(event.rawValue): \(counts[event, default: 0])")
        }
        let formatter = ISO8601DateFormatter()
        for entry in events.reversed() {
            lines.append("\(formatter.string(from: entry.date)) \(entry.event.rawValue)\(entry.peer.map { " · " + $0 } ?? "")")
        }
        return lines.joined(separator: "\n")
    }

    static func sessionLabel(_ state: LazyHandshakeState) -> String {
        switch state {
        case .none: return "No session"
        case .handshakeQueued: return "Handshake queued"
        case .handshaking: return "Handshaking"
        case .established: return "Established"
        case .failed: return "Failed"
        }
    }
}
