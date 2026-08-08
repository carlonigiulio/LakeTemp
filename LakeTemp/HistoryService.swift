//
//  HistoryService.swift
//  LakeTemp
//
//  Recupero dei dati storici di temperatura (/past_data/{range}).
//

import Foundation

/// I tre range disponibili dall'API storica.
enum HistoryRange: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    /// Etichetta mostrata nel selettore.
    var label: String {
        switch self {
        case .daily: return "Giorno"
        case .weekly: return "Settimana"
        case .monthly: return "Mese"
        }
    }
}

/// Un singolo punto aggregato del grafico.
struct HistoryPoint: Decodable, Identifiable {
    let date: String
    let temperature: Double

    var id: String { date }

    /// Data del bucket. Gestisce sia "yyyy-MM-dd HH:mm:ss" sia "yyyy-MM-dd".
    var parsedDate: Date? {
        HistoryPoint.dateTimeFormatter.date(from: date)
            ?? HistoryPoint.dateOnlyFormatter.date(from: date)
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

/// Risposta dell'endpoint /past_data/{range}.
struct HistoryResponse: Decodable {
    let ok: Bool
    let range: String
    let count: Int
    let data: [HistoryPoint]
}

enum HistoryService {
    /// Scarica i dati storici per il range indicato.
    /// Restituisce solo i punti con data valida, ordinati nel tempo.
    static func fetch(_ range: HistoryRange) async throws -> [HistoryPoint] {
        let url = apiURL.appendingPathComponent("past_data").appendingPathComponent(range.rawValue)
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(HistoryResponse.self, from: data)
        return decoded.data
            .filter { $0.parsedDate != nil }
            .sorted { ($0.parsedDate ?? .distantPast) < ($1.parsedDate ?? .distantPast) }
    }

    /// Gli stessi dati nel formato atteso dal grafico.
    static func trend(_ range: HistoryRange) async throws -> [TrendPoint] {
        try await fetch(range).compactMap { point in
            point.parsedDate.map { TrendPoint(date: $0, value: point.temperature) }
        }
    }
}
