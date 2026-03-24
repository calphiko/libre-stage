// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GigDetailView: View {
    let gig: GigOut
    @State private var vm = GigDetailViewModel()
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    @State private var showDownloadErrorAlert = false
    @State private var downloadErrorMessage = ""
    @Environment(AuthManager.self) private var authManager

    private var canEdit: Bool {
        authManager.userRole == .admin || authManager.userRole == .editor
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.setlist == nil {
                SkeletonList()
            } else if let setlist = vm.setlist {
                List {
                    // MARK: Gig Info
                    Section("Infos") {
                        GigInfoRow(label: "Datum",       value: gig.datum)
                        GigInfoRow(label: "Venue",       value: gig.venue)
                        GigInfoRow(label: "Veranstalter",value: gig.organizer)
                        GigInfoRow(label: "Art",         value: gig.kind_of_gig)
                        GigInfoRow(label: "Einlass",     value: gig.doors)
                        GigInfoRow(label: "Beginn",      value: gig.begin)
                        GigInfoRow(label: "Ende",        value: gig.end)
                        GigInfoRow(label: "Status",      value: gig.status)
                    }

                    // MARK: Live-Modus (nur Editor/Admin)


                    // MARK: Aktionen (für alle)
                    Section("Aktionen") {
                        Button {
                            Task {
                                if let fileURL = await vm.downloadSetlistPDF(gig: gig) {
                                    shareURL = fileURL
                                    showShareSheet = true
                                } else {
                                    presentDownloadError(documentName: "Setliste")
                                }
                            }
                        } label: {
                            Label("Setliste herunterladen", systemImage: "arrow.down.doc")
                        }

                        Button {
                            Task {
                                if let fileURL = await vm.downloadGemaList(gig: gig) {
                                    shareURL = fileURL
                                    showShareSheet = true
                                } else {
                                    presentDownloadError(documentName: "GEMA-Liste")
                                }
                            }
                        } label: {
                            Label("GEMA-Liste herunterladen", systemImage: "tablecells.badge.ellipsis")
                        }


                        if canEdit {
                            if vm.liveModeAvailability?.available == true {
                                NavigationLink {
                                    LiveModeView(gig: gig)
                                } label: {
                                    HStack {
                                        Label("Live-Modus starten", systemImage: "bolt.fill")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        if vm.liveModeAvailability?.forced == true {
                                            Text("🔓")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                                .listRowBackground(Color.accentColor)
                            } else if vm.liveModeAvailability?.can_force == true {
                                Button {
                                    Task { await vm.loadLiveModeAvailability(gigId: gig.id, force: true) }
                                } label: {
                                    Label("Live Mode entsperren", systemImage: "lock.open")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            } else {
                                Label("Live-Modus aktuell nicht verfügbar", systemImage: "lock.fill")
                                    .foregroundStyle(.secondary)
                            }

                            if let reason = vm.liveModeAvailability?.reason {
                                Text(liveModeReasonText(reason))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                        }
                    }

                    // MARK: Setlist
                    ForEach(setlist.sets) { set in
                        Section(set.setlist_name ?? set.set_name ?? "Set") {
                            ForEach(Array(set.songs.enumerated()), id: \.element.id) { idx, song in
                                NavigationLink {
                                    SongDetailsView(songId: song.song_id, initialTitle: song.title)
                                } label: {
                                    SetlistSongRow(index: idx + 1, song: song)
                                }
                            }
                            if let pause = set.pause {
                                Label("Pause: \(pause)", systemImage: "pause.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                }
                .refreshable {
                    await vm.loadSetlist(gigId: gig.id)
                    await vm.loadLiveModeAvailability(gigId: gig.id)
                }
            } else {
                ContentUnavailableView("Keine Setlist", systemImage: "music.note.list")
            }
        }
        .navigationTitle(gig.name ?? "Gig")
        .navigationBarTitleDisplayMode(.inline)
        .errorBanner($vm.error)
        .task {
            await vm.loadSetlist(gigId: gig.id)
            if canEdit {
                await vm.loadLiveModeAvailability(gigId: gig.id)
            }
        }
        .sheet(isPresented: $showShareSheet) {
#if canImport(UIKit)
            if let shareURL {
                ShareSheet(activityItems: [shareURL])
            }
#else
            Text("Datei heruntergeladen: \(shareURL?.lastPathComponent ?? "")")
                .padding()
#endif
        }
        .alert("Download fehlgeschlagen", isPresented: $showDownloadErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(downloadErrorMessage)
        }
    }

    private func liveModeReasonText(_ reason: String) -> String {
        switch reason {
        case "gig_day":
            return "Live-Mode ist am Gig-Tag aktiv."
        case "not_gig_day":
            return "Live-Mode ist nur am Gig-Tag aktiv oder muss manuell entsperrt werden."
        case "manually_unlocked":
            return "Live-Mode wurde manuell entsperrt."
        case "insufficient_permissions":
            return "Keine Berechtigung für Live-Mode."
        default:
            return "Live-Mode-Status: \(reason)"
        }
    }

    private func presentDownloadError(documentName: String) {
        if let error = vm.error {
            downloadErrorMessage = "\(documentName) konnte nicht heruntergeladen werden.\n\n\(error.localizedMessage)"
            vm.error = nil
        } else {
            downloadErrorMessage = "\(documentName) konnte nicht heruntergeladen werden. Bitte später erneut versuchen."
        }
        showDownloadErrorAlert = true
    }
}

#if canImport(UIKit)
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

private struct GigInfoRow: View {
    let label: String
    let value: String?

    var body: some View {
        if let value, !value.isEmpty {
            LabeledContent(label, value: value)
        }
    }
}

private struct SetlistSongRow: View {
    let index: Int
    let song: SongInSetOut

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).font(.body)
                if let interpret = song.interpret {
                    Text(interpret).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let key = song.tone_key {
                Text(key)
                    .font(.caption2.bold())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }
}

