// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A preference key that child views (subpages) set to signal they are a
/// navigation-stack destination and not the root view.
/// The root view's ZStack observes this to hide/show the floating menu button.
struct NavigationSubpagePreferenceKey: PreferenceKey {
    static let defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    /// Mark this view as a navigation subpage.
    /// Any ancestor root view that wraps its `NavigationStack` with
    /// `.onPreferenceChange(NavigationSubpagePreferenceKey.self)` will
    /// receive `true` while this view is part of the hierarchy, and
    /// `false` once it is popped off the navigation stack.
    func navigationSubpage() -> some View {
        preference(key: NavigationSubpagePreferenceKey.self, value: true)
    }
}

