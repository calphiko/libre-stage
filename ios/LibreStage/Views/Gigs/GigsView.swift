// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct GigsView: View {
    @State private var vm = GigsViewModel()
    @State private var showSeasonStats = false
    @State private var seasonStatsPreset: Int?

    private var gigsBySeason: [(title: String, gigs: [GigOut])] {
        let grouped = Dictionary(grouping: vm.gigs) { gig in
            seasonKey(for: gig)
        }

        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return false
            }
        }

        var sections: [(title: String, gigs: [GigOut])] = sortedKeys.map { key in
            let title = key.map { "Saison \($0)" } ?? "Ohne Datum"
            let gigs = (grouped[key] ?? []).sorted { lhs, rhs in
                let lDate = gigDate(lhs)
                let rDate = gigDate(rhs)
                switch (lDate, rDate) {
                case let (l?, r?): return l > r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return lhs.id > rhs.id
                }
            }
            return (title: title, gigs: gigs)
        }

        if sections.isEmpty, !vm.gigs.isEmpty {
            sections = [(title: "Ohne Datum", gigs: vm.gigs)]
        }

        return sections
    }

    private var availableSeasons: [Int] {
        vm.gigs
            .compactMap { seasonKey(for: $0) }
            .sorted(by: >)
            .reduce(into: [Int]()) { acc, year in
                if acc.last != year { acc.append(year) }
            }
    }

    private var currentSeasonYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.gigs.isEmpty {
                    SkeletonList()
                } else if vm.gigs.isEmpty {
                    ContentUnavailableView("Keine Gigs", systemImage: "music.mic")
                } else {
                    List {
                        Section("Statistiken") {
                            Button {
                                seasonStatsPreset = availableSeasons.contains(currentSeasonYear) ? currentSeasonYear : nil
                                showSeasonStats = true
                            } label: {
                                Label("Aktuelle Saison", systemImage: "chart.bar.fill")
                            }

                            Button {
                                seasonStatsPreset = nil
                                showSeasonStats = true
                            } label: {
                                Label("Alle Saisons", systemImage: "chart.xyaxis.line")
                            }
                        }

                        ForEach(gigsBySeason, id: \.title) { season in
                            Section(season.title) {
                                ForEach(season.gigs) { gig in
                                    NavigationLink {
                                        GigDetailView(gig: gig) { updatedGig in
                                            vm.upsertGig(updatedGig)
                                        }
                                    } label: {
                                        GigRow(gig: gig)
                                    }
                                }
                            }
                        }
                    }
                    .refreshable { await vm.load() }
                }
            }
            .navigationTitle("Gigs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSeasonStats = true
                    } label: {
                        Label("Saisonstatistik", systemImage: "chart.bar.doc.horizontal")
                    }
                }
            }
        }
        .errorBanner($vm.error)
        .task { await vm.load() }
        .sheet(isPresented: $showSeasonStats) {
            SeasonStatisticsSheet(vm: vm, availableSeasons: availableSeasons, initialSeason: seasonStatsPreset)
        }
    }

    private func seasonKey(for gig: GigOut) -> Int? {
        guard let datum = gig.datum else { return nil }
        let prefix = String(datum.prefix(4))
        return Int(prefix)
    }

    private func gigDate(_ gig: GigOut) -> Date? {
        guard let datum = gig.datum else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let parsed = iso.date(from: datum) {
            return parsed
        }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd"
        return fallback.date(from: datum)
    }
}

private struct SeasonStatisticsSheet: View {
    @Bindable var vm: GigsViewModel
    let availableSeasons: [Int]
    let initialSeason: Int?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeason: Int?

    var body: some View {
        NavigationStack {
            List {
                Section("Zeitraum") {
                    Picker("Saison", selection: selectionBinding) {
                        Text("Alle Jahre").tag("all")
                        ForEach(availableSeasons, id: \.self) { year in
                            Text(String(year)).tag(String(year))
                        }
                    }
                    .pickerStyle(.menu)
                }

                if vm.isSeasonStatisticsLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if let stats = vm.seasonStatistics {
                    Section("Uebersicht") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            SeasonKpiTile(title: "Gigs", value: String(stats.gig_count), icon: "music.mic", tint: .blue)
                            SeasonKpiTile(title: "Songs", value: String(stats.total_songs), icon: "music.note.list", tint: .purple)
                            SeasonKpiTile(title: "Unique", value: String(stats.unique_songs), icon: "waveform.path.ecg", tint: .teal)
                            SeasonKpiTile(title: "Uebersprungen", value: String(stats.skipped_count), icon: "forward.fill", tint: .orange)
                            SeasonKpiTile(title: "Eingeschoben", value: String(stats.inserted_count), icon: "pin.fill", tint: .green)
                            if let avg = stats.feedback_avg {
                                SeasonKpiTile(title: "Live", value: "\(feedbackEmoji(for: avg)) \(String(format: "%.2f", avg))", icon: "star.fill", tint: .yellow)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    if !stats.top_songs.isEmpty {
                        Section("Top Songs") {
                            ForEach(stats.top_songs.prefix(10)) { song in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.title).font(.body)
                                        Text(song.interpret).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(song.count)x")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    if !stats.gigs_overview.isEmpty {
                        Section("Gig-Uebersicht") {
                            ForEach(stats.gigs_overview) { gig in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(gig.gig_name).font(.body)
                                    HStack(spacing: 10) {
                                        Text(gig.gig_date).font(.caption).foregroundStyle(.secondary)
                                        Text("Songs: \(gig.song_count)").font(.caption).foregroundStyle(.secondary)
                                        if let avg = gig.feedback_avg {
                                            Text("Ø \(String(format: "%.2f", avg))").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        Text("Keine Saisonstatistiken verfuegbar.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Saisonstatistik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schliessen") { dismiss() }
                }
            }
            .task {
                selectedSeason = initialSeason ?? selectedSeason ?? availableSeasons.first
                await vm.loadSeasonStatistics(year: selectedSeason)
            }
            .onChange(of: selectedSeason) { _, newYear in
                Task { await vm.loadSeasonStatistics(year: newYear) }
            }
        }
    }

    private var selectionBinding: Binding<String> {
        Binding(
            get: { selectedSeason.map(String.init) ?? "all" },
            set: { newValue in
                selectedSeason = newValue == "all" ? nil : Int(newValue)
            }
        )
    }

    private func feedbackEmoji(for avg: Double) -> String {
        if avg >= 2.5 { return "😊" }
        if avg >= 1.5 { return "😐" }
        return "😞"
    }
}

private struct SeasonKpiTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

