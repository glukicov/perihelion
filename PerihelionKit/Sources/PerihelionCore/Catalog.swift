public struct CatalogEntry: Sendable {
    public let name: String
    public let bayer: String
    public let spectralClass: String
    public let magnitude: Double
}

public enum Catalog {
    public static let stars: [CatalogEntry] = [
        .init(name: "Sol", bayer: "", spectralClass: "G2 V", magnitude: -26.74),
        .init(name: "Sirius", bayer: "α CMa", spectralClass: "A1 V", magnitude: -1.46),
        .init(name: "Canopus", bayer: "α Car", spectralClass: "A9 II", magnitude: -0.74),
        .init(name: "Rigil Kentaurus", bayer: "α Cen", spectralClass: "G2 V", magnitude: -0.27),
        .init(name: "Arcturus", bayer: "α Boo", spectralClass: "K1.5 III", magnitude: -0.05),
        .init(name: "Vega", bayer: "α Lyr", spectralClass: "A0 V", magnitude: 0.03),
        .init(name: "Capella", bayer: "α Aur", spectralClass: "G3 III", magnitude: 0.08),
        .init(name: "Rigel", bayer: "β Ori", spectralClass: "B8 Ia", magnitude: 0.13),
        .init(name: "Procyon", bayer: "α CMi", spectralClass: "F5 IV", magnitude: 0.34),
        .init(name: "Achernar", bayer: "α Eri", spectralClass: "B6 V", magnitude: 0.46),
        .init(name: "Betelgeuse", bayer: "α Ori", spectralClass: "M2 Iab", magnitude: 0.50),
        .init(name: "Hadar", bayer: "β Cen", spectralClass: "B1 III", magnitude: 0.61),
        .init(name: "Altair", bayer: "α Aql", spectralClass: "A7 V", magnitude: 0.76),
        .init(name: "Acrux", bayer: "α Cru", spectralClass: "B0.5 IV", magnitude: 0.76),
        .init(name: "Aldebaran", bayer: "α Tau", spectralClass: "K5 III", magnitude: 0.86),
        .init(name: "Antares", bayer: "α Sco", spectralClass: "M1.5 Iab", magnitude: 0.96),
        .init(name: "Spica", bayer: "α Vir", spectralClass: "B1 IV", magnitude: 0.97),
        .init(name: "Pollux", bayer: "β Gem", spectralClass: "K0 III", magnitude: 1.14),
        .init(name: "Fomalhaut", bayer: "α PsA", spectralClass: "A3 V", magnitude: 1.16),
        .init(name: "Deneb", bayer: "α Cyg", spectralClass: "A2 Ia", magnitude: 1.25),
        .init(name: "Mimosa", bayer: "β Cru", spectralClass: "B0.5 III", magnitude: 1.25),
        .init(name: "Regulus", bayer: "α Leo", spectralClass: "B8 IV", magnitude: 1.39),
        .init(name: "Adhara", bayer: "ε CMa", spectralClass: "B2 II", magnitude: 1.50),
        .init(name: "Castor", bayer: "α Gem", spectralClass: "A1 V", magnitude: 1.58),
        .init(name: "Shaula", bayer: "λ Sco", spectralClass: "B2 IV", magnitude: 1.62),
        .init(name: "Gacrux", bayer: "γ Cru", spectralClass: "M3.5 III", magnitude: 1.64),
        .init(name: "Bellatrix", bayer: "γ Ori", spectralClass: "B2 III", magnitude: 1.64),
        .init(name: "Elnath", bayer: "β Tau", spectralClass: "B7 III", magnitude: 1.65),
        .init(name: "Miaplacidus", bayer: "β Car", spectralClass: "A1 III", magnitude: 1.69),
        .init(name: "Alnilam", bayer: "ε Ori", spectralClass: "B0 Ia", magnitude: 1.69),
        .init(name: "Alnair", bayer: "α Gru", spectralClass: "B6 V", magnitude: 1.74),
        .init(name: "Alnitak", bayer: "ζ Ori", spectralClass: "O9.5 Iab", magnitude: 1.77),
        .init(name: "Alioth", bayer: "ε UMa", spectralClass: "A1 III", magnitude: 1.77),
        .init(name: "Dubhe", bayer: "α UMa", spectralClass: "K0 III", magnitude: 1.79),
        .init(name: "Mirfak", bayer: "α Per", spectralClass: "F5 Ib", magnitude: 1.80),
        .init(name: "Wezen", bayer: "δ CMa", spectralClass: "F8 Ia", magnitude: 1.82),
        .init(name: "Sargas", bayer: "θ Sco", spectralClass: "F1 II", magnitude: 1.84),
        .init(name: "Kaus Australis", bayer: "ε Sgr", spectralClass: "B9.5 III", magnitude: 1.85),
        .init(name: "Avior", bayer: "ε Car", spectralClass: "K3 III", magnitude: 1.86),
        .init(name: "Alkaid", bayer: "η UMa", spectralClass: "B3 V", magnitude: 1.86),
        .init(name: "Menkalinan", bayer: "β Aur", spectralClass: "A1 IV", magnitude: 1.90),
        .init(name: "Atria", bayer: "α TrA", spectralClass: "K2 II", magnitude: 1.91),
        .init(name: "Alhena", bayer: "γ Gem", spectralClass: "A1 IV", magnitude: 1.92),
        .init(name: "Peacock", bayer: "α Pav", spectralClass: "B2 IV", magnitude: 1.94),
        .init(name: "Alsephina", bayer: "δ Vel", spectralClass: "A1 V", magnitude: 1.96),
        .init(name: "Mirzam", bayer: "β CMa", spectralClass: "B1 II", magnitude: 1.98),
        .init(name: "Alphard", bayer: "α Hya", spectralClass: "K3 II", magnitude: 1.98),
        .init(name: "Polaris", bayer: "α UMi", spectralClass: "F7 Ib", magnitude: 1.98),
        .init(name: "Hamal", bayer: "α Ari", spectralClass: "K2 III", magnitude: 2.00),
    ]

    public static let nebulae = [
        "Coalsack", "Horsehead", "Pipe Nebula", "Snake Nebula", "Barnard 68", "Dark Doodad", "Northern Coalsack",
    ]

    public static let plates: [(name: String, rule: String)] = [
        ("Plate I", ""),
        ("Plate II", "Some stars drift"),
        ("Plate III", "Dark nebulae swallow comets"),
        ("Plate IV", "Faster drift, more nebulae"),
        ("Plate V", "Fainter and faster"),
        ("Plate VI", "The last charted stars"),
    ]

    public static let offChart = (name: "Off the chart", rule: "No one has named these")

    public static func starName(_ i: Int) -> String {
        i < stars.count ? stars[i].name : "Uncharted \(i)"
    }
}
