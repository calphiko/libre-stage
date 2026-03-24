// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Thin router – dispatches to the correct detail view.
/// Kept for backwards-compatibility if surveyType is not known upfront.
struct SurveyDetailView: View {
    let surveyId: Int
    let surveyType: String          // "Terminfindung" or "Meinungsumfrage"

    var body: some View {
        Group {
            if surveyType == "Terminfindung" {
                TerminfindungDetailView(surveyId: surveyId)
            } else {
                MeinungsumfrageDetailView(surveyId: surveyId)
            }
        }
    }
}
