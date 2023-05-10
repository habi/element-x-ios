//
// Copyright 2023 New Vector Ltd
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
import Foundation
import MatrixRustSDK

private final class WeakNotificationSettingsManagerProxy: NotificationSettingsManagerDelegate {
    private weak var proxy: NotificationSettingsManagerProxy?
    
    init(proxy: NotificationSettingsManagerProxy) {
        self.proxy = proxy
    }
    
    // MARK: - NotificationSettingsDelegate
    
    func notificationSettingsDidChange() {
        proxy?.notificationSettingsDidChange()
    }
}

final class NotificationSettingsManagerProxy: NotificationSettingsManagerProxyProtocol {
    private(set) var notificationSettingsManager: MatrixRustSDK.NotificationSettingsManagerProtocol
    private var syncUpdateCancellable: AnyCancellable?

    let callbacks = PassthroughSubject<NotificationSettingsManagerProxyCallback, Never>()

    init(notificationSettingsManagerProxy: MatrixRustSDK.NotificationSettingsManagerProtocol) {
        notificationSettingsManager = notificationSettingsManagerProxy
        Task { [weak self] in
            guard let self else { return }
            await self.notificationSettingsManager.setDelegate(delegate: WeakNotificationSettingsManagerProxy(proxy: self))
        }
    }
    
    @MainActor
    func getNotificationMode(room: RoomProxyProtocol) async throws -> RoomNotificationSettingsProxyProtocol {
        let roomMotificationSettings = try await notificationSettingsManager.getRoomNotificationMode(roomId: room.id)
        return RoomNotificationSettingsProxy(roomNotificationSettings: roomMotificationSettings)
    }
    
    @MainActor
    func setNotificationMode(room: RoomProxyProtocol, mode: RoomNotificationMode) async throws {
        try await notificationSettingsManager.setRoomNotificationMode(roomId: room.id, mode: mode)
    }
    
    @MainActor
    func restoreDefaultNotificationMode(room: RoomProxyProtocol) async throws {
        try await notificationSettingsManager.restoreDefaultRoomNotificationMode(roomId: room.id)
    }
    
    // MARK: - Private
    
    func notificationSettingsDidChange() {
        callbacks.send(.notificationSettingsDidChange)
    }
}
