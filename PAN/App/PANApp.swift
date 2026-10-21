//
//  PANApp.swift
//  盘 PAN
//
//  没有网络、没有权限、没有音频、没有本地化。
//  整个 App 只有一层界面，进来就能摸。
//

import SwiftUI

@main
struct PANApp: App {

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
