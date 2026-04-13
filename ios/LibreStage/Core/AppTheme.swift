// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

enum AppTheme {
    static func shellGradient(for colorScheme: ColorScheme) -> LinearGradient {
        switch colorScheme {
        case .dark:
            return LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.10, blue: 0.22),
                    Color(red: 0.14, green: 0.09, blue: 0.28),
                    Color(red: 0.08, green: 0.24, blue: 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [
                    Color(red: 0.88, green: 0.94, blue: 1.00),
                    Color(red: 0.92, green: 0.90, blue: 0.99),
                    Color(red: 0.89, green: 0.96, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static func onShellPrimary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : Color(red: 0.10, green: 0.13, blue: 0.24)
    }

    static func onShellSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.8) : Color(red: 0.20, green: 0.24, blue: 0.36)
    }

    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color(.systemBackground).opacity(0.56)
    }

    static func cardBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.06)
    }

    static func rowBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color(.secondarySystemBackground).opacity(0.48)
    }

    static func tileBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color(.tertiarySystemBackground).opacity(0.68)
    }

    static func tileBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.06)
    }

    static func cardShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.10)
    }
}

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.ultraThinMaterial)
            .background(AppTheme.cardBackground(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.cardBorder(for: colorScheme), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppTheme.cardShadow(for: colorScheme), radius: 10, x: 0, y: 6)
    }
}

extension View {
    func glassCardStyle() -> some View {
        modifier(GlassCardModifier())
    }

    func appShellBackground() -> some View {
        modifier(AppShellBackgroundModifier())
    }

    func softCardContainer() -> some View {
        modifier(SoftCardContainerModifier())
    }

    func headerBodyBlend() -> some View {
        modifier(HeaderBodyBlendModifier())
    }
}

private struct SoftCardContainerModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .listRowBackground(AppTheme.rowBackground(for: colorScheme))
            .scrollContentBackground(.hidden)
            .background(.clear)
    }
}

private struct AppShellBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        ZStack {
            AppTheme.shellGradient(for: colorScheme).ignoresSafeArea()
            content
                .scrollContentBackground(.hidden)
                .background(.clear)
        }
    }
}

private struct HeaderBodyBlendModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(.hidden, for: .navigationBar)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.025) : Color.black.opacity(0.02),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
                .mask(
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
            }
    }
}
