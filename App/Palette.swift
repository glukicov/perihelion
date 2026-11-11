import SwiftUI

struct RGB: Sendable {
    var r: Double
    var g: Double
    var b: Double

    var color: Color { Color(red: r / 255, green: g / 255, blue: b / 255) }

    func mix(_ other: RGB, _ t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }
}

struct Tint: Sendable {
    var ground: RGB
    var ink: RGB

    func mix(_ other: Tint, _ t: Double) -> Tint {
        Tint(ground: ground.mix(other.ground, t), ink: ink.mix(other.ink, t))
    }
}

enum Palette {
    static let chalk = Color(red: 237 / 255, green: 242 / 255, blue: 244 / 255)
    static let chalkDim = chalk.opacity(0.64)
    static let comet = Color(red: 244 / 255, green: 201 / 255, blue: 93 / 255)
    static let ember = Color(red: 255 / 255, green: 138 / 255, blue: 102 / 255)
    static let ice = Color(red: 169 / 255, green: 220 / 255, blue: 255 / 255)

    static let tints: [Tint] = [
        Tint(ground: RGB(r: 17, g: 49, b: 94), ink: RGB(r: 8, g: 26, b: 58)),
        Tint(ground: RGB(r: 39, g: 35, b: 96), ink: RGB(r: 19, g: 15, b: 56)),
        Tint(ground: RGB(r: 13, g: 70, b: 79), ink: RGB(r: 5, g: 38, b: 46)),
        Tint(ground: RGB(r: 72, g: 30, b: 48), ink: RGB(r: 40, g: 13, b: 25)),
        Tint(ground: RGB(r: 22, g: 28, b: 52), ink: RGB(r: 8, g: 11, b: 26)),
    ]

    static func display(_ size: Double) -> Font {
        .custom("IowanOldStyle-Italic", size: size)
    }

    static func mono(_ size: Double, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
