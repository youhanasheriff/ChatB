import SwiftUI

/// Message layout is independent of the app's color and font theme.
enum ChatMessageStyle: String, CaseIterable, Identifiable {
    case bubble
    case terminal

    static let storageKey = "chat.messageStyle"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bubble:
            return String(localized: "app_info.chat_style.bubble", defaultValue: "Bubble", comment: "Message layout option showing incoming and outgoing chat bubbles")
        case .terminal:
            return String(localized: "app_info.chat_style.terminal", defaultValue: "Terminal", comment: "Message layout option showing a compact chat log")
        }
    }
}
