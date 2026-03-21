// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct GigsView: View {
    @State private var vm = GigsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.gigs.isEmpty {
                    SkeletonList()
                } else if vm.gigs.isEmpty {
                    ContentUnavailableView("Keine Gigs", systemImage: "music.mic")
                } else {
                    List(vm.gigs) { gig in
                        NavigationLink {
                            GigDetailView(gig: gig)
                        } label: {
                            GigRow(gig: gig)
                        }
                    }
                    .refreshable { await vm.load() }
                }
            }
            .navigationTitle("Gigs")
        }
        .errorBanner($vm.error)
        .task { await vm.load() }
    }
}

private struct GigRow: View {
    let gig: GigOut

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(gig.name ?? "–").font(.headline)
            HStack(spacing: 8) {
                if let datum = gig.datum {
                    Label(datum, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let venue = gig.venue {
                    Label(venue, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let kind = gig.kind_of_gig {
                Text(kind)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

