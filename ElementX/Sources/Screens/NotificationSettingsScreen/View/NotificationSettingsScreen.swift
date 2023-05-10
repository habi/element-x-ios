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

struct NotificationSettingsScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var counterColor: Color {
        colorScheme == .light ? .element.secondaryContent : .element.tertiaryContent
    }
    
    @ObservedObject var context: NotificationSettingsScreenViewModel.Context
    
    var body: some View {
        ScrollView {
            mainContent
                .padding(.top, 50)
                .padding(.horizontal)
                .readableFrame()
        }
        .safeAreaInset(edge: .bottom) {
            buttons
                .padding(.horizontal)
                .padding(.vertical)
                .readableFrame()
                .background(Color.element.system)
        }
    }
    
    /// The main content of the view to be shown in a scroll view.
    var mainContent: some View {
        VStack(spacing: 36) {
            Text("Notifications")
                .font(.compound.headingMDBold)
                .multilineTextAlignment(.center)
                .foregroundColor(.element.primaryContent)
                .accessibilityIdentifier("title")
        }
    }
    
    /// The action buttons shown at the bottom of the view.
    var buttons: some View {
        VStack {
            Button { context.send(viewAction: .accept) } label: {
                Text("Accept")
            }
            .buttonStyle(.elementAction(.xLarge))
            
            Button { context.send(viewAction: .cancel) } label: {
                Text("Cancel")
                    .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Previews

struct NotificationSettingsScreen_Previews: PreviewProvider {
    static let viewModel = {
        let userSession = MockUserSession(clientProxy: MockClientProxy(userID: "@userid:example.com"),
                                          mediaProvider: MockMediaProvider())
        let viewModel = NotificationSettingsScreenViewModel(userSession: userSession)
        return viewModel
    }()
    
    static var previews: some View {
        NotificationSettingsScreen(context: viewModel.context)
            .previewDisplayName("Regular")
    }
}
