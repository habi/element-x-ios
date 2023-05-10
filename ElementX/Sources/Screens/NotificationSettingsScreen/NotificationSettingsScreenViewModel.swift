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

import Combine
import SwiftUI

typealias NotificationSettingsScreenViewModelType = StateStoreViewModel<NotificationSettingsScreenViewState, NotificationSettingsScreenViewAction>

class NotificationSettingsScreenViewModel: NotificationSettingsScreenViewModelType, NotificationSettingsScreenViewModelProtocol {
    private var actionsSubject: PassthroughSubject<NotificationSettingsScreenViewModelAction, Never> = .init()
    private let userSession: UserSessionProtocol
    
    var actions: AnyPublisher<NotificationSettingsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(userSession: UserSessionProtocol) {
        self.userSession = userSession
        super.init(initialViewState: NotificationSettingsScreenViewState())
    }
    
    private func loadPushRules() { }
    
    // MARK: - Public
    
    override func process(viewAction: NotificationSettingsScreenViewAction) {
        switch viewAction {
        case .accept:
            actionsSubject.send(.accept)
        case .cancel:
            actionsSubject.send(.cancel)
        case .incrementCount:
            break
        case .decrementCount:
            break
        }
    }
}
