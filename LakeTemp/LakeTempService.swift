//
//  LakeTempService.swift
//  LakeTemp
//
//  Modello dati + chiamata all'API della temperatura del lago.
//

import Foundation

let apiURL = URL(string: "https://lake-temp.carloni.uk")!

/// Risposta JSON dell'API, es: { "temperature": 21.63, "date": "2026-07-08 23:03:52" }
struct LakeTemperature: Codable {
    let temperature: Double
    let date: String

    /// Valore numerico in °C.
    var celsius: Double { temperature }

    /// Testo grande in stile meteo, es. "21.6°".
    var displayTemp: String {
        String(format: "%.2f°", temperature)
    }

    /// Solo il numero, per le viste che mostrano l'unità di misura a parte.
    var displayValue: String {
        String(format: "%.2f", temperature)
    }

    /// Quanto è avanzato l'anello della card, sulla stessa scala del widget.
    var gaugeFraction: Double {
        min(max(temperature / 30, 0), 1)
    }

    /// Data dell'ultima misurazione (formato "yyyy-MM-dd HH:mm:ss").
    var measuredAt: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.date(from: date)
    }
}

/// Scarica la temperatura corrente dall'API.
enum LakeTempService {
    static func fetch() async throws -> LakeTemperature {
        var request = URLRequest(url: apiURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(LakeTemperature.self, from: data)
    }
}
