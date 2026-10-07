//
// ContentView.swift
// bitchat
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import BitFoundation

struct ContentRootModalPresentationState {
    var isPeopleSheetPresented = false
    var isAppInfoPresented = false
    var isFingerprintPresented = false
    var isLocationChannelsSheetPresented = false
    var isNoticesSheetPresented = false
    var isImagePreviewPresented = false
    var isVerificationSheetPresented = false
    var isVoiceAlertPresented = false
    var isScreenshotPrivacyAlertPresented = false
    var isMediaPickerPresented = false
    var isPanicConfirmationPresented = false

    var hasPresentation: Bool {
        isPeopleSheetPresented
            || isAppInfoPresented
            || isFingerprintPresented
            || isLocationChannelsSheetPresented
            || isNoticesSheetPresented
            || isImagePreviewPresented
            || isVerificationSheetPresented
            || isVoiceAlertPresented
            || isScreenshotPrivacyAlertPresented
            || isMediaPickerPresented
            || isPanicConfirmationPresented
    }
}

extension ContentRootModalPresentationState {
    @MainActor
    init(
        appChromeModel: AppChromeModel,
        isPeopleSheetPresented: Bool = false,
        isImagePreviewPresented: Bool = false,
        isVerificationSheetPresented: Bool = false,
        isVoiceAlertPresented: Bool = false,
        isMediaPickerPresented: Bool = false
    ) {
        self.init(
            isPeopleSheetPresented: isPeopleSheetPresented,
            isAppInfoPresented: appChromeModel.isAppInfoPresented,
            isFingerprintPresented:
                appChromeModel.showingFingerprintFor != nil,
            isLocationChannelsSheetPresented:
                appChromeModel.isLocationChannelsSheetPresented,
            isNoticesSheetPresented:
                appChromeModel.isNoticesSheetPresented,
            isImagePreviewPresented: isImagePreviewPresented,
            isVerificationSheetPresented: isVerificationSheetPresented,
            isVoiceAlertPresented: isVoiceAlertPresented,
            isScreenshotPrivacyAlertPresented:
                appChromeModel.showScreenshotPrivacyWarning,
            isMediaPickerPresented: isMediaPickerPresented,
            isPanicConfirmationPresented: appChromeModel.showPanicConfirmation
        )
    }
}

/// On macOS 14+, disables the default system focus ring on TextFields.
/// On earlier macOS versions and on iOS this is a no-op.
struct FocusEffectDisabledModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            content.focusEffectDisabled()
        } else {
            content
        }
        #else
        content
        #endif
    }
}

struct ContentView: View {
    @EnvironmentObject private var appChromeModel: AppChromeModel
    @EnvironmentObject private var privateConversationModel: PrivateConversationModel
    @EnvironmentObject private var verificationModel: VerificationModel
    @EnvironmentObject private var conversationUIModel: ConversationUIModel
    @EnvironmentObject private var locationChannelsModel: LocationChannelsModel
    @EnvironmentObject private var sharedContentImportModel: SharedContentImportModel
    @EnvironmentObject private var peerListModel: PeerListModel
    @EnvironmentObject private var publicChatModel: PublicChatModel
    @EnvironmentObject private var privateInboxModel: PrivateInboxModel

    @StateObject private var voiceRecordingVM = VoiceRecordingViewModel()
    @State private var messageText = ""
    /// Conversation the current `messageText` belongs to, so a channel switch
    /// can save under the previous key before loading the next draft.
    @State private var activeDraftKey: ComposerDraftStore.Key = .mesh
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.appTheme) private var appTheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSidebar = false
    #if os(macOS)
    @AppStorage("desktop.sidebarVisible") private var desktopSidebarVisible = true
    @State private var clipboardImportError: String?
    @State private var showDesktopTopology = false
    #endif
    @State private var selectedMessageSender: String?
    @State private var selectedMessageSenderID: PeerID?
    @FocusState private var isNicknameFieldFocused: Bool
    @State private var isAtBottomPublic = true
    @State private var isAtBottomPrivate = true
    @State private var autocompleteDebounceTimer: Timer?
    @State private var showVerifySheet = false
    @State private var imagePreviewURL: URL?
    #if os(iOS)
    @State private var showImagePicker = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .camera
    #else
    @State private var showMacImagePicker = false
    #endif
    @ScaledMetric(relativeTo: .body) private var headerHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .subheadline) private var headerPeerIconSize: CGFloat = 11
    @ScaledMetric(relativeTo: .subheadline) private var headerPeerCountFontSize: CGFloat = 12
    @State private var windowCountPublic: Int = 300
    @State private var windowCountPrivate: [PeerID: Int] = [:]

    @ThemedPalette private var palette

    private var selectedPrivatePeerID: PeerID? {
        privateConversationModel.selectedPeerID
    }

    private var sharedContentDestination: SharedContentDestination {
        SharedContentDestination.resolve(
            selectedPrivatePeerID: selectedPrivatePeerID,
            privateDisplayName: privateConversationModel.selectedHeaderState?.displayName,
            activeChannel: locationChannelsModel.selectedChannel
        )
    }

    private var usesGlassLayout: Bool { appTheme.usesGlassChrome }

    private var isPeopleSheetPresented: Bool {
        #if os(macOS)
        showSidebar
        #else
        showSidebar || selectedPrivatePeerID != nil
        #endif
    }

    private func rootModalPresentationState(
        includingVoiceAlert: Bool
    ) -> ContentRootModalPresentationState {
        #if os(iOS)
        let isMediaPickerPresented = showImagePicker
        #else
        let isMediaPickerPresented = showMacImagePicker
        #endif

        return ContentRootModalPresentationState(
            appChromeModel: appChromeModel,
            // The private container owns recording/Bluetooth alerts even
            // when it is an inline desktop pane rather than a sheet.
            isPeopleSheetPresented: showSidebar || selectedPrivatePeerID != nil,
            isImagePreviewPresented: imagePreviewURL != nil,
            isVerificationSheetPresented: showVerifySheet,
            isVoiceAlertPresented: includingVoiceAlert && voiceRecordingVM.showAlert,
            isMediaPickerPresented: isMediaPickerPresented
        )
    }

    private var hasDesktopToolPresentation: Bool {
        #if os(macOS)
        clipboardImportError != nil || showDesktopTopology
        #else
        false
        #endif
    }

    private var hasRootModalPresentation: Bool {
        hasDesktopToolPresentation || sharedContentImportModel.offer != nil || rootModalPresentationState(includingVoiceAlert: true).hasPresentation
    }

    /// The voice alert cannot defer to itself: its own binding must keep
    /// reporting `true` while it is the presented modal.
    private var hasRootModalPresentationBesidesVoiceAlert: Bool {
        hasDesktopToolPresentation || sharedContentImportModel.offer != nil || rootModalPresentationState(includingVoiceAlert: false).hasPresentation
    }

    private var rootBluetoothAlertBinding: Binding<Bool> {
        Binding(
            get: {
                scenePhase == .active
                    && appChromeModel.showBluetoothAlert
                    && !hasRootModalPresentation
            },
            set: { isPresented in
                guard !isPresented,
                      scenePhase == .active,
                      !hasRootModalPresentation else {
                    return
                }
                // SwiftUI can invoke this setter inside a view update (the
                // alert dismisses when a scenePhase change re-evaluates the
                // `get`); publishing synchronously there is undefined
                // behavior, so defer the write one hop.
                Task { @MainActor in
                    appChromeModel.showBluetoothAlert = false
                }
            }
        )
    }

    /// Voice recording errors can surface while the people/DM sheet is up
    /// (recording happens inside the sheet). Presenting the root alert then
    /// would force-dismiss the sheet, so the root copy defers to any other
    /// root modal; the sheet presents its own copy. Mirrors the Bluetooth
    /// alert treatment above.
    private var rootVoiceAlertBinding: Binding<Bool> {
        Binding(
            get: {
                scenePhase == .active
                    && voiceRecordingVM.showAlert
                    && !hasRootModalPresentationBesidesVoiceAlert
            },
            set: { isPresented in
                guard !isPresented,
                      scenePhase == .active,
                      !hasRootModalPresentationBesidesVoiceAlert else {
                    return
                }
                // Same deferral as the Bluetooth alert above: the setter can
                // run inside a view update when the sheet state changes.
                Task { @MainActor in
                    voiceRecordingVM.showAlert = false
                }
            }
        )
    }

    var body: some View {
        mainContent
            .onAppear {
                conversationUIModel.setCurrentColorScheme(colorScheme)
                conversationUIModel.setCurrentTheme(appTheme)
                voiceRecordingVM.sessionProvider = { [weak conversationUIModel] in
                    conversationUIModel?.makeVoiceCaptureSession() ?? VoiceNoteCaptureSession()
                }
                appChromeModel.setPanicPreparation { [weak voiceRecordingVM] in
                    voiceRecordingVM?.panicWipe()
                    // Drop in-memory composer text before ChatViewModel resets
                    // persisted drafts — otherwise the next inactive/background
                    // transition would write the pre-wipe draft back.
                    messageText = ""
                    activeDraftKey = .mesh
                }
                #if os(macOS)
                DispatchQueue.main.async {
                    isNicknameFieldFocused = false
                    isTextFieldFocused = true
                }
                #endif
                sharedContentImportModel.updateDestination(sharedContentDestination)
                activeDraftKey = ComposerDraftStore.Key.from(
                    peerID: selectedPrivatePeerID,
                    fingerprint: selectedPrivatePeerID.flatMap { conversationUIModel.getFingerprint(for: $0) },
                    channel: locationChannelsModel.selectedChannel
                )
                messageText = ComposerDraftStore.load(activeDraftKey)
            }
            .onChange(of: colorScheme) { newValue in
                conversationUIModel.setCurrentColorScheme(newValue)
            }
            .onChange(of: appTheme) { newValue in
                conversationUIModel.setCurrentTheme(newValue)
            }
        .background(ThemedRootBackground())
        .foregroundColor(palette.primary)
        .tint(palette.accent)
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 580)
        #endif
        .onChange(of: selectedPrivatePeerID) { newValue in
            #if os(iOS)
            if newValue != nil { showSidebar = true }
            #else
            // Selecting a roster row closes the roster sheet and opens inline.
            if newValue != nil { showSidebar = false }
            #endif
            sharedContentImportModel.updateDestination(sharedContentDestination)
            switchComposerDraft(to: ComposerDraftStore.Key.from(
                peerID: newValue,
                fingerprint: newValue.flatMap { conversationUIModel.getFingerprint(for: $0) },
                channel: locationChannelsModel.selectedChannel
            ))
        }
        .onChange(of: locationChannelsModel.selectedChannel) { newChannel in
            sharedContentImportModel.updateDestination(sharedContentDestination)
            // Private drafts are keyed by peer; only public channel switches
            // need a draft swap while no DM is open.
            if selectedPrivatePeerID == nil {
                switchComposerDraft(to: ComposerDraftStore.Key.from(
                    peerID: nil,
                    fingerprint: nil,
                    channel: newChannel
                ))
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                // Always save, including empty — clearing the composer must
                // remove the in-memory draft so it does not resurrect on the
                // next switch back into this conversation.
                ComposerDraftStore.save(messageText, for: activeDraftKey)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { isPeopleSheetPresented },
                set: { isPresented in
                    if !isPresented {
                        showSidebar = false
                        // Scene/background and alert-presentation
                        // reconciliation (Bluetooth-off, recording errors)
                        // are not user requests to leave the conversation.
                        // Keep the selected DM so the sheet remains live
                        // when the app returns from Settings.
                        #if os(iOS)
                        if scenePhase == .active,
                           !appChromeModel.showBluetoothAlert,
                           !voiceRecordingVM.showAlert {
                            privateConversationModel.endConversation()
                        }
                        #endif
                    }
                }
            )
        ) {
            #if os(iOS)
            ContentPeopleSheetView(
                showSidebar: $showSidebar,
                messageText: $messageText,
                selectedMessageSender: $selectedMessageSender,
                selectedMessageSenderID: $selectedMessageSenderID,
                imagePreviewURL: $imagePreviewURL,
                windowCountPublic: $windowCountPublic,
                windowCountPrivate: $windowCountPrivate,
                isAtBottomPrivate: $isAtBottomPrivate,
                isTextFieldFocused: $isTextFieldFocused,
                voiceRecordingVM: voiceRecordingVM,
                autocompleteDebounceTimer: $autocompleteDebounceTimer,
                headerHeight: headerHeight,
                onSendMessage: sendMessage,
                showImagePicker: $showImagePicker,
                imagePickerSourceType: $imagePickerSourceType
            )
            // Sheets + NavigationStack can drop inherited EnvironmentObjects on
            // some iOS versions (#1558). Re-inject every model the sheet tree
            // reads so ContentPeopleListView / MessageListView never crash.
            .environmentObject(appChromeModel)
            .environmentObject(privateConversationModel)
            .environmentObject(verificationModel)
            .environmentObject(conversationUIModel)
            .environmentObject(locationChannelsModel)
            .environmentObject(peerListModel)
            .environmentObject(publicChatModel)
            .environmentObject(privateInboxModel)
            .environmentObject(sharedContentImportModel)
            #else
            ContentPeopleSheetView(
                showSidebar: $showSidebar,
                messageText: $messageText,
                selectedMessageSender: $selectedMessageSender,
                selectedMessageSenderID: $selectedMessageSenderID,
                imagePreviewURL: $imagePreviewURL,
                windowCountPublic: $windowCountPublic,
                windowCountPrivate: $windowCountPrivate,
                isAtBottomPrivate: $isAtBottomPrivate,
                isTextFieldFocused: $isTextFieldFocused,
                voiceRecordingVM: voiceRecordingVM,
                autocompleteDebounceTimer: $autocompleteDebounceTimer,
                headerHeight: headerHeight,
                onSendMessage: sendMessage,
                showMacImagePicker: $showMacImagePicker
            )
            .environmentObject(appChromeModel)
            .environmentObject(privateConversationModel)
            .environmentObject(verificationModel)
            .environmentObject(conversationUIModel)
            .environmentObject(locationChannelsModel)
            .environmentObject(peerListModel)
            .environmentObject(publicChatModel)
            .environmentObject(privateInboxModel)
            .environmentObject(sharedContentImportModel)
            #endif
        }
        .sheet(isPresented: $appChromeModel.isLocationChannelsSheetPresented) {
            LocationChannelsSheet(isPresented: $appChromeModel.isLocationChannelsSheetPresented)
                .environmentObject(locationChannelsModel)
                .environmentObject(peerListModel)
        }
        .sheet(
            isPresented: $appChromeModel.isNoticesSheetPresented,
            onDismiss: { appChromeModel.noticesSheetPrefersGeoTab = false }
        ) {
            NoticesView(
                senderNickname: appChromeModel.nickname,
                board: appChromeModel.boardManager,
                initialTab: appChromeModel.noticesSheetPrefersGeoTab ? .geo : (locationChannelsModel.selectedChannel.isMesh ? .mesh : .geo)
            )
            .environmentObject(locationChannelsModel)
        }
        .alert("content.alert.screenshot.title", isPresented: $appChromeModel.showScreenshotPrivacyWarning) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text("content.alert.screenshot.message")
        }
        .sheet(isPresented: $showVerifySheet) {
            VerificationSheetView(isPresented: $showVerifySheet)
                .environmentObject(verificationModel)
        }
        .sheet(isPresented: $appChromeModel.isAppInfoPresented) {
            AppInfoView(
                topologyProvider: { appChromeModel.meshTopologyDisplayModel() },
                onPanicWipe: { appChromeModel.panicClearAllData() },
                debugModelProvider: { appChromeModel.makeDesktopDebugModel() }
            )
            .environmentObject(locationChannelsModel)
        }
        .sheet(isPresented: Binding(
            get: { appChromeModel.showingFingerprintFor != nil && !showSidebar && selectedPrivatePeerID == nil },
            set: { _ in appChromeModel.clearFingerprint() }
        )) {
            if let peerID = appChromeModel.showingFingerprintFor {
                FingerprintView(peerID: peerID)
                    .environmentObject(verificationModel)
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: Binding(
            get: { showImagePicker && !showSidebar && selectedPrivatePeerID == nil },
            set: { newValue in
                if !newValue {
                    showImagePicker = false
                }
            }
        )) {
            ImagePickerView(sourceType: imagePickerSourceType) { image in
                showImagePicker = false
                conversationUIModel.processSelectedImage(image)
            }
            .ignoresSafeArea()
        }
        #endif
        #if os(macOS)
        .sheet(isPresented: Binding(
            get: { showMacImagePicker && !showSidebar && selectedPrivatePeerID == nil },
            set: { newValue in
                if !newValue {
                    showMacImagePicker = false
                }
            }
        )) {
            MacImagePickerView { url in
                showMacImagePicker = false
                conversationUIModel.processSelectedImage(from: url)
            }
        }
        #endif
        .sheet(isPresented: Binding(
            get: { imagePreviewURL != nil },
            set: { presenting in
                if !presenting {
                    imagePreviewURL = nil
                }
            }
        )) {
            if let url = imagePreviewURL {
                ImagePreviewView(url: url)
            }
        }
        .alert(Text(String(localized: "voice.error.title", defaultValue: "recording error", comment: "Title of the voice recording error alert")), isPresented: rootVoiceAlertBinding, actions: {
            Button("common.ok", role: .cancel) {}
            if voiceRecordingVM.state == .permissionDenied {
                Button("location_channels.action.open_settings") {
                    SystemSettings.microphone.open()
                }
            }
        }, message: {
            Text(voiceRecordingVM.state.alertMessage)
        })
        .alert("content.alert.bluetooth_required.title", isPresented: rootBluetoothAlertBinding) {
            Button("content.alert.bluetooth_required.settings") {
                // Powered-off needs the radio controls, not the privacy pane.
                (appChromeModel.bluetoothState == .poweredOff
                    ? SystemSettings.bluetoothPower
                    : SystemSettings.bluetooth).open()
            }
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(appChromeModel.bluetoothAlertMessage)
        }
        #if os(macOS)
        .sheet(isPresented: $showDesktopTopology) {
            MeshTopologyView(provider: { appChromeModel.meshTopologyDisplayModel() })
        }
        .alert("desktop.clipboard_error.title", isPresented: Binding(
            get: { clipboardImportError != nil },
            set: { if !$0 { clipboardImportError = nil } }
        )) {
            Button("common.ok", role: .cancel) { clipboardImportError = nil }
        } message: {
            Text(verbatim: clipboardImportError ?? "")
        }
        #endif
        .alert(
            String(localized: "share_import.review.title", comment: "Title for reviewing content received from the share extension"),
            isPresented: Binding(
                get: { sharedContentImportModel.offer != nil },
                set: { _ in }
            ),
            presenting: sharedContentImportModel.offer
        ) { _ in
            Button("common.cancel", role: .cancel) {
                sharedContentImportModel.cancel(destination: sharedContentDestination)
            }
            Button("share_import.review.use_in_composer") {
                guard let importedText = sharedContentImportModel.confirm(
                    destination: sharedContentDestination
                ) else { return }
                // Replacing is deliberate and called out in the prompt. It
                // avoids combining a stale draft from another conversation
                // with newly shared content.
                messageText = importedText
                isTextFieldFocused = true
            }
        } message: { offer in
            let format = String(
                localized: "share_import.review.message",
                comment: "Explains that shared content will replace the named destination's composer and will not be sent automatically"
            )
            Text(String(format: format, offer.destination.displayName) + "\n\n" + offer.payload.preview)
        }
        // The desktop sidebar remains usable during a private conversation;
        // host confirmation at the root so changing headers cannot remove it.
        .confirmationDialog(
            Text(
                String(localized: "app_info.settings.danger.panic_confirm_title", defaultValue: "wipe all data?", comment: "Title of the confirmation dialog before a panic wipe")
            ),
            isPresented: $appChromeModel.showPanicConfirmation,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                appChromeModel.panicClearAllData()
            } label: {
                Text(
                    String(localized: "app_info.settings.danger.panic_confirm_action", defaultValue: "wipe everything", comment: "Destructive confirmation button that performs the panic wipe")
                )
            }
            Button("common.cancel", role: .cancel) {}
        }
        .onDisappear {
            autocompleteDebounceTimer?.invalidate()
            appChromeModel.setPanicPreparation(nil)
        }
    }

    /// Matrix: classic opaque bars with dividers. Glass: full-bleed message
    /// list scrolling underneath floating chrome panels (safe-area insets),
    /// so the translucency gains usable space instead of losing it.
    @ViewBuilder
    private var mainContent: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            if desktopSidebarVisible {
                DesktopSidebarView(showPeople: $showSidebar, showVerification: $showVerifySheet, onReviewClipboard: reviewClipboard, showTopology: $showDesktopTopology)
                    .frame(width: 240)
                Rectangle().fill(palette.divider).frame(width: 1)
            }
            VStack(spacing: 0) {
                HStack {
                    Button {
                        desktopSidebarVisible.toggle()
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .buttonStyle(.plain)
                    .help("Toggle sidebar (⌘\\)")
                    .accessibilityLabel("Toggle sidebar")
                    .keyboardShortcut("\\", modifiers: .command)
                    Spacer()
                }
                .foregroundColor(palette.secondary)
                .padding(.horizontal, 20)
                .frame(height: 28)
                if selectedPrivatePeerID != nil {
                    desktopPrivatePane
                } else {
                    publicChatContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #else
        publicChatContent
        #endif
    }

    #if os(macOS)
    private var desktopPrivatePane: some View {
        ContentPeopleSheetView(
            showSidebar: $showSidebar, messageText: $messageText,
            selectedMessageSender: $selectedMessageSender,
            selectedMessageSenderID: $selectedMessageSenderID,
            imagePreviewURL: $imagePreviewURL, windowCountPublic: $windowCountPublic,
            windowCountPrivate: $windowCountPrivate, isAtBottomPrivate: $isAtBottomPrivate,
            isTextFieldFocused: $isTextFieldFocused, voiceRecordingVM: voiceRecordingVM,
            autocompleteDebounceTimer: $autocompleteDebounceTimer,
            headerHeight: 56, onSendMessage: sendMessage,
            hasExternalRootPresentation: hasDesktopToolPresentation,
            showMacImagePicker: $showMacImagePicker
        )
        // All navigation, consent, encryption and media behavior stays in the
        // existing conversation container, now hosted beside the sidebar.
    }
    #endif

    @ViewBuilder
    private var publicChatContent: some View {
        if usesGlassLayout {
            publicMessageList
                .safeAreaInset(edge: .top, spacing: 0) {
                    headerView
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if selectedPrivatePeerID == nil {
                        composerView
                    }
                }
        } else {
            VStack(spacing: 0) {
                headerView

                Divider()

                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        publicMessageList
                            .background(palette.background)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }

                Divider()

                if selectedPrivatePeerID == nil {
                    composerView
                }
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 0) {
            ContentHeaderView(
                showSidebar: $showSidebar,
                showVerifySheet: $showVerifySheet,
                isNicknameFieldFocused: $isNicknameFieldFocused,
                headerHeight: headerHeight,
                headerPeerIconSize: headerPeerIconSize,
                headerPeerCountFontSize: headerPeerCountFontSize
            )

            // Failed-wipe outranks connectivity: "your data may still be
            // here" matters more than "the radio is off".
            if appChromeModel.panicWipeBlocked {
                PanicWipeBlockedBanner()
            }

            if let issue = ConnectivityIssue.resolve(
                bluetoothState: appChromeModel.bluetoothState,
                torBlocked: appChromeModel.torBlocked
            ) {
                ConnectivityStatusBanner(issue: issue)
            }
        }

    }

    private var publicMessageList: some View {
        MessageListView(
            privatePeer: nil,
            isAtBottom: $isAtBottomPublic,
            messageText: $messageText,
            selectedMessageSender: $selectedMessageSender,
            selectedMessageSenderID: $selectedMessageSenderID,
            imagePreviewURL: $imagePreviewURL,
            windowCountPublic: $windowCountPublic,
            windowCountPrivate: $windowCountPrivate,
            showSidebar: $showSidebar,
            isTextFieldFocused: $isTextFieldFocused
        )
    }

    private var composerView: some View {
        #if os(iOS)
        ContentComposerView(
            messageText: $messageText,
            isTextFieldFocused: $isTextFieldFocused,
            voiceRecordingVM: voiceRecordingVM,
            autocompleteDebounceTimer: $autocompleteDebounceTimer,
            onSendMessage: sendMessage,
            showImagePicker: $showImagePicker,
            imagePickerSourceType: $imagePickerSourceType
        )
        #else
        ContentComposerView(
            messageText: $messageText,
            isTextFieldFocused: $isTextFieldFocused,
            voiceRecordingVM: voiceRecordingVM,
            autocompleteDebounceTimer: $autocompleteDebounceTimer,
            onSendMessage: sendMessage,
            showMacImagePicker: $showMacImagePicker
        )
        #endif
    }

    #if os(macOS)
    private func reviewClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.trimmed.isEmpty else {
            clipboardImportError = String(localized: "desktop.clipboard_error.empty")
            return
        }
        do {
            try sharedContentImportModel.reviewLocal(.text(text), destination: sharedContentDestination)
        } catch {
            clipboardImportError = String(localized: "desktop.clipboard_error.invalid")
        }
    }
    #endif

    private func sendMessage() {
        guard let trimmed = messageText.trimmedOrNilIfEmpty else { return }

        messageText = ""
        ComposerDraftStore.save("", for: activeDraftKey)

        DispatchQueue.main.async {
            self.conversationUIModel.sendMessage(trimmed)
        }
    }

    private func switchComposerDraft(to newKey: ComposerDraftStore.Key) {
        guard newKey != activeDraftKey else { return }
        ComposerDraftStore.save(messageText, for: activeDraftKey)
        activeDraftKey = newKey
        messageText = ComposerDraftStore.load(newKey)
    }
}
