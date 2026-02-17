//
//  Item.swift
//  sunnad-ios
//
//  Created by Alimkhan Yergebayev on 17/2/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
