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

    static func dashboardRowBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? rowBackground(for: colorScheme) : .clear
    }

    static func tileBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color(.tertiarySystemBackground).opacity(0.68)
    }

    static func dashboardTileBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? tileBackground(for: colorScheme) : .clear
    }

    static func tileBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.06)
    }

    // Inputs should blend into the glass/list surface in light mode.
    static func inputFieldBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? tileBackground(for: colorScheme) : .clear.opacity(0.10)
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

    func formFieldSurface() -> some View {
        modifier(FormFieldSurfaceModifier())
    }

    func listAlignedFieldSurface() -> some View {
        modifier(ListAlignedFieldSurfaceModifier())
    }

    // Standard style for "create/add" modal forms.
    func addModalFormStyle() -> some View {
        modifier(AddModalFormModifier())
    }

    func addModalSectionStyle() -> some View {
        modifier(AddModalSectionModifier())
    }

    func addModalFieldStyle() -> some View {
        modifier(AddModalFieldModifier())
    }

    // Glass-like active state for compact tab buttons.
    func dashboardTabGlassStyle(isActive: Bool) -> some View {
        modifier(DashboardTabGlassModifier(isActive: isActive))
    }
}

private struct DashboardTabGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let isActive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        return content
            .background {
                if isActive {
                    shape
                        .fill(.regularMaterial)
                        .overlay {
                            // Top highlight to emulate liquid glass sheen.
                            shape
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(colorScheme == .dark ? 0.24 : 0.38),
                                            Color.white.opacity(0.02)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .overlay {
                            shape
                                .fill(colorScheme == .dark ? Color.accentColor.opacity(0.15) : Color.accentColor.opacity(0.08))
                        }
                } else {
                    Color.clear
                }
            }
            .overlay {
                if isActive {
                    shape
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.30) : Color.white.opacity(0.78),
                            lineWidth: 1
                        )
                        .overlay {
                            shape
                                .stroke(
                                    colorScheme == .dark ? Color.black.opacity(0.18) : Color.accentColor.opacity(0.26),
                                    lineWidth: 0.6
                                )
                        }
                }
            }
            .shadow(
                color: isActive
                ? (colorScheme == .dark ? Color.black.opacity(0.26) : Color.black.opacity(0.12))
                : .clear,
                radius: isActive ? 6 : 0,
                x: 0,
                y: isActive ? 2 : 0
            )
    }
}

private struct AddModalFormModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .softCardContainer()
            .textFieldStyle(.plain)
            .appShellBackground()
    }
}

private struct AddModalSectionModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .listRowBackground(AppTheme.rowBackground(for: colorScheme))
    }
}

private struct AddModalFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listAlignedFieldSurface()
    }
}

private struct SoftCardContainerModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .listRowBackground(AppTheme.rowBackground(for: colorScheme))
            .textFieldStyle(SoftCardTextFieldStyle())
            .labeledContentStyle(SoftCardLabeledContentStyle())
            .scrollContentBackground(.hidden)
            .background(.clear)
    }
}

private struct SoftCardTextFieldStyle: TextFieldStyle {
    @Environment(\.colorScheme) private var colorScheme

    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.inputFieldBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.tileBorder(for: colorScheme), lineWidth: 1)
            )
    }
}

private struct SoftCardLabeledContentStyle: LabeledContentStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            configuration.label
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            configuration.content
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.inputFieldBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.tileBorder(for: colorScheme), lineWidth: 1)
        )
    }
}

private struct FormFieldSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.inputFieldBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.tileBorder(for: colorScheme), lineWidth: 1)
            )
    }
}

private struct ListAlignedFieldSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        // Keep controls aligned with list rows while preserving transparent surfaces.
        content
            .padding(.vertical, 4)
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
    @Environment(\.displayScale) private var displayScale

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
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10))
                    .frame(height: 1 / max(displayScale, 1))
                    .padding(.top, 44)
                    .allowsHitTesting(false)
            }
    }
}

struct AppModalContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            GeometryReader { proxy in
                content
                    .frame(width: proxy.size.width * 0.9, height: proxy.size.height * 0.9)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppTheme.cardBorder(for: colorScheme), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.cardShadow(for: colorScheme), radius: 14, x: 0, y: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

