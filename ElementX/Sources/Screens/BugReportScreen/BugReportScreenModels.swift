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
import UIKit

enum BugReportScreenViewModelAction {
    case cancel
    case submitStarted(progressTracker: ProgressTracker)
    case submitFinished
    case submitFailed(error: Error)
}

struct BugReportScreenViewState: BindableState {
    var screenshot: UIImage?
    var bindings: BugReportScreenViewStateBindings
    let isModallyPresented: Bool
}

struct BugReportScreenViewStateBindings {
    var reportText: String
    var sendingLogsEnabled: Bool
}

enum BugReportScreenViewAction {
    case cancel
    case submit
    case removeScreenshot
    case attachScreenshot(UIImage)
}
