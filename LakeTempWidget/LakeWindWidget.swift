//
//  LakeWindWidget.swift
//  LakeTempWidget
//

import WidgetKit
import SwiftUI

// MARK: - Modello + rete (copia autonoma per il widget)

private let windURL = URL(string: "https://lake-temp.carloni.uk/wind")!

// Fondo scala dell'anello nel widget tondo (km/h): sul lago oltre i 50 si va
// di rado, e tenerlo basso rende leggibili le brezze di tutti i giorni.
private let windGaugeRange: ClosedRange<Double> = 0...50

private struct WindReading: Codable {
    let date: String
    let speed: Double
    let direction: Double?
    let gust: Double?

    /// Velocità con un decimale, es. "10.1".
    var displaySpeed: String {
        String(format: "%.1f", speed)
    }

    /// Velocità arrotondata, per gli spazi stretti della Lock Screen.
    var compactSpeed: String {
        String(format: "%.0f", speed)
    }

    /// Sigla del punto cardinale di provenienza, es. "SSO".
    var cardinal: String? {
        direction.map(cardinalPoint(for:))
    }

    var measuredAt: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: date)
    }
}

/// Settore da 22,5° più vicino, in sigla italiana.
private func cardinalPoint(for degrees: Double) -> String {
    let names = [
        "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
        "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO"
    ]
    let normalized = degrees.truncatingRemainder(dividingBy: 360)
    let positive = normalized < 0 ? normalized + 360 : normalized
    return names[Int((positive / 22.5).rounded()) % 16]
}

private func fetchWind() async -> WindReading? {
    var request = URLRequest(url: windURL)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    guard let (data, _) = try? await URLSession.shared.data(for: request),
          let reading = try? JSONDecoder().decode(WindReading.self, from: data)
    else { return nil }
    return reading
}

// MARK: - Timeline

struct WindEntry: TimelineEntry {
    let date: Date
    let speed: Double?
    let displaySpeed: String
    let compactSpeed: String
    let direction: Double?
    let cardinal: String
    let measuredAt: Date?

    /// La direzione è di provenienza, la freccia indica dove va il vento.
    var arrowRotation: Double {
        guard let direction else { return 0 }
        return (direction + 180).truncatingRemainder(dividingBy: 360)
    }
}

struct WindProvider: TimelineProvider {
    private var sample: WindEntry {
        WindEntry(
            date: .now,
            speed: 18,
            displaySpeed: "18.0",
            compactSpeed: "18",
            direction: 182,
            cardinal: "S",
            measuredAt: .now
        )
    }

    func placeholder(in context: Context) -> WindEntry { sample }

    func getSnapshot(in context: Context, completion: @escaping (WindEntry) -> Void) {
        completion(sample)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WindEntry>) -> Void) {
        Task {
            let reading = await fetchWind()
            let entry = WindEntry(
                date: .now,
                speed: reading?.speed,
                displaySpeed: reading?.displaySpeed ?? "--",
                compactSpeed: reading?.compactSpeed ?? "--",
                direction: reading?.direction,
                cardinal: reading?.cardinal ?? "--",
                measuredAt: reading?.measuredAt
            )
            // Aggiorna tra 30 minuti.
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

// MARK: - Viste

/// Vista Home Screen (piccolo/medio): stile meteo con sfondo azzurro.
private struct WindHomeView: View {
    let entry: WindEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "wind")
                    .font(.caption2)
                Text("Lago di Garda")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(entry.displaySpeed)
                    .font(.system(size: 36, weight: .thin))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("km/h")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(spacing: 4) {
                Image(systemName: "location.north.fill")
                    .font(.caption2)
                    .rotationEffect(.degrees(entry.arrowRotation))
                Text("da \(entry.cardinal)")
                    .font(.caption2)
            }
            .foregroundStyle(.white.opacity(0.8))

            if let date = entry.measuredAt {
                Text(date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.45, blue: 0.72),
                         Color(red: 0.05, green: 0.22, blue: 0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// Vista Lock Screen tonda: anello sulla velocità, freccia orientata come il vento.
private struct WindCircularView: View {
    let entry: WindEntry

    var body: some View {
        Gauge(value: min(entry.speed ?? 0, windGaugeRange.upperBound), in: windGaugeRange) {
            Image(systemName: "location.north.fill")
                .rotationEffect(.degrees(entry.arrowRotation))
        } currentValueLabel: {
            Text(entry.compactSpeed)
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(.clear, for: .widget)
    }
}

/// Vista Lock Screen rettangolare: freccia + velocità + provenienza.
private struct WindRectangularView: View {
    let entry: WindEntry

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "location.north.fill")
                .rotationEffect(.degrees(entry.arrowRotation))
            Text("\(entry.compactSpeed) km/h")
                .font(.title3)
            Text(entry.cardinal)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }
}

/// Vista in linea (accanto all'orologio nella Lock Screen).
private struct WindInlineView: View {
    let entry: WindEntry

    var body: some View {
        Label("Vento \(entry.compactSpeed) km/h \(entry.cardinal)", systemImage: "wind")
    }
}

/// Sceglie la vista giusta in base alla famiglia del widget.
struct LakeWindWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WindEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            WindCircularView(entry: entry)
        case .accessoryRectangular:
            WindRectangularView(entry: entry)
        case .accessoryInline:
            WindInlineView(entry: entry)
        default:
            WindHomeView(entry: entry)
        }
    }
}

// MARK: - Definizione widget

struct LakeWindWidget: Widget {
    let kind = "LakeWindWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WindProvider()) { entry in
            LakeWindWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Vento Garda")
        .description("Velocità e direzione del vento sul Lago di Garda.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

#Preview("Home", as: .systemSmall) {
    LakeWindWidget()
} timeline: {
    WindEntry(date: .now, speed: 18, displaySpeed: "18.0", compactSpeed: "18",
              direction: 182, cardinal: "S", measuredAt: .now)
}

#Preview("Lock tondo", as: .accessoryCircular) {
    LakeWindWidget()
} timeline: {
    WindEntry(date: .now, speed: 18, displaySpeed: "18.0", compactSpeed: "18",
              direction: 182, cardinal: "S", measuredAt: .now)
}

#Preview("Lock rettangolare", as: .accessoryRectangular) {
    LakeWindWidget()
} timeline: {
    WindEntry(date: .now, speed: 18, displaySpeed: "18.0", compactSpeed: "18",
              direction: 182, cardinal: "S", measuredAt: .now)
}
