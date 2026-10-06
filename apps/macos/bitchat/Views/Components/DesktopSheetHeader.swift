// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
#if os(macOS)
import SwiftUI

/// Shared sheet chrome keeps tools, identity and settings consistent with
/// the desktop conversation shell without replacing native system dialogs.
struct DesktopSheetHeader: View {
    let title: LocalizedStringKey
    var onRefresh: (() -> Void)? = nil
    let onClose: () -> Void
    @ThemedPalette private var palette

    var body: some View {
        HStack(spacing: 12) {
            Text(title).bitchatFont(size: 16, weight: .semibold)
            Spacer()
            if let onRefresh {
                Button(action: onRefresh) { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).accessibilityLabel("topology.refresh")
            }
            SheetCloseButton(action: onClose)
        }
        .foregroundColor(palette.primary)
        .padding(.horizontal, 20).padding(.vertical, 16)
        .background(palette.panel)
        .background(palette.background)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.divider).frame(height: 1) }
    }
}
#endif
