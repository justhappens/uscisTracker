//
//  CaseStatusStore.swift
//  uscisTracker
//
//  Created by ### on 12/31/21.
//

import Foundation
import Combine
import SwiftSoup
import UserNotifications
import BackgroundTasks
import UIKit

private let BG_IDENTIFIER = "com.uscisTracker.refresh"
private let userNotificationCenter = UNUserNotificationCenter.current()

private let FACTORY = UserDefaults.standard
private let ENCODER = JSONEncoder()
private let DECODER = JSONDecoder()

final class CaseStatusStore: ObservableObject {
    @Published var cases:[CaseStatus] = load()
    
    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BG_IDENTIFIER, using: nil) { task in
            self.executeBGTask(task: task as! BGAppRefreshTask)
        }
    }
    func add(caseRef:String)->Bool {
        var found = false
        if let ids = FACTORY.string(forKey: "keys") {
            for existing in ids.split(separator: "|") {
                if caseRef == existing {
                    found = true
                    break
                }
            }
        }
        
        if !found {
            requestPushPermission()
            let newCase = CaseStatus(id: caseRef, status: "", date: "")
            
            if let updated = check(theCase: newCase) {
                cases.append(updated)
                save(cases: cases)
                return true
            } else {
                return false
            }
        } else {
            return false
        }
            
    }
    
    func check(caseRef: String) ->CaseStatus? {
        if let theCase = readCase(caseRef: caseRef) {
            return check(theCase: theCase)
        }
        return nil
    }
    func check(theCase: CaseStatus) -> CaseStatus? {
        do {
            let url = URL(string:"https://egov.uscis.gov/casestatus/mycasestatus.do?appReceiptNum=\(theCase.id)")!
//            print(url)
            let html = try String(contentsOf: url)
            let document = try SwiftSoup.parse(html)
            let heading = try document.select(".rows.text-center > h1").first()
            let content = try document.select(".rows.text-center > p").first()
            if let heading = heading, let content = content {
                let headingHTML = try heading.html()
                let contentHTML = try content.html()
                if let idx = contentHTML.firstIndex(of: ",") {
                    let newDate = String(contentHTML.prefix(upTo: idx))
                    if newDate != theCase.date {
                        
                        let newCase = CaseStatus(id: theCase.id, status: headingHTML, date: newDate)
                        saveCase(theCase: newCase)
                        return newCase
                    }
                            
                }
                return nil
            } else {
                print("[Error] caseStatus-\(theCase.id)-1")
            }
        } catch {
            print("[Error] caseStatus-\(theCase.id)-2: \(error)")
        }
        return nil
    }
    func save(cases:[CaseStatus]) {
        var keys:[String] = []
        for existing in cases {
            let key = existing.id
            keys.append(key)
            saveCase(theCase: existing)
//            print(readCase(caseRef: key))
        }
        print("Current case:", keys.joined(separator: "|"))
        FACTORY.set(keys.joined(separator:"|"), forKey: "keys")
        
    }
    func remove(caseRef: String) {
        for i in 0...cases.count {
            if cases[i].id == caseRef {
                cases.remove(at: i)
                break
            }
        }
        save(cases: cases)
    }
    func createBGTask() {
        print("createBGTask")
        if UIApplication.shared.backgroundRefreshStatus != .available {
            print("Backgroudn refresh is unavailable!")
            
        } else {
            let request = BGAppRefreshTaskRequest(identifier: BG_IDENTIFIER)
            // Refresh every 2 hours
            request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
            
            do {
                try BGTaskScheduler.shared.submit(request)
                BGTaskScheduler.shared.getPendingTaskRequests { requests in
                    for request in requests {
                        print(request)
                    }
                }
            } catch {
                print("[Error] Failed scheduling app refresh \(error)")
            }
        }
    }
    func executeBGTask(task: BGAppRefreshTask) {
        print("executeBGTask")
        createBGTask()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        for existing in cases {
            if let newCase = check(theCase: existing) {
                createPush(content: newCase.id+" : "+newCase.status)
            }

        }
        createPush(content: "Test BG")
        task.setTaskCompleted(success: true)
    }
    func requestPushPermission() {
        let authOptions = UNAuthorizationOptions.init(arrayLiteral: .alert, .badge, .sound)
        userNotificationCenter.requestAuthorization(options: authOptions) { (success, error) in
            if let error = error {
                print("[Error] Request Push Permission failed: \(error)")
            }
        }
    }
    func createPush(content: String) {
        let pushContent = UNMutableNotificationContent()
        pushContent.title = "Status update"
        pushContent.body = content
        pushContent.badge = NSNumber(value: 1)
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(identifier: "statusUpdate"+String(Int.random(in: 1...10000)), content: pushContent, trigger: trigger)
        
        userNotificationCenter.add(request) { err in
            if let err = err {
                print("[Error] Request notification failed: \(err)")
            }
        }
        print("reqeust Push: \(content)")
        
    }

}
func load()->[CaseStatus] {
    let data = FACTORY.string(forKey: "keys")
//    print("***",data)
    var cases:[CaseStatus] = []
    if let keys = data?.split(separator: "|") {
        for key in keys {
            if let newCase = readCase(caseRef: String(key)) {
                cases.append(newCase)
            }
        }
    }
   
    return cases
}
func saveCase(theCase: CaseStatus) {
    do {
        let data = try ENCODER.encode(theCase)
        FACTORY.set(data, forKey: String(theCase.id))
    } catch {
        print("[Error] saveCase: Unable to encode: \(theCase)")
    }
}
func readCase(caseRef: String)->CaseStatus? {
    do {
        if let data = FACTORY.data(forKey: caseRef) {
            let theCase = try DECODER.decode(CaseStatus.self, from: data)
            return theCase
        }
    } catch {
        print("[Error] readCase: Unable to decode: \(caseRef)")
    }
    return nil
}
