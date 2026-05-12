// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct AdminConfigView: View {
    @State private var vm = AdminConfigViewModel()

    var body: some View {
        Group {
            if vm.isLoading && !vm.hasLoaded {
                SkeletonList()
            } else {
                List {
                    Section {
                        if !vm.updatedAtDisplay.isEmpty {
                            LabeledContent("Stand", value: vm.updatedAtDisplay)
                        }
                    }

                    OptionEditorSection(
                        title: "Genres",
                        rows: Binding(
                            get: { vm.genres },
                            set: { vm.genres = $0 }
                        ),
                        onAdd: { vm.addOption(in: \.genres) },
                        onRemove: { vm.removeOption(in: \.genres, at: $0) }
                    )

                    OptionEditorSection(
                        title: "Gig-Typen",
                        rows: Binding(
                            get: { vm.gigTypes },
                            set: { vm.gigTypes = $0 }
                        ),
                        onAdd: { vm.addOption(in: \.gigTypes) },
                        onRemove: { vm.removeOption(in: \.gigTypes, at: $0) }
                    )

                    OptionEditorSection(
                        title: "Song-Status",
                        rows: Binding(
                            get: { vm.songStatuses },
                            set: { vm.songStatuses = $0 }
                        ),
                        onAdd: { vm.addOption(in: \.songStatuses) },
                        onRemove: { vm.removeOption(in: \.songStatuses, at: $0) }
                    )

                    OptionEditorSection(
                        title: "Gig-Status",
                        rows: Binding(
                            get: { vm.gigStatuses },
                            set: { vm.gigStatuses = $0 }
                        ),
                        onAdd: { vm.addOption(in: \.gigStatuses) },
                        onRemove: { vm.removeOption(in: \.gigStatuses, at: $0) }
                    )

                    OptionEditorSection(
                        title: "Tonarten",
                        rows: Binding(
                            get: { vm.tonekeys },
                            set: { vm.tonekeys = $0 }
                        ),
                        onAdd: { vm.addOption(in: \.tonekeys) },
                        onRemove: { vm.removeOption(in: \.tonekeys, at: $0) }
                    )

                    StringEditorSection(
                        title: "Proben-Song-Status",
                        rows: Binding(
                            get: { vm.rehearsalSongStatuses },
                            set: { vm.rehearsalSongStatuses = $0 }
                        ),
                        onAdd: { vm.addRehearsalStatus() },
                        onRemove: { vm.removeRehearsalStatus(at: $0) }
                    )
                }
                .softCardContainer()
                .refreshable { await vm.load() }
            }
        }
        .appShellBackground()
        .navigationTitle("Konfiguration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Verwerfen") {
                    vm.resetToLoadedState()
                }
                .disabled(!vm.hasChanges || vm.isSaving)

                Button(vm.isSaving ? "Speichern..." : "Speichern") {
                    Task { _ = await vm.save() }
                }
                .disabled(vm.isSaving || !vm.hasChanges)
            }
        }
        .errorBanner($vm.error)
        .task { await vm.load() }
    }
}

private struct OptionEditorSection: View {
    let title: String
    @Binding var rows: [AdminConfigViewModel.EditableOption]
    let onAdd: () -> Void
    let onRemove: (Int) -> Void

    var body: some View {
        Section(title) {
            ForEach(Array(rows.indices), id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Key", text: $rows[index].key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .formFieldSurface()

                    TextField("Label", text: $rows[index].label)
                        .formFieldSurface()

                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            onRemove(index)
                        } label: {
                            Label("Eintrag entfernen", systemImage: "minus.circle.fill")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Button {
                onAdd()
            } label: {
                Label("Eintrag hinzufügen", systemImage: "plus.circle.fill")
            }
        }
    }
}

private struct StringEditorSection: View {
    let title: String
    @Binding var rows: [String]
    let onAdd: () -> Void
    let onRemove: (Int) -> Void

    var body: some View {
        Section(title) {
            ForEach(Array(rows.indices), id: \.self) { index in
                HStack(spacing: 8) {
                    TextField("Status", text: $rows[index])
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .formFieldSurface()

                    Button(role: .destructive) {
                        onRemove(index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                }
            }

            Button {
                onAdd()
            } label: {
                Label("Status hinzufügen", systemImage: "plus.circle.fill")
            }
        }
    }
}


