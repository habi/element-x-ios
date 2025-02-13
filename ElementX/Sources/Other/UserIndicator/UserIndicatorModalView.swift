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

struct UserIndicatorModalView: View {
    let indicator: UserIndicator
    @State private var progressFraction: Double?

    var body: some View {
        ZStack {
            VStack(spacing: 12.0) {
                if let progressFraction {
                    ProgressView(value: progressFraction)
                } else {
                    ProgressView()
                }

                HStack {
                    if let iconName = indicator.iconName {
                        Image(systemName: iconName)
                    }
                    Text(indicator.title)
                        .font(.compound.bodyLG)
                        .foregroundColor(.element.primaryContent)
                }
            }
            .padding()
            .frame(minWidth: 150.0)
            .fixedSize(horizontal: true, vertical: false)
            .background(Color.element.quinaryContent)
            .clipShape(RoundedCornerShape(radius: 12.0, corners: .allCorners))
            .shadow(color: .black.opacity(0.1), radius: 10.0, y: 4.0)
            .onReceive(indicator.progressPublisher?.publisher ?? Empty().eraseToAnyPublisher()) { progress in
                progressFraction = progress
            }
            .transition(.opacity)
        }
        .id(indicator.id)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.1))
        .ignoresSafeArea()
    }
}

struct UserIndicatorModalView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UserIndicatorModalView(indicator: UserIndicator(type: .modal,
                                                            title: "Successfully logged in",
                                                            iconName: "checkmark")
            )
            .previewDisplayName("Spinner")
            UserIndicatorModalView(indicator: UserIndicator(type: .modal,
                                                            title: "Successfully logged in",
                                                            iconName: "checkmark",
                                                            progressPublisher: ProgressTracker(initialValue: 0.5))
            )
            .previewDisplayName("Progress Bar")
        }
    }
}
