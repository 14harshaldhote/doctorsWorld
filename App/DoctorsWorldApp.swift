import SwiftUI

@main
struct DoctorsWorldApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

/// Switches between the title, the shift and the results.
struct RootView: View {
    let model: AppModel

    var body: some View {
        ZStack {
            switch model.screen {
            case .title:
                TitleView(model: model)
                    .transition(.opacity)
            case .shift:
                if let controller = model.shiftController {
                    ShiftView(controller: controller)
                        .id(ObjectIdentifier(controller))
                        .transition(.move(edge: .trailing))
                }
            case .results:
                if let result = model.lastResult {
                    ResultsView(result: result, onNextShift: { model.startShift() }, onTitle: { model.backToTitle() })
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(duration: 0.45), value: model.screen)
    }
}
