import Foundation

public enum Tuning {
    public static let width = 400.0
    public static let anchor = 0.62
    public static let wall = 6.0
    public static let range = 540.0
    public static let step = 1.0 / 120.0
    public static let catchMargin = 5.0
    public static let starsPerPlate = 8
    public static let maxFlow = 7
    public static let lapGrace = 0.35
    public static let centre = 0.22
    public static let cameraRate = 4.5
    public static let tau = Double.pi * 2
}

public enum StarKind: String, Sendable, Codable {
    case sol, white, red, blue

    var radiusScale: Double {
        switch self {
        case .red: 1.3
        case .blue: 0.84
        case .sol, .white: 1
        }
    }

    var spinScale: Double {
        switch self {
        case .red: 0.8
        case .blue: 1.18
        case .sol, .white: 1
        }
    }

    var fuseScale: Double {
        self == .red ? 0.6 : 1
    }

    static func of(spectralClass cls: String) -> StarKind {
        guard let first = cls.first else { return .white }
        if "OB".contains(first) { return .blue }
        if "KM".contains(first) { return .red }
        return .white
    }
}
