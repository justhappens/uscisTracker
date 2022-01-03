//
//  uscisTrackerApp.swift
//  uscisTracker
//
//  Created by ### on 12/29/21.
//

import SwiftUI
import UserNotifications
import BackgroundTasks

private let BG_IDENTIFIER = "com.uscisTracker.refresh"

@main
struct uscisTrackerApp: App {
    @State private var csStore = CaseStatusStore()
//    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(csStore)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    UIApplication.shared.applicationIconBadgeNumber = 0
                    BGTaskScheduler.shared.getPendingTaskRequests { requests in
                        for request in requests {
                            print(request)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    UNUserNotificationCenter.current().getNotificationSettings { setting in
                        if setting.authorizationStatus == .authorized {
                            csStore.createBGTask()
                        }
                    }
                    
                }
            }
//        }.onChange(of: scenePhase) { (newScenePhase) in
//            switch newScenePhase {
//            case .active:
//                UIApplication().applicationIconBadgeNumber = 0
//            default:
//                print("App entered \(newScenePhase)")
//            }
//        }
    }
}
