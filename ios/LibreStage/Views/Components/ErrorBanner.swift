// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Slide-in error banner at the top of the screen.
/// Auto-dismisses after 4 seconds.
struct ErrorBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil
    var onDismiss: (() -> Void)?

    private var bannerRed: Color {
        colorScheme == .dark ? Color(red: 0.72, green: 0.12, blue: 0.12) : Color(red: 0.82, green: 0.17, blue: 0.17)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .foregroundStyle(.white)
                .font(.subheadline)
                .fontWeight(.medium)
            if let actionTitle, let onAction {
                Button(actionTitle) { onAction() }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .foregroundStyle(.red)
                    .font(.caption.bold())
            }
            Spacer()
            Button {
                onDismiss?()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(bannerRed.opacity(0.92))
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
    }
}

/// Modifier that overlays an ErrorBanner at the top of a view.
struct ErrorBannerModifier: ViewModifier {
    @Binding var error: AppError?
    var actionTitle: String?
    var onAction: (() -> Void)?

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let error {
                ErrorBanner(
                    message: error.localizedMessage,
                    actionTitle: actionTitle,
                    onAction: onAction
                ) {
                    self.error = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
                .task {
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation { self.error = nil }
                }
            }
        }
        .animation(.spring(duration: 0.3), value: error != nil)
    }
}

extension View {
    func errorBanner(
        _ error: Binding<AppError?>,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorBannerModifier(error: error, actionTitle: actionTitle, onAction: onAction))
    }
}
