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

    /// PostScript names of the bundled faces. IM Fell is the chart's display face
    /// (italic for titles and star names, roman for the lede and the key). DM Mono is the data face.
    static let displayItalicName = "IM_FELL_English_Italic"
    static let displayRomanName = "IM_FELL_English_Roman"
    static let monoRegularName = "DMMono-Regular"
    static let monoMediumName = "DMMono-Medium"

    static let scrim = Color(red: 4 / 255, green: 9 / 255, blue: 20 / 255)
    static let veil = Color(red: 2 / 255, green: 6 / 255, blue: 18 / 255)

    static func display(_ size: Double, italic: Bool = true) -> Font {
        .custom(italic ? displayItalicName : displayRomanName, size: size)
    }

    static func mono(_ size: Double, weight: Font.Weight = .regular) -> Font {
        .custom(weight == .regular ? monoRegularName : monoMediumName, size: size)
    }

    static func points(_ value: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: "en_GB")))
    }
}
