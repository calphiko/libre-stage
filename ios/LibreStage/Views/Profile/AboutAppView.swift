// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct AboutAppView: View {
    var body: some View {
        List {
            Section("libre-stage") {
                Text("Die mobile App für libre-stage - die interne Band-Management-Plattform.")
                LabeledContent("Version", value: appVersion)
            }

            Section("Credits") {
                Text("Entwickelt von den libre-stage contributors.")
                Text("Open-Source-Projekt unter GPL-3.0-or-later.")
            }

            Section("Links") {
                Link(destination: URL(string: "https://calphiko.codeberg.page/libre-stage/")!) {
                    Label("Dokumentation", systemImage: "book")
                }
                Link(destination: URL(string: "https://pakleds-patentoffice.de")!) {
                    Label("pakleds-patentoffice.de", systemImage: "safari")
                }
            }
        }
        .navigationTitle("Über diese App")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (Build \(build))"
    }
}


