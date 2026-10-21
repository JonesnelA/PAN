//
//  Theme.swift
//  盘 PAN
//
//  一块精密的金属。没有品牌色，只有钢、光、黑，和一点点黄铜。
//

import SwiftUI

enum Palette {
    static let bg          = Color(hex: 0x050506)
    static let bgLift      = Color(hex: 0x0C0D10)
    static let steelBright = Color(white: 0.94)
    static let steel       = Color(white: 0.58)
    static let steelDim    = Color(white: 0.24)
    static let ink         = Color(white: 0.055)
    static let brass       = Color(hex: 0xC9A227)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
