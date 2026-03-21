// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Slide-in error banner at the top of the screen.
/// Auto-dismisses after 4 seconds.
struct ErrorBanner: View {
    let message: String
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .foregroundStyle(.white)
                .font(.subheadline)
            if let actionTitle, let onAction {
                Button(actionTitle) { onAction() }
                    .buttonStyle(.bordered)
                    .tint(.white)
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
        .background(Color.red.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .shadow(radius: 6)
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

