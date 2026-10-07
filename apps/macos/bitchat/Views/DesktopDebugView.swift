#if os(macOS)
import AppKit
import SwiftUI

struct DesktopDebugView: View {
    @Environment(\.dismiss) private var dismiss
    @ThemedPalette private var palette
    @StateObject private var model: DesktopDebugModel
    @ObservedObject private var settings = DesktopDebugSettings.shared
    @State private var tab = Tab.overview
    @State private var showTopology = false
    @State private var copied = false
    var topologyProvider: (@MainActor () -> MeshTopologyDisplayModel)?

    private enum Tab: String, CaseIterable {
        case overview = "Overview", peers = "Peers", console = "Console"
    }

    init(model: DesktopDebugModel, topologyProvider: (@MainActor () -> MeshTopologyDisplayModel)? = nil) {
        _model = StateObject(wrappedValue: model)
        self.topologyProvider = topologyProvider
    }

    var body: some View {
        VStack(spacing: 0) {
            DesktopSheetHeader(title: "Debug settings", onClose: { dismiss() })
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(get: { settings.isEnabled }, set: { settings.setEnabled($0) })) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug mode").bitchatFont(size: 13, weight: .semibold)
                        Text("Events stay on this Mac, in memory. Turning debug mode off clears the console.")
                            .bitchatFont(size: 11).foregroundColor(palette.secondary)
                    }
                }
                .toggleStyle(IRCToggleStyle(accent: palette.accent, onLabel: "on", offLabel: "off"))
                Picker("Debug section", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(20)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch tab {
                    case .overview: overview
                    case .peers: peers
                    case .console: console
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if let date = model.refreshedAt {
                    Text("Updated \(date.formatted(date: .omitted, time: .standard))")
                        .bitchatFont(size: 10).foregroundColor(palette.secondary)
                }
                Spacer()
                Button("Refresh") { Task { await model.refresh() } }
                    .disabled(model.isRefreshing)
                Button(copied ? "Copied" : "Copy report") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.report, forType: .string)
                    copied = true
                }
                .disabled(model.isRefreshing || model.refreshedAt == nil)
            }
            .bitchatFont(size: 12)
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(palette.panel)
        }
        .foregroundColor(palette.primary)
        .themedSheetBackground()
        .frame(minWidth: 680, idealWidth: 720, minHeight: 580, idealHeight: 680)
        .task {
            // SwiftUI cancels this task when the sheet closes. No background
            // polling or retained model after dismissal.
            while !Task.isCancelled {
                await model.refresh()
                do { try await Task.sleep(nanoseconds: 2_000_000_000) }
                catch { return }
            }
        }
        .onChange(of: settings.isEnabled) { _ in
            model.debugModeChanged()
            copied = false
            Task { await model.refresh() }
        }
        .sheet(isPresented: $showTopology) {
            if let topologyProvider { MeshTopologyView(provider: topologyProvider) }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            card("Build & network") {
                Text(model.buildDescription).bitchatFont(size: 12).textSelection(.enabled)
                Text(ProcessInfo.processInfo.operatingSystemVersionString)
                    .bitchatFont(size: 11).foregroundColor(palette.secondary)
            }
            card("Bluetooth") {
                row("Central / client", model.radio.central)
                row("Peripheral / server", model.radio.peripheral)
                row("Scanning", model.radio.scanning ? "Active" : "Idle")
                row("Advertising", model.radio.advertising ? "Active" : "Idle")
                row("Outbound / inbound links", "\(model.radio.outboundLinks) / \(model.radio.inboundLinks)")
                row("Connecting / candidates", "\(model.radio.connecting) / \(model.radio.candidates)")
                if model.supportsBluetoothTools {
                    Divider().overlay(palette.divider)
                    Toggle("Continuous scanning", isOn: Binding(
                        get: { model.radio.continuousScanning },
                        set: { model.setContinuousScanning($0); Task { await model.refresh() } }
                    ))
                    .toggleStyle(IRCToggleStyle(accent: palette.accent, onLabel: "on", offLabel: "off"))
                    .disabled(!settings.isEnabled)
                    Text("Keeps discovery scanning active. Uses more power; debug mode off restores adaptive scanning.")
                        .bitchatFont(size: 11).foregroundColor(palette.secondary)
                    Button("Refresh discovery & announce") { model.refreshDiscovery(); Task { await model.refresh() } }
                        .disabled(!settings.isEnabled || model.radio.central != "powered on")
                }
            }
            card("Private delivery") {
                row("Retained private texts", "\(model.pendingMessages)")
                Text("Retries preserve the message ID and existing delivery limits.")
                    .bitchatFont(size: 11).foregroundColor(palette.secondary)
                Button("Retry pending deliveries") { model.retryPending(); Task { await model.refresh() } }
                    .disabled(!settings.isEnabled || model.pendingMessages == 0)
                row("Handed to transport", "\(model.counts[.transmitted, default: 0])")
                row("Retries", "\(model.counts[.retried, default: 0])")
                row("Delivery / read receipts", "\(model.counts[.delivered, default: 0]) / \(model.counts[.read, default: 0])")
                row("Dropped entries", "\(model.counts[.dropped, default: 0])")
                Text("Event counters cover this debug session since the console was cleared. A transport handoff is not a delivery confirmation.")
                    .bitchatFont(size: 11).foregroundColor(palette.secondary)
            }
            if topologyProvider != nil {
                Button("Open mesh topology") { showTopology = true }
            }
        }
        .bitchatFont(size: 12)
    }

    private var peers: some View {
        card("Known mesh peers · \(model.peers.count)") {
            Text("Short peer IDs only. Session status is separate from link connectivity.")
                .bitchatFont(size: 11).foregroundColor(palette.secondary)
            if model.peers.isEmpty {
                Text("No peers discovered yet. Check Bluetooth and refresh discovery.")
                    .bitchatFont(size: 12).padding(.vertical, 12)
            }
            ForEach(model.peers) { peer in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(peer.shortID).bitchatFont(size: 13, weight: .semibold)
                        Spacer()
                        Text(peer.connected ? "Connected" : "Offline")
                            .foregroundColor(peer.connected ? palette.accent : palette.secondary)
                    }
                    row("Noise session", peer.session)
                    row("Signature-verified announce", peer.verifiedAnnounce ? "Yes" : "No")
                    if model.supportsPing {
                        HStack {
                            Button("Ping peer") { model.ping(peer.id) }
                                .disabled(!settings.isEnabled || !peer.connected || model.pingResults[peer.id] == "Waiting…")
                            if let result = model.pingResults[peer.id] {
                                Text(result).foregroundColor(palette.secondary)
                            }
                        }
                    }
                }
                .bitchatFont(size: 12)
                .padding(12)
                .background(palette.background.opacity(0.5))
                .cornerRadius(6)
            }
        }
    }

    private var console: some View {
        card("Local event console") {
            HStack {
                Text("Newest first · last 300 events")
                    .bitchatFont(size: 11).foregroundColor(palette.secondary)
                Spacer()
                Button("Clear console") { model.clear(); copied = false }
                    .disabled(model.events.isEmpty && model.counts.isEmpty)
            }
            Text("Connection, handshake and text-delivery events only. Message contents, keys and raw packet data are excluded.")
                .bitchatFont(size: 11).foregroundColor(palette.secondary)
            if model.events.isEmpty {
                Text(settings.isEnabled ? "Waiting for events. Try a peer ping or send a private text." : "Turn debug mode on to capture events.")
                    .bitchatFont(size: 12).padding(.vertical, 18)
            }
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(model.events) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Text(entry.date.formatted(date: .omitted, time: .standard))
                            .foregroundColor(palette.secondary).frame(width: 76, alignment: .leading)
                        Text(entry.event.rawValue)
                        Spacer(minLength: 0)
                        if let peer = entry.peer { Text(peer).foregroundColor(palette.secondary) }
                    }
                    .bitchatFont(size: 11)
                    .textSelection(.enabled)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundColor(palette.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .bitchatFont(size: 12)
        .accessibilityElement(children: .combine)
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).bitchatFont(size: 13, weight: .semibold)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.secondary.opacity(0.10))
        .cornerRadius(8)
    }
}
#endif
