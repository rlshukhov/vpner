//
//  Item.swift
//  vpner
//
//  Created by Lane Shukhov on 14.07.2025.
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
