//
//  LakeTempWidget.swift
//  LakeTempWidget
//

import WidgetKit
import SwiftUI

// MARK: - Modello + rete (copia autonoma per il widget)

private let apiURL = URL(string: "https://lake-temp.carloni.uk")!

// Intervallo usato per l'anello del widget tondo (min...max in °C).
private let gaugeRange: ClosedRange<Double> = 0...30

private struct LakeTemperature: Codable {
    let temperature: Double
    let date: String

    var celsius: Double { temperature }

    var displayTemp: String {
        String(format: "%.2f°", temperature)
    }

    var measuredAt: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.date(from: date)
    }
}

private func fetchTemperature() async -> LakeTemperature? {
    var request = URLRequest(url: apiURL)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    guard let (data, _) = try? await URLSession.shared.data(for: request),
          let reading = try? JSONDecoder().decode(LakeTemperature.self, from: data)
    else { return nil }
    return reading
}

// MARK: - Timeline

struct LakeEntry: TimelineEntry {
    let date: Date
    let celsius: Double?
    let displayTemp: String
    let measuredAt: Date?
}

struct Provider: TimelineProvider {
    private var sample: LakeEntry {
        LakeEntry(date: .now, celsius: 21.81, displayTemp: "21.8°", measuredAt: .now)
    }

    func placeholder(in context: Context) -> LakeEntry { sample }

    func getSnapshot(in context: Context, completion: @escaping (LakeEntry) -> Void) {
        completion(sample)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LakeEntry>) -> Void) {
        Task {
            let reading = await fetchTemperature()
            let entry = LakeEntry(
                date: .now,
                celsius: reading?.celsius,
                displayTemp: reading?.displayTemp ?? "--°",
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
private struct HomeView: View {
    let entry: LakeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.caption2)
                Text("Lago di Garda")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 0)

            Text(entry.displayTemp)
                .font(.system(size: 40, weight: .thin))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

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

/// Vista Lock Screen tonda: anello + temperatura al centro.
private struct CircularView: View {
    let entry: LakeEntry

    var body: some View {
        Gauge(value: entry.celsius ?? 0, in: gaugeRange) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text(entry.displayTemp)
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(.clear, for: .widget)
    }
}

/// Vista Lock Screen rettangolare: nome + temperatura + ora.
private struct RectangularView: View {
    let entry: LakeEntry

    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: "drop.fill")
            Text(entry.displayTemp)
                .font(.title3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }
}

/// Vista in linea (accanto all'orologio nella Lock Screen).
private struct InlineView: View {
    let entry: LakeEntry

    var body: some View {
        Label("Lago di Garda \(entry.displayTemp)", systemImage: "drop.fill")
    }
}

/// Sceglie la vista giusta in base alla famiglia del widget.
struct LakeTempWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: LakeEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularView(entry: entry)
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .accessoryInline:
            InlineView(entry: entry)
        default:
            HomeView(entry: entry)
        }
    }
}

// MARK: - Definizione widget

@main
struct LakeTempWidgetBundle: WidgetBundle {
    var body: some Widget {
        LakeTempWidget()
        LakeWindWidget()
    }
}

struct LakeTempWidget: Widget {
    let kind = "LakeTempWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LakeTempWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Temperatura Garda")
        .description("Temperatura dell'acqua del Lago di Garda.")
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
    LakeTempWidget()
} timeline: {
    LakeEntry(date: .now, celsius: 21.8, displayTemp: "21.8°", measuredAt: .now)
}

#Preview("Lock tondo", as: .accessoryCircular) {
    LakeTempWidget()
} timeline: {
    LakeEntry(date: .now, celsius: 21.8, displayTemp: "21.8°", measuredAt: .now)
}

#Preview("Lock rettangolare", as: .accessoryRectangular) {
    LakeTempWidget()
} timeline: {
    LakeEntry(date: .now, celsius: 21.8, displayTemp: "21.8°", measuredAt: .now)
}
