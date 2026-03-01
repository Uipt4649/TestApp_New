//
//  TestAppApp.swift
//  TestApp
//
//  Created by 渡邉羽唯 on 2025/12/21.
//

import SwiftUI

@main
struct TestAppApp: App {
    
    init() {
        NotificationManager.shared.requestPermission { granted in
            print("通知許可: \(granted)")
        }
    }

    var body: some Scene {
        WindowGroup {

            SelectView()
        }
    }
    
    
}


