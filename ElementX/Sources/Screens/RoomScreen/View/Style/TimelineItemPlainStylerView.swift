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

import Foundation
import SwiftUI

struct TimelineItemPlainStylerView<Content: View>: View {
    @EnvironmentObject private var context: RoomScreenViewModel.Context
    @Environment(\.timelineGroupStyle) private var timelineGroupStyle
    
    let timelineItem: EventBasedTimelineItemProtocol
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .trailing) {
            VStack(alignment: .leading, spacing: 4) {
                header

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        contentWithReply

                        Spacer()
                    }
                    supplementaryViews
                }
            }
            TimelineReceiptView(timelineItem: timelineItem)
                .environmentObject(context)
        }
    }
    
    @ViewBuilder
    var contentWithReply: some View {
        VStack(alignment: .leading) {
            if let messageTimelineItem = timelineItem as? EventBasedMessageTimelineItemProtocol,
               let replyDetails = messageTimelineItem.replyDetails {
                HStack(spacing: 4.0) {
                    Rectangle()
                        .foregroundColor(.global.melon)
                        .frame(width: 4.0)
                    TimelineReplyView(timelineItemReplyDetails: replyDetails)
                }
            }
            
            content()
        }
        .contextMenu {
            context.viewState.contextMenuActionProvider?(timelineItem.id).map { actions in
                TimelineItemContextMenu(itemID: timelineItem.id, contextMenuActions: actions)
            }
        }
    }
    
    @ViewBuilder
    private var header: some View {
        if shouldShowSenderDetails {
            HStack {
                TimelineSenderAvatarView(timelineItem: timelineItem)
                Text(timelineItem.sender.displayName ?? timelineItem.sender.id)
                    .font(.subheadline)
                    .foregroundColor(.element.primaryContent)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Text(timelineItem.timestamp)
                    .foregroundColor(Color.element.tertiaryContent)
                    .font(.compound.bodyXS)
            }
            .padding(.top, 16)
        }
    }
    
    @ViewBuilder
    private var supplementaryViews: some View {
        VStack {
            if timelineItem.properties.isEdited {
                Text(L10n.commonEditedSuffix)
                    .font(.compound.bodySM)
                    .foregroundColor(.element.tertiaryContent)
            }
            
            if !timelineItem.properties.reactions.isEmpty {
                TimelineReactionsView(reactions: timelineItem.properties.reactions,
                                      alignment: .leading) { key in
                    context.send(viewAction: .sendReaction(key: key, eventID: timelineItem.id))
                }
            }
        }
    }
    
    private var shouldShowSenderDetails: Bool {
        timelineGroupStyle.shouldShowSenderDetails
    }
}

struct TimelineItemPlainStylerView_Previews: PreviewProvider {
    static let viewModel = RoomScreenViewModel.mock
    
    static var previews: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(1..<MockRoomTimelineController().timelineItems.count, id: \.self) { index in
                let item = MockRoomTimelineController().timelineItems[index]
                RoomTimelineViewProvider(timelineItem: item, groupStyle: .single)
                    .padding(TimelineStyle.plain.rowInsets) // Insets added in the table view cells
            }
        }
        .timelineStyle(.plain)
        .previewLayout(.sizeThatFits)
        .environmentObject(viewModel.context)
    }
}
