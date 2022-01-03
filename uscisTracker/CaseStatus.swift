//
//  CaseStatus.swift
//  uscisTracker
//
//  Created by ### on 12/31/21.
//

import Foundation
import SwiftUI

struct CaseStatus: Identifiable, Codable, Hashable {
    let id: String
    var status: String
    var date: String
}
