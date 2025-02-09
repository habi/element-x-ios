//
// Copyright 2022 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import SwiftUI

struct SoftLogoutScreenCoordinatorParameters {
    let authenticationService: AuthenticationServiceProxyProtocol
    let credentials: SoftLogoutScreenCredentials
    let keyBackupNeeded: Bool
}

enum SoftLogoutScreenCoordinatorResult: CustomStringConvertible {
    /// Login was successful.
    case signedIn(UserSessionProtocol)
    /// Clear all user data
    case clearAllData
    
    /// A string representation of the result, ignoring any associated values that could leak PII.
    var description: String {
        switch self {
        case .signedIn:
            return "signedIn"
        case .clearAllData:
            return "clearAllData"
        }
    }
}

final class SoftLogoutScreenCoordinator: CoordinatorProtocol {
    private let parameters: SoftLogoutScreenCoordinatorParameters
    private var viewModel: SoftLogoutScreenViewModelProtocol
    
    private let oidcAuthenticationPresenter: OIDCAuthenticationPresenter
    private var authenticationService: AuthenticationServiceProxyProtocol { parameters.authenticationService }
    
    var callback: (@MainActor (SoftLogoutScreenCoordinatorResult) -> Void)?
    
    @MainActor init(parameters: SoftLogoutScreenCoordinatorParameters) {
        self.parameters = parameters
        
        let homeserver = parameters.authenticationService.homeserver
        viewModel = SoftLogoutScreenViewModel(credentials: parameters.credentials,
                                              homeserver: homeserver,
                                              keyBackupNeeded: parameters.keyBackupNeeded)
        
        oidcAuthenticationPresenter = OIDCAuthenticationPresenter(authenticationService: parameters.authenticationService)
    }
    
    // MARK: - Public
    
    func start() {
        viewModel.callback = { [weak self] result in
            guard let self else { return }
            MXLog.info("[SoftLogoutCoordinator] SoftLogoutViewModel did complete with result: \(result).")

            switch result {
            case .login(let password):
                self.login(withPassword: password)
            case .forgotPassword:
                self.showForgotPasswordScreen()
            case .clearAllData:
                self.callback?(.clearAllData)
            case .continueWithOIDC:
                self.continueWithOIDC()
            }
        }
    }
    
    func stop() {
        stopLoading()
    }
    
    func toPresentable() -> AnyView {
        AnyView(SoftLogoutScreen(context: viewModel.context))
    }
    
    // MARK: - Private
    
    private static let loadingIndicatorIdentifier = "SoftLogoutLoading"
    
    /// Show an activity indicator whilst loading.
    @MainActor private func startLoading() {
        ServiceLocator.shared.userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorIdentifier,
                                                                                    type: .modal,
                                                                                    title: L10n.commonLoading,
                                                                                    persistent: true))
    }
    
    /// Hide the currently displayed activity indicator.
    @MainActor private func stopLoading() {
        ServiceLocator.shared.userIndicatorController.retractIndicatorWithId(Self.loadingIndicatorIdentifier)
    }

    /// Shows the forgot password screen.
    @MainActor private func showForgotPasswordScreen() {
        viewModel.displayError(.alert("Not implemented."))
    }

    /// Login with the supplied username and password.
    @MainActor private func login(withPassword password: String) {
        let username = parameters.credentials.userId

        startLoading()

        Task {
            switch await authenticationService.login(username: username,
                                                     password: password,
                                                     initialDeviceName: UIDevice.current.initialDeviceName,
                                                     deviceId: parameters.credentials.deviceId) {
            case .success(let userSession):
                callback?(.signedIn(userSession))
                stopLoading()
            case .failure(let error):
                stopLoading()
                handleError(error)
            }
        }
    }

    private func continueWithOIDC() {
        startLoading()
        
        Task {
            switch await authenticationService.urlForOIDCLogin() {
            case .failure(let error):
                stopLoading()
                handleError(error)
            case .success(let oidcData):
                stopLoading()
                
                switch await oidcAuthenticationPresenter.authenticate(using: oidcData) {
                case .success(let userSession):
                    callback?(.signedIn(userSession))
                case .failure(let error):
                    handleError(error)
                }
            }
        }
    }

    /// Processes an error to either update the flow or display it to the user.
    private func handleError(_ error: AuthenticationServiceError) {
        switch error {
        case .invalidCredentials:
            viewModel.displayError(.alert(L10n.screenLoginErrorInvalidCredentials))
        case .accountDeactivated:
            viewModel.displayError(.alert(L10n.screenLoginErrorDeactivatedAccount))
        case .oidcError(.notSupported):
            // Temporary alert hijacking the use of .notSupported, can be removed when OIDC support is in the SDK.
            viewModel.displayError(.alert(L10n.commonServerNotSupported))
        case .oidcError(.userCancellation):
            // No need to show an error, the user cancelled authentication.
            break
        default:
            viewModel.displayError(.alert(L10n.errorUnknown))
        }
    }
}
