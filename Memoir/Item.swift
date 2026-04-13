//
//  Item.swift
//  Memoir
//
//  Created by 法伍 on 2026/4/13.
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
