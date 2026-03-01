//
//  NotificationManager.swift
//  TestApp_New
//
//  Created by 渡邉羽唯 on 2026/02/26.
//

import Foundation

import Foundation
import UserNotifications

final class NotificationManager {
    
    static let shared = NotificationManager()
    
    private init() {}
    
    // 通知許可を取る
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    // 通知をスケジュール
    func scheduleNotification(at date: Date, completion: @escaping (Date?) -> Void) {

        guard let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: date),
              dayBefore > Date() else {
            completion(nil)
            return
        }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dayBefore
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let content = UNMutableNotificationContent()
        content.title = "Echo.Me"
        content.body = "明日の予定を忘れないでね！"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if error == nil {
                    completion(dayBefore)
                } else {
                    completion(nil)
                }
            }
        }
    }
}

