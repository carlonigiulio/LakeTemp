//
//  WindService.swift
//  LakeTemp
//
//  Modello dati + chiamate all'API del vento (/wind e /wind/past_data/{range}).
//

import Foundation

/// Risposta di /wind, es: { "date": "2026-08-08 17:30:00", "speed": 10.4, "direction": 214, "gust": 26.3 }
struct WindReading: Decodable {
    let date: String
    let speed: Double
    let direction: Double?
    let gust: Double?

    /// Velocità in km/h senza unità, es. "10.4".
    var displaySpeed: String {
        String(format: "%.1f", speed)
    }

    /// Provenienza per esteso, es. "da Sud-Ovest · 214°".
    var originDescription: String {
        guard let direction else { return "Direzione non disponibile" }
        return "da \(Wind.cardinalName(for: direction)) · \(Int(direction.rounded()))°"
    }

    /// Rotazione della freccia: la direzione è di provenienza, la freccia
    /// indica dove il vento sta andando, quindi ruota di mezzo giro.
    var arrowRotation: Double {
        guard let direction else { return 0 }
        return (direction + 180).truncatingRemainder(dividingBy: 360)
    }

    /// Descrizione Beaufort, es. "Brezza leggera".
    var strengthDescription: String {
        Wind.beaufortName(forKilometersPerHour: speed)
    }

    /// Raffica formattata, nil se il dato manca.
    var gustText: String? {
        gust.map { String(format: "Raffiche %.0f km/h", $0) }
    }

    /// Istante della misura (formato "yyyy-MM-dd HH:mm:ss", ora locale).
    var measuredAt: Date? {
        WindReading.formatter.date(from: date)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

/// Un punto aggregato dello storico vento.
struct WindHistoryPoint: Decodable {
    let date: String
    let speed: Double
    let direction: Double?
    let gust: Double?

    /// Gestisce sia "yyyy-MM-dd HH:mm:ss" sia "yyyy-MM-dd".
    var parsedDate: Date? {
        WindHistoryPoint.dateTimeFormatter.date(from: date)
            ?? WindHistoryPoint.dateOnlyFormatter.date(from: date)
    }

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

/// Risposta di /wind/past_data/{range}.
struct WindHistoryResponse: Decodable {
    let ok: Bool
    let range: String
    let count: Int
    let data: [WindHistoryPoint]
}

enum WindService {
    /// Vento istantaneo.
    static func fetchCurrent() async throws -> WindReading {
        var request = URLRequest(url: apiURL.appendingPathComponent("wind"))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(WindReading.self, from: data)
    }

    /// Storico della velocità del vento, pronto per il grafico.
    static func trend(_ range: HistoryRange) async throws -> [TrendPoint] {
        let url = apiURL
            .appendingPathComponent("wind")
            .appendingPathComponent("past_data")
            .appendingPathComponent(range.rawValue)

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(WindHistoryResponse.self, from: data)

        return decoded.data
            .compactMap { point in
                point.parsedDate.map { TrendPoint(date: $0, value: point.speed) }
            }
            .sorted { $0.date < $1.date }
    }
}

/// Conversioni sui valori di vento: calcoli puri, nessuno stato condiviso.
nonisolated enum Wind {
    private static let cardinalNames = [
        "Nord", "Nord-Nord-Est", "Nord-Est", "Est-Nord-Est",
        "Est", "Est-Sud-Est", "Sud-Est", "Sud-Sud-Est",
        "Sud", "Sud-Sud-Ovest", "Sud-Ovest", "Ovest-Sud-Ovest",
        "Ovest", "Ovest-Nord-Ovest", "Nord-Ovest", "Nord-Nord-Ovest"
    ]

    /// Indice del settore da 22,5° più vicino.
    private static func sector(for degrees: Double) -> Int {
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        return Int((positive / 22.5).rounded()) % 16
    }

    static func cardinalName(for degrees: Double) -> String {
        cardinalNames[sector(for: degrees)]
    }

    /// Grado Beaufort corrispondente, dai limiti in km/h della scala.
    static func beaufortName(forKilometersPerHour speed: Double) -> String {
        switch speed {
        case ..<1:    return "Calma"
        case ..<6:    return "Bava di vento"
        case ..<12:   return "Brezza leggera"
        case ..<20:   return "Brezza tesa"
        case ..<29:   return "Vento moderato"
        case ..<39:   return "Vento teso"
        case ..<50:   return "Vento fresco"
        case ..<62:   return "Vento forte"
        case ..<75:   return "Burrasca"
        case ..<89:   return "Burrasca forte"
        case ..<103:  return "Tempesta"
        case ..<118:  return "Tempesta violenta"
        default:      return "Uragano"
        }
    }
}
