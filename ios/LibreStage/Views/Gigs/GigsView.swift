// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct GigsView: View {
    let onMenuTap: (() -> Void)?
    @Environment(AuthManager.self) private var authManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var vm = GigsViewModel()
    @State private var showSeasonStats = false
    @State private var seasonStatsPreset: Int?
    @State private var showCreateGigSheet = false
    @State private var selectedSeason: Int?
    @State private var isInSubpage = false

    init(onMenuTap: (() -> Void)? = nil) {
        self.onMenuTap = onMenuTap
    }

    private var canEdit: Bool {
        authManager.userRole == .admin || authManager.userRole == .editor
    }

    private var filteredGigs: [GigOut] {
        let targetSeason = effectiveSelectedSeason
        let seasonGigs = vm.gigs.filter { seasonKey(for: $0) == targetSeason }
        return seasonGigs.sorted(by: isBeforeInGigList)
    }

    private var availableSeasons: [Int] {
        ([currentSeasonYear] + vm.gigs
            .compactMap { seasonKey(for: $0) }
            .sorted(by: >)
            .reduce(into: [Int]()) { acc, year in
                if acc.last != year { acc.append(year) }
            })
            .sorted(by: >)
            .reduce(into: [Int]()) { acc, year in
                if acc.last != year { acc.append(year) }
            }
    }

    private var currentSeasonYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var defaultSeasonSelection: Int? {
        currentSeasonYear
    }

    private var effectiveSelectedSeason: Int? {
        selectedSeason ?? defaultSeasonSelection
    }

    private var selectedSeasonTitle: String {
        if let year = effectiveSelectedSeason {
            return "Saison \(year)"
        }
        return "Saison"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationStack {
                Group {
                    if vm.isLoading && vm.gigs.isEmpty {
                    SkeletonList()
                } else if vm.gigs.isEmpty {
                    ContentUnavailableView("Keine Gigs", systemImage: "music.mic")
                } else {
                    List {
                        Section(selectedSeasonTitle) {
                            if filteredGigs.isEmpty {
                                Text("Keine Gigs in dieser Saison")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(filteredGigs) { gig in
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
                        .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await vm.load() }
                }
            }
            .appShellBackground()
            .navigationTitle("Gigs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Gigs")
                        .font(.headline)
                        .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        ForEach(availableSeasons, id: \.self) { year in
                            Button {
                                selectedSeason = year
                            } label: {
                                if year == effectiveSelectedSeason {
                                    Label(String(year), systemImage: "checkmark")
                                } else {
                                    Text(String(year))
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(String(effectiveSelectedSeason ?? currentSeasonYear))
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.rowBackground(for: colorScheme)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Saison auswaehlen")

                    Button {
                        seasonStatsPreset = effectiveSelectedSeason
                        showSeasonStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(AppTheme.rowBackground(for: colorScheme)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Saisonstatistik")

                    if canEdit {
                        Button {
                            showCreateGigSheet = true
                        } label: {
                            Label("Gig hinzufuegen", systemImage: "plus")
                        }
                    }
                }
            }
            .headerBodyBlend()
            .onChange(of: availableSeasons) { _, newSeasons in
                guard let currentSelection = effectiveSelectedSeason else {
                    selectedSeason = nil
                    return
                }
                if !newSeasons.contains(currentSelection) {
                    selectedSeason = defaultSeasonSelection
                } else if selectedSeason == nil {
                    selectedSeason = currentSelection
                }
            }
            .errorBanner($vm.error)
            .task {
                await vm.loadGigFieldConfig()
                await vm.load()
                if selectedSeason == nil {
                    selectedSeason = defaultSeasonSelection
                }
            }
            .fullScreenCover(isPresented: $showSeasonStats) {
                SeasonStatisticsSheet(vm: vm, availableSeasons: availableSeasons, initialSeason: seasonStatsPreset)
            }
            .fullScreenCover(isPresented: $showCreateGigSheet) {
                AppModalContainer {
                    CreateGigSheet(vm: vm)
                }
            }
        }
        .onPreferenceChange(NavigationSubpagePreferenceKey.self) { isInSubpage = $0 }

        if let onMenuTap, !isInSubpage {
            AppMenuButton(action: onMenuTap)
                .padding(.leading, 12)
                .padding(.top, 0)
        }
    }
}

    private func isBeforeInGigList(_ lhs: GigOut, _ rhs: GigOut) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let lDate = gigDate(lhs)
        let rDate = gigDate(rhs)

        switch (lDate, rDate) {
        case let (l?, r?):
            let lIsUpcoming = l >= today
            let rIsUpcoming = r >= today

            if lIsUpcoming != rIsUpcoming {
                return lIsUpcoming && !rIsUpcoming
            }

            if lIsUpcoming {
                return l < r
            }

            return l > r
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.id > rhs.id
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
            Form {
                Section("Zeitraum") {
                    Picker("Saison", selection: selectionBinding) {
                        Text("Alle Jahre").tag("all")
                        ForEach(availableSeasons, id: \.self) { year in
                            Text(String(year)).tag(String(year))
                        }
                    }
                    .pickerStyle(.menu)
                    .addModalFieldStyle()
                }
                .addModalSectionStyle()

                if vm.isSeasonStatisticsLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                    .addModalSectionStyle()
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
                    .addModalSectionStyle()

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
                        .addModalSectionStyle()
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
                        .addModalSectionStyle()
                    }
                } else {
                    Section {
                        Text("Keine Saisonstatistiken verfuegbar.")
                            .foregroundStyle(.secondary)
                    }
                    .addModalSectionStyle()
                }
            }
            .addModalFormStyle()
            .navigationTitle("Saisonstatistik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
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

private struct CreateGigSheet: View {
    @Bindable var vm: GigsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = GigDetailsDraft()

    var body: some View {
        NavigationStack {
            Form {
                Section("Gig") {
                    ForEach(vm.gigFields) { field in
                        gigEditorView(for: field)
                    }
                }
                .addModalSectionStyle()

                if vm.isCreatingGig {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                    .addModalSectionStyle()
                }
            }
            .addModalFormStyle()
            .navigationTitle("Neuer Gig")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        Task {
                            if await vm.createGig(draft: draft) != nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(vm.isCreatingGig)
                }
            }
        }
    }

    @ViewBuilder
    private func gigEditorView(for field: GigFieldDefinition) -> some View {
        switch field.type {
        case .option:
            Picker(field.required ? "\(field.label) *" : field.label, selection: gigBinding(for: field.key)) {
                if !field.required {
                    Text("-").tag("")
                }
                ForEach(field.options) { option in
                    Text(option.label).tag(option.key)
                }
            }
            .pickerStyle(.menu)
            .addModalFieldStyle()
        case .time:
            HStack {
                DatePicker(
                    field.required ? "\(field.label) *" : field.label,
                    selection: timeBinding(for: field.key),
                    displayedComponents: .hourAndMinute
                )
                if !field.required {
                    Button("Loeschen") {
                        draft.setValue("", for: field.key)
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            .addModalFieldStyle()
        case .date:
            DatePicker(
                field.required ? "\(field.label) *" : field.label,
                selection: dateBinding(for: field.key),
                displayedComponents: .date
            )
            .addModalFieldStyle()
        case .text:
            TextField(field.required ? "\(field.label) *" : field.label, text: gigBinding(for: field.key))
                .addModalFieldStyle()
        }
    }

    private func gigBinding(for key: String) -> Binding<String> {
        Binding(
            get: { draft.value(for: key) },
            set: { draft.setValue($0, for: key) }
        )
    }

    private func dateBinding(for key: String) -> Binding<Date> {
        Binding(
            get: {
                let current = draft.value(for: key)
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: current) ?? Date()
            },
            set: { newDate in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd"
                draft.setValue(formatter.string(from: newDate), for: key)
            }
        )
    }

    private func timeBinding(for key: String) -> Binding<Date> {
        Binding(
            get: {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "HH:mm"
                return formatter.date(from: draft.value(for: key)) ?? Date()
            },
            set: { newDate in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "HH:mm"
                draft.setValue(formatter.string(from: newDate), for: key)
            }
        )
    }
}
