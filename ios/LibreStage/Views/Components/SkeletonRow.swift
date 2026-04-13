// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A placeholder row used for skeleton loading.
struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .frame(width: 120, height: 12)
            }
            Spacer()
        }
        .foregroundStyle(Color.secondary.opacity(0.3))
        .redacted(reason: .placeholder)
    }
}

/// Shows a list of skeleton rows while loading.
struct SkeletonList: View {
    var count: Int = 6

    var body: some View {
        List {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonRow()
            }
        }
        .softCardContainer()
    }
}

