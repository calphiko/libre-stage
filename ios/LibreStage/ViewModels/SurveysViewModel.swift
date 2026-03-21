// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@Observable
final class SurveysViewModel {

    var surveys: [SurveyList] = []
    var detail: SurveyQuestionOut? = nil
    var users: [UserListElem] = []
    var isLoading = false
    var error: AppError?
    var reminderResult: ReminderResponse? = nil

    // MARK: - Derived

    var activeSurveys: [SurveyList] { surveys.filter { !$0.closed } }
    var closedSurveys:  [SurveyList] { surveys.filter {  $0.closed } }

    func userName(for userId: Int) -> String {
        users.first { $0.id == userId }?.clear_name ?? "#\(userId)"
    }

    // MARK: - Load

    @MainActor
    func loadList() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let s: [SurveyList]   = APIClient.shared.get(path: "/surveys/")
            async let u: [UserListElem] = APIClient.shared.get(path: "/user_list")
            surveys = try await s
            users   = try await u
        } catch let e as AppError { error = e
        } catch { self.error = .networkError(error) }
    }

    @MainActor
    func loadDetail(id: Int) async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await APIClient.shared.get(path: "/surveys/\(id)")
            if users.isEmpty {
                users = try await APIClient.shared.get(path: "/user_list")
            }
        } catch let e as AppError { error = e
        } catch { self.error = .networkError(error) }
    }

    // MARK: - Create

    @MainActor
    func createSurvey(_ survey: SurveyIn) async {
        isLoading = true
        defer { isLoading = false }
        do {
            surveys = try await APIClient.shared.post(path: "/surveys/", body: survey)
        } catch let e as AppError { error = e
        } catch { self.error = .networkError(error) }
    }

    // MARK: - Archive  (PUT /surveys/close/{id})

    @MainActor
    func archiveSurvey(id: Int) async {
        do {
            struct E: Encodable {}
            surveys = try await APIClient.shared.put(path: "/surveys/close/\(id)", body: E())
        } catch let e as AppError { error = e
        } catch { self.error = .networkError(error) }
    }

    // MARK: - Delete

    @MainActor
    func deleteSurvey(id: Int) async {
        do {
            surveys = try await APIClient.shared.delete(path: "/surveys/\(id)")
        } catch let e as AppError { error = e
        } catch { self.error = .networkError(error) }
    }

    // MARK: - Feedback Update  (PUT /surveys/{id}/feedback)

    @MainActor
    func updateFeedback(surveyId: Int, feedbacks: [SurveyFeedbackPayload]) async {
        do {
            // PUT to submit feedbacks
            let _: SurveyQuestionOut = try await APIClient.shared.put(
                path: "/surveys/\(surveyId)/feedback",
                body: feedbacks
            )
            // Always reload via GET to guarantee SwiftUI sees the change
            detail = try await APIClient.shared.get(path: "/surveys/\(surveyId)")
        } catch let e as AppError { error = e
        } catch { self.error = .networkError(error) }
    }

    // MARK: - Reminder  (POST /surveys/reminder/{id})

    @MainActor
    func sendReminder(surveyId: Int) async {
        do {
            struct E: Encodable {}
            reminderResult = try await APIClient.shared.post(
                path: "/surveys/reminder/\(surveyId)",
                body: E()
            )
        } catch let e as AppError { error = e
        } catch { self.error = .networkError(error) }
    }
}
