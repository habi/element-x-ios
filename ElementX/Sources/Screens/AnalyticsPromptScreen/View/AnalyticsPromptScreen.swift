//
// Copyright 2021 New Vector Ltd
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

/// A prompt that asks the user whether they would like to enable Analytics or not.
struct AnalyticsPromptScreen: View {
    private let horizontalPadding: CGFloat = 16
    
    @ObservedObject var context: AnalyticsPromptScreenViewModel.Context
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                Spacer()
                    .frame(height: UIConstants.spacerHeight(in: geometry))
                
                mainContent
                    .readableFrame()
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, UIConstants.onboardingBreakerScreenTopPadding)
                    .padding(.bottom, 8)
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    buttons
                        .readableFrame()
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, UIConstants.actionButtonBottomPadding)
                    
                    Spacer()
                        .frame(height: UIConstants.spacerHeight(in: geometry))
                }
                .padding(.top, 8)
                .background(Color.element.background.ignoresSafeArea())
            }
            .background(Color.element.background.ignoresSafeArea())
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
    
    /// The main content of the screen that is shown inside the scroll view.
    private var mainContent: some View {
        VStack {
            Image(uiImage: Asset.Images.analyticsLogo.image)
                .padding(.bottom, 24)
            
            Text(L10n.screenAnalyticsPromptTitle(InfoPlistReader.main.bundleDisplayName))
                .font(.compound.headingMDBold)
                .multilineTextAlignment(.center)
                .foregroundColor(.element.primaryContent)
                .padding(.bottom, 2)
                .accessibilityIdentifier(A11yIdentifiers.analyticsPromptScreen.title)
            
            Text(context.viewState.strings.optInContent)
                .font(.compound.bodyLG)
                .multilineTextAlignment(.center)
                .foregroundColor(.element.secondaryContent)
                .tint(.element.links)
            
            Divider()
                .background(Color.element.quinaryContent)
                .padding(.vertical, 20)
            
            checkmarkList
        }
    }
    
    /// The list of re-assurances about analytics.
    private var checkmarkList: some View {
        VStack(alignment: .leading, spacing: 8) {
            AnalyticsPromptScreenCheckmarkItem(attributedString: context.viewState.strings.point1)
            AnalyticsPromptScreenCheckmarkItem(attributedString: context.viewState.strings.point2)
            AnalyticsPromptScreenCheckmarkItem(string: context.viewState.strings.point3)
        }
        .fixedSize(horizontal: false, vertical: true)
        .font(.compound.bodyLG)
        .foregroundColor(.element.secondaryContent)
        .frame(maxWidth: .infinity)
    }
    
    /// The stack of enable/disable buttons.
    private var buttons: some View {
        VStack {
            Button { context.send(viewAction: .enable) } label: {
                Text(L10n.actionEnable)
                    .font(.compound.bodyLGSemibold)
            }
            .buttonStyle(.elementAction(.xLarge))
            .accessibilityIdentifier(A11yIdentifiers.analyticsPromptScreen.enable)
            
            Button { context.send(viewAction: .disable) } label: {
                Text(L10n.actionNotNow)
                    .font(.compound.bodyLGSemibold)
                    .padding(12)
            }
            .accessibilityIdentifier(A11yIdentifiers.analyticsPromptScreen.notNow)
        }
    }
}

// MARK: - Previews

struct AnalyticsPromptScreen_Previews: PreviewProvider {
    static let viewModel = AnalyticsPromptScreenViewModel()
    static var previews: some View {
        AnalyticsPromptScreen(context: viewModel.context)
    }
}
