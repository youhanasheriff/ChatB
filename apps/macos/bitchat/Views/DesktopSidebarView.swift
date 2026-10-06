// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>

#if os(macOS)
import SwiftUI
import BitFoundation

/// Desktop navigation uses the same channel and conversation coordinators as
/// the mobile UI. No demo peers or transport state are inserted into the app.
struct DesktopSidebarView: View {
    @EnvironmentObject private var chrome: AppChromeModel
    @EnvironmentObject private var channels: LocationChannelsModel
    @EnvironmentObject private var peers: PeerListModel
    @EnvironmentObject private var conversations: PrivateConversationModel
    @ThemedPalette private var palette
    @Binding var showPeople: Bool
    @Binding var showVerification: Bool
    var onReviewClipboard: () -> Void
    @Binding var showTopology: Bool
    @State private var search = ""
    @FocusState private var nicknameFocused: Bool

    private var isMeshSelected: Bool {
        conversations.selectedPeerID == nil && channels.selectedChannel.isMesh
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(palette.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: "BitChat Desktop").bitchatFont(size: 15, weight: .semibold)
                    Text("desktop.sidebar.tagline").bitchatFont(size: 10)
                        .foregroundColor(palette.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 24)
            .contentShape(Rectangle())
            .onTapGesture(count: 3) { chrome.requestPanicWipe() }
            .onTapGesture(count: 1) {
                UserDefaults.standard.set("info", forKey: "appInfo.selectedPane")
                chrome.presentAppInfo()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("desktop.sidebar.about")
            .accessibilityAction {
                UserDefaults.standard.set("info", forKey: "appInfo.selectedPane")
                chrome.presentAppInfo()
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(palette.secondary)
                TextField("desktop.sidebar.search", text: $search)
                    .textFieldStyle(.plain).bitchatFont(size: 12)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("desktop.sidebar.clear_search")
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(palette.background))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.divider, lineWidth: 1))
            .padding(.horizontal, 16)
            .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    section("desktop.sidebar.channels")
                    row("#mesh", icon: "antenna.radiowaves.left.and.right", selected: isMeshSelected) {
                        openChannel(.mesh)
                    }
                    ForEach(channels.availableChannels) { channel in
                        row(channel.level.displayName, icon: "number",
                            selected: conversations.selectedPeerID == nil && channels.isSelected(channel)) {
                            openChannel(.location(channel))
                        }
                    }
                    // A teleported or bookmarked active channel may not be in
                    // the local geographic roster. It must remain reachable.
                    if case .location(let channel) = channels.selectedChannel,
                       !channels.availableChannels.contains(channel) {
                        row("#\(channel.geohash)", icon: "location",
                            selected: conversations.selectedPeerID == nil) {
                            openChannel(.location(channel))
                        }
                    }
                    row(localized("desktop.sidebar.browse_channels"), icon: "plus") {
                        chrome.isLocationChannelsSheetPresented = true
                    }

                    section("desktop.sidebar.people")
                    row(localized("desktop.sidebar.all_people"), icon: "person.2",
                        badge: peers.reachableMeshPeerCount + peers.visibleGeohashPeerCount) {
                        chrome.clearFingerprint()
                        conversations.endConversation()
                        showPeople = true
                    }
                    ForEach(peers.meshRows.filter { !$0.isMe && matches($0.displayName) && !$0.isBlocked }) { peer in
                        person(peer.displayName, peerID: peer.peerID, online: peer.isConnected || peer.isReachable,
                               unread: peer.hasUnread)
                        .contextMenu {
                            Button(peer.isFavorite ? "content.accessibility.remove_favorite" : "content.accessibility.add_favorite") {
                                peers.toggleFavorite(peerID: peer.peerID)
                            }
                            Button("desktop.sidebar.fingerprint") { chrome.showFingerprint(for: peer.peerID) }
                        }
                    }
                    ForEach(peers.geohashPeople.filter { !$0.isMe && !$0.isBlocked && matches($0.displayName) }) { person in
                        row(person.displayName, icon: "person", selected: conversations.selectedPeerID == PeerID(nostr_: person.id)) {
                            chrome.clearFingerprint()
                            peers.openGeohashDirectMessage(with: person.id)
                        }
                    }
                    ForEach(peers.recentChatRows.filter { matches($0.displayName) }) { chat in
                        person(chat.displayName, peerID: chat.peerID, online: false, unread: chat.hasUnread)
                    }
                    if peers.meshRows.filter({ !$0.isMe && !$0.isBlocked }).isEmpty &&
                       peers.geohashPeople.filter({ !$0.isMe && !$0.isBlocked }).isEmpty && peers.recentChatRows.isEmpty {
                        Text("desktop.sidebar.no_people")
                            .bitchatFont(size: 11).foregroundColor(palette.secondary)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                    if !peers.groupRows.isEmpty {
                        section("desktop.sidebar.groups")
                        ForEach(peers.groupRows.filter { matches($0.name) }) { group in
                            row(group.name, icon: "person.3", selected: conversations.selectedPeerID == group.peerID,
                                unread: group.hasUnread) {
                                openConversation(group.peerID)
                            }
                        }
                    }

                    section("desktop.sidebar.tools")
                    row(localized("desktop.sidebar.review_clipboard"), icon: "doc.on.clipboard", action: onReviewClipboard)
                    row(localized("desktop.sidebar.notices"), icon: "pin") { chrome.presentNotices() }
                    row(localized("desktop.sidebar.verify"), icon: "qrcode") { showVerification = true }
                    row(localized("desktop.sidebar.topology"), icon: "point.3.connected.trianglepath.dotted") {
                        showTopology = true
                    }
                    row(localized("desktop.sidebar.settings"), icon: "gearshape") {
                        // A settings entry always lands on Settings, even if
                        // the last visit was to the Info tab.
                        UserDefaults.standard.set("settings", forKey: "appInfo.selectedPane")
                        chrome.presentAppInfo()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
            Rectangle().fill(palette.divider).frame(height: 1)
            identityFooter
        }
        .foregroundColor(palette.primary)
        .background(palette.panel)
    }

    private var identityFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "at").foregroundColor(palette.accent)
                TextField("content.input.nickname_placeholder", text: Binding(
                    get: { chrome.nickname }, set: { chrome.setNickname($0) }
                ))
                .textFieldStyle(.plain).bitchatFont(size: 13, weight: .medium)
                .focused($nicknameFocused).autocorrectionDisabled()
                .onSubmit { chrome.validateAndSaveNickname() }
                .onChange(of: nicknameFocused) { focused in
                    if !focused { chrome.validateAndSaveNickname() }
                }
                .accessibilityLabel("desktop.sidebar.nickname")
            }
            HStack(spacing: 7) {
                Circle().fill(chrome.bluetoothState == .poweredOn ? palette.accent : palette.secondary)
                    .frame(width: 6, height: 6)
                Text(chrome.bluetoothState == .poweredOn ? "desktop.sidebar.bluetooth_on" : "desktop.sidebar.bluetooth_unavailable")
                    .bitchatFont(size: 10)
            }
            .foregroundColor(palette.secondary)
        }
        .padding(20)
    }

    private func section(_ title: LocalizedStringKey) -> some View {
        Text(title).bitchatFont(size: 10, weight: .semibold)
            .foregroundColor(palette.secondary)
            .padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 6)
    }

    private func person(_ name: String, peerID: PeerID, online: Bool, unread: Bool) -> some View {
        row(name, icon: online ? "circle.fill" : "circle", selected: conversations.selectedPeerID == peerID,
            unread: unread) { openConversation(peerID) }
    }

    private func row(_ title: String, icon: String, selected: Bool = false,
                     badge: Int? = nil, unread: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: icon.contains("circle") ? 7 : 13))
                    .frame(width: 16).foregroundColor(selected ? palette.accent : palette.secondary)
                Text(verbatim: title).bitchatFont(size: 12, weight: selected || unread ? .semibold : .regular)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let badge, badge > 0 {
                    Text(verbatim: "\(badge)").bitchatFont(size: 10).foregroundColor(palette.secondary)
                }
                if unread { Circle().fill(palette.accent).frame(width: 6, height: 6) }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 7).fill(selected ? palette.selection : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func openConversation(_ peerID: PeerID) {
        chrome.clearFingerprint()
        peers.startConversation(with: peerID)
    }

    private func openChannel(_ channel: ChannelID) {
        chrome.clearFingerprint()
        conversations.endConversation()
        channels.select(channel)
    }

    private func matches(_ name: String) -> Bool {
        search.isEmpty || name.localizedCaseInsensitiveContains(search)
    }

    private func localized(_ key: String.LocalizationValue) -> String { String(localized: key) }
}
#endif
