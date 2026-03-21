// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@main
struct LibreStageApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentRoot()
                .environment(authManager)
        }
    }
}

struct ContentRoot: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        if authManager.isLoggedIn {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

#Preview {
    ContentRoot()
        .environment(AuthManager())
}
