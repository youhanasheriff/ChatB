import BitFoundation
import Foundation
import Testing
@testable import bitchat

struct DesktopDebugCaptureTests {
    @Test func disabledCaptureNeverRetainsEventsAndDisablingClearsHistory() {
        let capture = DesktopDebugCapture()
        capture.record(.connected)
        #expect(capture.snapshot().entries.isEmpty)
        capture.setEnabled(true)
        capture.record(.connected)
        #expect(capture.snapshot().counts[.connected] == 1)
        capture.setEnabled(false)
        capture.record(.read)
        #expect(capture.snapshot().entries.isEmpty)
        #expect(capture.snapshot().counts.isEmpty)
    }

    @Test func boundedHistoryKeepsNewestEventsAndFullSessionCounters() {
        let capture = DesktopDebugCapture()
        capture.setEnabled(true)
        for number in 0..<1000 {
            capture.record(.retried, at: Date(timeIntervalSince1970: Double(number)))
        }
        let snapshot = capture.snapshot()
        #expect(snapshot.entries.count == 300)
        #expect(snapshot.entries.first?.date == Date(timeIntervalSince1970: 700))
        #expect(snapshot.entries.last?.date == Date(timeIntervalSince1970: 999))
        #expect(snapshot.counts[.retried] == 1000)
        capture.clear()
        #expect(capture.snapshot().counts.isEmpty)
    }

    @Test func identifiersCannotInjectTextAndFullKeysAreNeverRetained() {
        let capture = DesktopDebugCapture()
        capture.setEnabled(true)
        let key = String(repeating: "ab", count: 32)
        capture.record(.authenticated, peerID: PeerID(str: key))
        capture.record(.connected, peerID: PeerID(str: "private message\npassword:secret"))
        let entries = capture.snapshot().entries
        #expect(entries[0].peer == "abababab…")
        #expect(entries[1].peer == "peer")
        #expect(!entries.map { $0.peer ?? "" }.joined().contains("secret"))
    }

    @Test func concurrentRecordingDoesNotLoseCountsOrExceedCapacity() async {
        let capture = DesktopDebugCapture()
        capture.setEnabled(true)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    for _ in 0..<200 { capture.record(.read) }
                }
            }
        }
        let snapshot = capture.snapshot()
        #expect(snapshot.counts[.read] == 1600)
        #expect(snapshot.entries.count == 300)
        #expect(Set(snapshot.entries.map(\.id)).count == 300)
    }
}

@MainActor
struct DesktopDebugModelTests {
    private func fixture() -> (DesktopDebugSettings, DesktopDebugCapture, UserDefaults) {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let capture = DesktopDebugCapture()
        return (DesktopDebugSettings(defaults: defaults, capture: capture), capture, defaults)
    }

    @Test func preferenceRestoresAndPanicClearsCaptureAndPreference() {
        let (settings, capture, defaults) = fixture()
        #expect(!settings.isEnabled)
        settings.setEnabled(true)
        capture.record(.privateReceived)
        let restoredCapture = DesktopDebugCapture()
        let restored = DesktopDebugSettings(defaults: defaults, capture: restoredCapture)
        #expect(restored.isEnabled)
        settings.panicReset()
        #expect(!settings.isEnabled)
        #expect(capture.snapshot().entries.isEmpty)
        #expect(defaults.object(forKey: DesktopDebugSettings.storageKey) == nil)
    }

    @Test func reportContainsStatusButOmitsContentNicknamesKeysAndErrors() async {
        let (settings, capture, _) = fixture()
        settings.setEnabled(true)
        let peer = PeerID(str: "abcdef0123456789")
        let transport = MockTransport()
        transport.updatePeerSnapshots([
            TransportPeerSnapshot(peerID: peer, nickname: "PRIVATE NICKNAME", isConnected: true,
                                  noisePublicKey: Data(repeating: 42, count: 32), lastSeen: Date())
        ])
        transport.peerNoiseStates[peer] = .failed(NSError(domain: "SECRET ERROR", code: 1))
        let router = MessageRouter(transports: [transport])
        router.sendPrivate("PRIVATE MESSAGE BODY", to: peer, recipientNickname: "PRIVATE NICKNAME", messageID: "SECRET MESSAGE ID")
        let model = DesktopDebugModel(transport: transport, router: router, settings: settings, capture: capture)
        await model.refresh()
        #expect(model.pendingMessages == 1)
        #expect(model.peers.first?.session == "Failed")
        #expect(model.report.contains("abcdef01…"))
        #expect(!model.report.contains(peer.id))
        #expect(!model.report.contains("PRIVATE"))
        #expect(!model.report.contains("SECRET"))
    }

    @Test func retryToolIsGatedAndUsesExistingOutbox() async {
        let (settings, capture, _) = fixture()
        let peer = PeerID(str: "abcdef0123456789")
        let transport = MockTransport()
        let router = MessageRouter(transports: [transport])
        router.sendPrivate("Hello", to: peer, recipientNickname: "Peer", messageID: "stable-id")
        transport.connectedPeers = [peer]
        transport.securePeers = [peer]
        let model = DesktopDebugModel(transport: transport, router: router, settings: settings, capture: capture)
        model.retryPending()
        #expect(transport.sentPrivateMessages.isEmpty)
        settings.setEnabled(true)
        model.retryPending()
        #expect(transport.sentPrivateMessages.map(\.messageID) == ["stable-id"])
        router.markDelivered("stable-id", from: [peer])
        model.retryPending()
        #expect(transport.sentPrivateMessages.count == 1)
    }

    @Test func pingLateCompletionCannotRepopulateClearedConsole() async {
        let (settings, capture, _) = fixture()
        settings.setEnabled(true)
        let peer = PeerID(str: "abcdef0123456789")
        let transport = MockTransport()
        transport.meshPingResult = MeshPingResult(rttMs: 5, hops: 1)
        let model = DesktopDebugModel(transport: transport, router: MessageRouter(transports: [transport]), settings: settings, capture: capture)
        model.ping(peer)
        model.clear()
        for _ in 0..<10 { await Task.yield() }
        #expect(model.pingResults.isEmpty)
        #expect(capture.snapshot().entries.isEmpty)
        settings.setEnabled(false)
        model.ping(peer)
        #expect(transport.sentMeshPings.count == 1)
    }
}
