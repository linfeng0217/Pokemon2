import SwiftUI

/// PokéBonk — 个人用 WKWebView 封装壳
/// 游戏本体始终从 https://pokebonk.com/ 在线加载，本 App 不内嵌游戏资源。
@main
struct PokeBonkApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .preferredColorScheme(.dark)
        }
    }
}
