import BitFoundation
import Combine
import Foundation

enum SharedContentDestination: Sendable, Equatable {
    case mesh
    case geohash(String)
    case privateConversation(peerID: PeerID, displayName: String)

    static func resolve(
        selectedPrivatePeerID: PeerID?,
        privateDisplayName: String?,
        activeChannel: ChannelID
    ) -> SharedContentDestination {
        if let selectedPrivatePeerID {
            let fallback = String(selectedPrivatePeerID.id.prefix(12))
            return .privateConversation(
                peerID: selectedPrivatePeerID,
                displayName: privateDisplayName?.trimmedOrNilIfEmpty ?? fallback
            )
        }

        switch activeChannel {
        case .mesh:
            return .mesh
        case .location(let channel):
            return .geohash(channel.geohash.lowercased())
        }
    }

    var displayName: String {
        switch self {
        case .mesh:
            return "#mesh"
        case .geohash(let geohash):
            return "#\(geohash)"
        case .privateConversation(_, let displayName):
            return displayName
        }
    }
}

struct SharedContentOffer: Identifiable, Sendable, Equatable {
    let payload: SharedContentPayload
    let destination: SharedContentDestination

    var id: UUID { payload.id }
}

/// Holds a pending extension handoff until the user chooses a destination and
/// explicitly adds it to the composer. This type has no send dependency by
/// design: confirming an import can never transmit a message.
@MainActor
final class SharedContentImportModel: ObservableObject {
    @Published private(set) var offer: SharedContentOffer?

    private let store: SharedContentStore?
    /// Desktop clipboard review is ephemeral; it does not need an App Group.
    private var localPayload: SharedContentPayload?

    init(store: SharedContentStore?) {
        self.store = store
    }

    func reviewLocal(_ payload: SharedContentPayload, destination: SharedContentDestination) throws {
        try payload.validate()
        localPayload = payload
        offer = SharedContentOffer(payload: payload, destination: destination)
    }

    @discardableResult
    func refresh(
        destination: SharedContentDestination,
        now: Date = Date()
    ) -> SharedContentPayload? {
        if let localPayload {
            guard (try? localPayload.validate(now: now)) != nil else {
                self.localPayload = nil
                offer = nil
                return nil
            }
            offer = SharedContentOffer(payload: localPayload, destination: destination)
            return localPayload
        }
        guard let payload = store?.pending(now: now) else {
            offer = nil
            return nil
        }

        let nextOffer = SharedContentOffer(payload: payload, destination: destination)
        if offer != nextOffer {
            offer = nextOffer
        }
        return payload
    }

    func updateDestination(_ destination: SharedContentDestination) {
        guard let offer, offer.destination != destination else { return }
        self.offer = SharedContentOffer(payload: offer.payload, destination: destination)
    }

    /// Returns composer text only when the currently displayed destination is
    /// still current and the reviewed envelope is still the stored envelope.
    /// A destination change updates the prompt and requires another tap.
    func confirm(
        destination: SharedContentDestination,
        now: Date = Date()
    ) -> String? {
        guard let offer else { return nil }
        guard offer.destination == destination else {
            updateDestination(destination)
            return nil
        }
        if let localPayload, localPayload.id == offer.id {
            self.localPayload = nil
            self.offer = nil
            guard (try? localPayload.validate(now: now)) != nil else { return nil }
            return localPayload.composerText
        }
        guard let payload = store?.consume(id: offer.id, now: now) else {
            _ = refresh(destination: destination, now: now)
            return nil
        }

        self.offer = nil
        return payload.composerText
    }

    func cancel(destination: SharedContentDestination, now: Date = Date()) {
        guard let offer else { return }
        if localPayload?.id == offer.id { localPayload = nil }
        store?.discard(id: offer.id)
        self.offer = nil
        // If a newer share replaced the reviewed envelope, surface it rather
        // than losing it with the older cancellation.
        _ = refresh(destination: destination, now: now)
    }

    func discardAll() {
        store?.discardAll()
        localPayload = nil
        offer = nil
    }
}
