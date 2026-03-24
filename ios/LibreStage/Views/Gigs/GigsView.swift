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
                            GigDetailView(gig: gig) { updatedGig in
                                vm.upsertGig(updatedGig)
                            }
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

    private var isPastGig: Bool {
        guard let datum = gig.datum else { return false }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let dateFromISO = iso.date(from: datum)

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd"
        let parsedDate = dateFromISO ?? fallback.date(from: datum)

        guard let parsedDate else { return false }
        return parsedDate < Calendar.current.startOfDay(for: Date())
    }

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
                HStack(spacing: 6) {
                    Text(kind)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())

                    if isPastGig {
                        Text("Vergangen")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.18))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isPastGig ? 0.45 : 1.0)
    }
}

