import SwiftUI

@main
struct NeckBalloonApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(app)
                .task { await app.onLaunch() }
                .onAppear {
                    // CI のスクリーンショット用（起動引数 -screenshotScene <名前>）
                    if let scene = UserDefaults.standard.string(forKey: "screenshotScene") {
                        app.applyScreenshotScene(scene)
                    } else if ProcessInfo.processInfo.arguments.contains("-demo") {
                        // YouTube の録画用：人の操作なしで主な流れを再生する（保存しない）
                        app.runDemo()
                    }
                }
        }
    }
}
