//
//  ContentView.swift
//  uscisTracker
//
//  Created by ### on 12/29/21.
//

import SwiftUI
import Foundation
import SwiftSoup
import BackgroundTasks
import UserNotifications

private let factory = UserDefaults.standard
private let userNotificationCenter = UNUserNotificationCenter.current()

struct ContentView: View {
    @EnvironmentObject var csStore: CaseStatusStore
    @State private var caseRef: String = ""
    @State private var isLoading = false
    @State private var isAddError = false
    var body: some View {
        VStack {
            
            
            Text("Enter your USCIS case number")
                .padding()
            
            GeometryReader { metrics in
                HStack {
                    TextField("Case number", text: $caseRef)
                        .accessibilityIdentifier("inputCaseRef")
                        .frame(width: metrics.size.width*0.6)
                        .padding()
                        .overlay(ProgressView()
                                    .padding()
                                    .cornerRadius(10)
                                    .shadow(radius: 10)
                                    .opacity(isLoading ? 1 : 0))
                    Spacer()
                        
                    Button("Track") {
                        isLoading = true
                        Thread.detachNewThread {
                            if !csStore.add(caseRef: caseRef)  {
                                isAddError = true
                            }
                            isLoading = false
                        }
                        
                    }.alert(isPresented: $isAddError) {
                        Alert(title: Text("Case cannot be added"), message: Text("Invalid case number or already tracking"), dismissButton: .default(Text("OK")))
                    }
                }
                
            }.frame(height:30)
            List {
                ForEach(csStore.cases) { existing in
                    VStack(alignment: .leading) {
                        HStack(alignment: .top) {
                            Text(existing.status)
                            Spacer()
                            Button("x") {
                                csStore.remove(caseRef: existing.id)
                            }.foregroundColor(.red)
                        }
                        
                        Text(existing.date+" / "+existing.id)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
            }
            
            
        }
        
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
        
        let request = UNNotificationRequest(identifier: "statusUpdate", content: pushContent, trigger: trigger)
        userNotificationCenter.add(request) { err in
            if let err = err {
                print("[Error] Request notification failed: \(err)")
            }
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
