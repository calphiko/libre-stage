// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@Observable
final class ProfileViewModel {
    var isChangingPassword = false
    var passwordError: String?
    var passwordSuccess = false
    var error: AppError?

    @MainActor
    func changePassword(userId: Int, old: String, new: String) async {
        isChangingPassword = true
        passwordError = nil
        passwordSuccess = false
        defer { isChangingPassword = false }

        let body = PasswordUpdateRequest(user_id: userId, old_password: old, new_password: new)
        do {
            let _: EmptyResponse = try await APIClient.shared.put(path: "/change_password", body: body)
            passwordSuccess = true
        } catch let e as AppError {
            switch e {
            case .serverError(_, let detail): passwordError = detail
            default: passwordError = e.localizedMessage
            }
        } catch {
            passwordError = error.localizedDescription
        }
    }
}

