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

import Algorithms
import Combine
import SwiftUI

typealias RoomScreenViewModelType = StateStoreViewModel<RoomScreenViewState, RoomScreenViewAction>

class RoomScreenViewModel: RoomScreenViewModelType, RoomScreenViewModelProtocol {
    private enum Constants {
        static let backPaginationEventLimit: UInt = 20
        static let backPaginationPageSize: UInt = 50
        static let toastErrorID = "RoomScreenToastError"
    }

    private let roomProxy: RoomProxyProtocol
    private let timelineController: RoomTimelineControllerProtocol
    
    init(timelineController: RoomTimelineControllerProtocol,
         mediaProvider: MediaProviderProtocol,
         roomProxy: RoomProxyProtocol) {
        self.roomProxy = roomProxy
        self.timelineController = timelineController
        
        super.init(initialViewState: RoomScreenViewState(roomId: timelineController.roomID,
                                                         roomTitle: roomProxy.roomTitle,
                                                         roomAvatarURL: roomProxy.avatarURL,
                                                         timelineStyle: ServiceLocator.shared.settings.timelineStyle,
                                                         bindings: .init(composerText: "", composerFocused: false)),
                   imageProvider: mediaProvider)
        
        timelineController.callbacks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] callback in
                guard let self else { return }
                
                switch callback {
                case .updatedTimelineItems:
                    self.buildTimelineViews()
                case .canBackPaginate(let canBackPaginate):
                    if self.state.canBackPaginate != canBackPaginate {
                        self.state.canBackPaginate = canBackPaginate
                    }
                case .isBackPaginating(let isBackPaginating):
                    if self.state.isBackPaginating != isBackPaginating {
                        self.state.isBackPaginating = isBackPaginating
                    }
                }
            }
            .store(in: &cancellables)
        
        state.contextMenuActionProvider = { [weak self] itemId -> TimelineItemContextMenuActions? in
            guard let self else {
                return nil
            }
            
            return self.contextMenuActionsForItemId(itemId)
        }
        
        roomProxy
            .updatesPublisher
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                guard let self else { return }
                self.state.roomTitle = roomProxy.roomTitle
                self.state.roomAvatarURL = roomProxy.avatarURL
            }
            .store(in: &cancellables)
        
        ServiceLocator.shared.settings.$timelineStyle
            .weakAssign(to: \.state.timelineStyle, on: self)
            .store(in: &cancellables)
                
        buildTimelineViews()
    }
    
    // MARK: - Public

    var callback: ((RoomScreenViewModelAction) -> Void)?
    
    // swiftlint:disable:next cyclomatic_complexity
    override func process(viewAction: RoomScreenViewAction) {
        switch viewAction {
        case .displayRoomDetails:
            callback?(.displayRoomDetails)
        case .paginateBackwards:
            Task { await paginateBackwards() }
        case .itemAppeared(let id):
            Task { await timelineController.processItemAppearance(id) }
        case .itemDisappeared(let id):
            Task { await timelineController.processItemDisappearance(id) }
        case .itemTapped(let id):
            Task { await itemTapped(with: id) }
        case .itemDoubleTapped(let id):
            itemDoubleTapped(with: id)
        case .linkClicked(let url):
            MXLog.warning("Link clicked: \(url)")
        case .sendMessage:
            Task { await sendCurrentMessage() }
        case .sendReaction(let emoji, let itemId):
            Task { await timelineController.sendReaction(emoji, to: itemId) }
        case .cancelReply:
            state.composerMode = .default
        case .cancelEdit:
            state.composerMode = .default
            state.bindings.composerText = ""
        case .markRoomAsRead:
            Task { await markRoomAsRead() }
        case .contextMenuAction(let itemID, let action):
            processContentMenuAction(action, itemID: itemID)
        case .displayCameraPicker:
            callback?(.displayCameraPicker)
        case .displayMediaPicker:
            callback?(.displayMediaPicker)
        case .displayDocumentPicker:
            callback?(.displayDocumentPicker)
        case .handlePasteOrDrop(let provider):
            handlePasteOrDrop(provider)
        }
    }
    
    // MARK: - Private
    
    private func paginateBackwards() async {
        switch await timelineController.paginateBackwards(requestSize: Constants.backPaginationEventLimit, untilNumberOfItems: Constants.backPaginationPageSize) {
        case .failure:
            displayError(.toast(L10n.errorFailedLoadingMessages))
        default:
            break
        }
    }
    
    private func markRoomAsRead() async {
        _ = await timelineController.markRoomAsRead()
    }

    private func itemTapped(with itemId: String) async {
        state.showLoading = true
        let action = await timelineController.processItemTap(itemId)

        switch action {
        case .displayMediaFile(let file, let title):
            callback?(.displayMediaViewer(file: file, title: title))
        case .none:
            break
        }
        state.showLoading = false
    }
    
    private func itemDoubleTapped(with itemId: String) {
        guard let item = state.items.first(where: { $0.id == itemId }), item.isReactable else { return }
        callback?(.displayEmojiPicker(itemID: itemId))
    }
    
    private func buildTimelineViews() {
        var timelineViews = [RoomTimelineViewProvider]()
        
        let itemsGroupedByTimelineDisplayStyle = timelineController.timelineItems.chunked { current, next in
            canGroupItem(timelineItem: current, with: next)
        }
        
        for itemGroup in itemsGroupedByTimelineDisplayStyle {
            guard !itemGroup.isEmpty else {
                MXLog.error("Found empty item group")
                continue
            }
            
            if itemGroup.count == 1 {
                if let firstItem = itemGroup.first {
                    timelineViews.append(RoomTimelineViewProvider(timelineItem: firstItem, groupStyle: .single))
                }
            } else {
                for (index, item) in itemGroup.enumerated() {
                    if index == 0 {
                        timelineViews.append(RoomTimelineViewProvider(timelineItem: item, groupStyle: .first))
                    } else if index == itemGroup.count - 1 {
                        timelineViews.append(RoomTimelineViewProvider(timelineItem: item, groupStyle: .last))
                    } else {
                        timelineViews.append(RoomTimelineViewProvider(timelineItem: item, groupStyle: .middle))
                    }
                }
            }
        }
        
        state.items = timelineViews
    }
        
    private func canGroupItem(timelineItem: RoomTimelineItemProtocol, with otherTimelineItem: RoomTimelineItemProtocol) -> Bool {
        if timelineItem is CollapsibleTimelineItem || otherTimelineItem is CollapsibleTimelineItem {
            return false
        }
        
        guard let eventTimelineItem = timelineItem as? EventBasedTimelineItemProtocol,
              let otherEventTimelineItem = otherTimelineItem as? EventBasedTimelineItemProtocol else {
            return false
        }
        
        // State events aren't rendered as messages so shouldn't be grouped.
        if eventTimelineItem is StateRoomTimelineItem || otherEventTimelineItem is StateRoomTimelineItem {
            return false
        }
        
        //  can be improved by adding a date threshold
        return eventTimelineItem.properties.reactions.isEmpty && eventTimelineItem.sender == otherEventTimelineItem.sender
    }

    private func sendCurrentMessage() async {
        guard !state.bindings.composerText.isEmpty else {
            fatalError("This message should never be empty")
        }
        
        let currentMessage = state.bindings.composerText
        let currentComposerState = state.composerMode

        state.bindings.composerText = ""
        state.composerMode = .default

        switch currentComposerState {
        case .reply(let itemId, _):
            await timelineController.sendMessage(currentMessage, inReplyTo: itemId)
        case .edit(let originalItemId):
            await timelineController.editMessage(currentMessage, original: originalItemId)
        default:
            await timelineController.sendMessage(currentMessage)
        }
    }
    
    private func displayError(_ type: RoomScreenErrorType) {
        switch type {
        case .alert(let message):
            state.bindings.alertInfo = AlertInfo(id: type,
                                                 title: L10n.commonError,
                                                 message: message)
        case .toast(let message):
            ServiceLocator.shared.userIndicatorController.submitIndicator(UserIndicator(id: Constants.toastErrorID,
                                                                                        type: .toast,
                                                                                        title: message,
                                                                                        iconName: "xmark"))
        }
    }
    
    // MARK: ContextMenus
    
    private func contextMenuActionsForItemId(_ itemId: String) -> TimelineItemContextMenuActions? {
        guard let timelineItem = timelineController.timelineItems.first(where: { $0.id == itemId }),
              let item = timelineItem as? EventBasedTimelineItemProtocol else {
            // Don't show a context menu for non-event based items.
            return nil
        }
        
        if timelineItem is StateRoomTimelineItem {
            // Don't show a context menu for state events.
            return nil
        }
        
        var actions: [TimelineItemContextMenuAction] = [
            .react, .reply, .copyPermalink
        ]
        
        if timelineItem is EventBasedMessageTimelineItemProtocol {
            actions.append(contentsOf: [.copy, .quote])
        }

        if item.isEditable {
            actions.append(.edit)
        }
        
        if item.isOutgoing {
            actions.append(.redact)
        } else {
            actions.append(.report)
        }
        
        var debugActions: [TimelineItemContextMenuAction] = ServiceLocator.shared.settings.canShowDeveloperOptions ? [.viewSource] : []
        
        if let item = timelineItem as? EncryptedRoomTimelineItem,
           case let .megolmV1AesSha2(sessionID) = item.encryptionType {
            debugActions.append(.retryDecryption(sessionID: sessionID))
        }
        
        return .init(actions: actions, debugActions: debugActions)
    }
    
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func processContentMenuAction(_ action: TimelineItemContextMenuAction, itemID: String) {
        guard let timelineItem = timelineController.timelineItems.first(where: { $0.id == itemID }),
              let eventTimelineItem = timelineItem as? EventBasedTimelineItemProtocol else {
            return
        }
        
        switch action {
        case .react:
            callback?(.displayEmojiPicker(itemID: eventTimelineItem.id))
        case .copy:
            guard let messageTimelineItem = timelineItem as? EventBasedMessageTimelineItemProtocol else {
                return
            }
            
            UIPasteboard.general.string = messageTimelineItem.body
        case .edit:
            guard let messageTimelineItem = timelineItem as? EventBasedMessageTimelineItemProtocol else {
                return
            }
            
            state.bindings.composerFocused = true
            state.bindings.composerText = messageTimelineItem.body
            state.composerMode = .edit(originalItemId: messageTimelineItem.id)
        case .quote:
            guard let messageTimelineItem = timelineItem as? EventBasedMessageTimelineItemProtocol else {
                return
            }
            
            state.bindings.composerFocused = true
            state.bindings.composerText = "> \(messageTimelineItem.body)\n\n"
        case .copyPermalink:
            do {
                let permalink = try PermalinkBuilder.permalinkTo(eventIdentifier: eventTimelineItem.id, roomIdentifier: timelineController.roomID)
                UIPasteboard.general.url = permalink
            } catch {
                displayError(.alert(L10n.errorFailedCreatingThePermalink))
            }
        case .redact:
            Task {
                await timelineController.redact(itemID)
            }
        case .reply:
            state.bindings.composerFocused = true
            state.composerMode = .reply(id: eventTimelineItem.id, displayName: eventTimelineItem.sender.displayName ?? eventTimelineItem.sender.id)
        case .viewSource:
            let debugInfo = timelineController.debugInfo(for: eventTimelineItem.id)
            MXLog.info(debugInfo)
            state.bindings.debugInfo = debugInfo
        case .retryDecryption(let sessionID):
            Task {
                await timelineController.retryDecryption(for: sessionID)
            }
        case .report:
            callback?(.displayReportContent(itemID: itemID, senderID: eventTimelineItem.sender.id))
        }
        
        if action.switchToDefaultComposer {
            state.composerMode = .default
        }
    }
    
    // Pasting and dropping
    
    private func handlePasteOrDrop(_ provider: NSItemProvider) {
        guard let contentType = provider.preferredContentType,
              let preferredExtension = contentType.preferredFilenameExtension else {
            MXLog.error("Invalid NSItemProvider: \(provider)")
            displayError(.toast(L10n.screenRoomErrorFailedProcessingMedia))
            return
        }
        
        let providerSuggestedName = provider.suggestedName
        let providerDescription = provider.description
        
        _ = provider.loadDataRepresentation(for: contentType) { data, error in
            Task { @MainActor in
                let loadingIndicatorIdentifier = UUID().uuidString
                ServiceLocator.shared.userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorIdentifier, type: .modal, title: L10n.commonLoading, persistent: true))
                defer {
                    ServiceLocator.shared.userIndicatorController.retractIndicatorWithId(loadingIndicatorIdentifier)
                }

                if let error {
                    self.displayError(.toast(L10n.screenRoomErrorFailedProcessingMedia))
                    MXLog.error("Failed processing NSItemProvider: \(providerDescription) with error: \(error)")
                    return
                }

                guard let data else {
                    self.displayError(.toast(L10n.screenRoomErrorFailedProcessingMedia))
                    MXLog.error("Invalid NSItemProvider data: \(providerDescription)")
                    return
                }

                do {
                    let url = try await Task.detached {
                        if let filename = providerSuggestedName {
                            let hasExtension = !(filename as NSString).pathExtension.isEmpty
                            let filename = hasExtension ? filename : "\(filename).\(preferredExtension)"
                            return try FileManager.default.writeDataToTemporaryDirectory(data: data, fileName: filename)
                        } else {
                            let filename = "\(UUID().uuidString).\(preferredExtension)"
                            return try FileManager.default.writeDataToTemporaryDirectory(data: data, fileName: filename)
                        }
                    }.value

                    self.callback?(.displayMediaUploadPreviewScreen(url: url))
                } catch {
                    self.displayError(.toast(L10n.screenRoomErrorFailedProcessingMedia))
                    MXLog.error("Failed storing NSItemProvider data \(providerDescription) with error: \(error)")
                }
            }
        }
    }
}

// MARK: - Mocks

extension RoomScreenViewModel {
    static let mock = RoomScreenViewModel(timelineController: MockRoomTimelineController(),
                                          mediaProvider: MockMediaProvider(),
                                          roomProxy: RoomProxyMock(with: .init(displayName: "Preview room")))
}
