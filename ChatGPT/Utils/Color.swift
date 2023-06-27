//
//  Color.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import Foundation
import SwiftUI

extension Color {
  #if canImport(AppKit)
  init(color: NSColor) {
    self.init(nsColor: color)
  }
  #else
  init(color: UIColor) {
    self.init(uiColor: color)
  }
  #endif
  
  static func rgb(red: Int, green: Int, blue: Int, opacity: Double = 1) -> Color {
    .init(
      .sRGB,
      red: Double(red) / 255.0, 
      green: Double(green) / 255.0, 
      blue: Double(blue) / 255.0,
      opacity: opacity
    )
  }
  
  static func hex(_ hex: Int, opacity: Double = 1) -> Color {
    rgb(
      red: (hex & 0xFF0000) >> 16,
      green: (hex & 0x00FF00) >> 8,
      blue: hex & 0x0000FF,
      opacity: opacity
    )
  }
  
  enum palette {
    static var background = Color.hex(0x1C1C1C)
    static var background1 = Color.hex(0x2A2A2A)
    static var background2 = Color.hex(0x3A3A3A)
    static var primaryText = Color.hex(0xE0E0E0)
    static var secondaryText = Color.hex(0xB0B0B0)
    static var accentColor = Color.hex(0x3B8BFF)
    static var accentColor2 = Color.hex(0x42D77D)
    static var accentColor3 = Color.hex(0xFF647C)
    static var accentColor4 = Color.hex(0xFFC833)
    static var accentColor5 = Color.hex(0x31C1A8)
    static var selectionBackgroundColor = Color.hex(0x4A90E2)
    static var selectionTextColor = Color.hex(0xFFFFFF)
  }
}
