//
//  ContentView.swift
//  LakeTemp
//
//  Created by Giulio Carloni on 08/07/2026.
//

import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var reading: LakeTemperature?
    @State private var wind: WindReading?
    @State private var errorMessage: String?
    @State private var windFailed = false
    @State private var isLoading = false
    @State private var reloadToken = 0

    var body: some View {
        ZStack {
            // Sfondo gradiente stile meteo (azzurro lago).
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.45, blue: 0.72),
                         Color(red: 0.05, green: 0.22, blue: 0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Lago di Garda")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 4)

                    temperatureCard

                    TrendChartView(
                        title: "Andamento temperatura",
                        axisLabel: { String(format: "%.1f°", $0) },
                        load: HistoryService.trend,
                        reloadToken: reloadToken
                    )

                    windCard

                    TrendChartView(
                        title: "Andamento vento",
                        axisLabel: { String(format: "%.0f", $0) },
                        load: WindService.trend,
                        clampsToZero: true,
                        reloadToken: reloadToken
                    )

                    refreshButton
                        .padding(.top, 4)

                    Text("© \(Calendar.current.component(.year, from: Date()).description) - Giulio Carloni")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
        }
        .task { await load() }
    }

    private var refreshButton: some View {
        Button {
            reloadToken += 1
            Task { await load() }
        } label: {
            Label("Aggiorna", systemImage: "arrow.clockwise")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.white.opacity(0.15), in: Capsule())
        }
        .disabled(isLoading)
    }

    // MARK: - Temperatura

    private var temperatureCard: some View {
        CurrentValueCard(
            title: "Temperatura dell'acqua",
            value: reading?.displayValue ?? "00.00",
            unit: "°C",
            details: temperatureDetails,
            isPlaceholder: reading == nil,
            failureMessage: errorMessage,
            failureIcon: "wifi.exclamationmark"
        ) {
            // Anello sulla stessa scala 0–30 °C usata dal widget.
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: reading?.gaugeFraction ?? 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: reading?.gaugeFraction)

                Image(systemName: "drop.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
            .frame(width: 80, height: 80)
        }
    }

    private var temperatureDetails: [String] {
        return [updatedText]
    }

    /// Testo dell'ultimo aggiornamento (segnaposto se il dato non è ancora arrivato).
    private var updatedText: String {
        if let date = reading?.measuredAt {
            return "Aggiornato \(date.formatted(date: .omitted, time: .shortened))"
        }
        return "Aggiornato 00:00"
    }

    // MARK: - Vento

    private var windCard: some View {
        CurrentValueCard(
            title: "Vento",
            value: wind?.displaySpeed ?? "00.0",
            unit: "km/h",
            details: windDetails,
            isPlaceholder: wind == nil,
            failureMessage: windFailed ? "Dato non disponibile" : nil,
            failureIcon: "wind"
        ) {
            // Rosa dei venti: la freccia punta verso dove il vento sta soffiando.
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 1.5)

                compassLabel("N", y: -32)
                compassLabel("E", x: 32)
                compassLabel("S", y: 32)
                compassLabel("O", x: -32)

                Image(systemName: "location.north.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(wind?.arrowRotation ?? 0))
                    .animation(.easeInOut(duration: 0.4), value: wind?.arrowRotation)
            }
            .frame(width: 80, height: 80)
        }
    }

    /// Lettera della rosa dei venti, sempre dritta a prescindere da dove sta.
    private func compassLabel(_ text: String, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.55))
            .offset(x: x, y: y)
    }

    private var windDetails: [String] {
        guard let wind else { return ["da Nord · 0°", "Calma", "Aggiornato 00:00"] }

        var lines = [wind.originDescription, wind.strengthDescription]
        if let gustText = wind.gustText { lines.append(gustText) }
        lines.append(windUpdatedText)
        return lines
    }

    /// Ora dell'ultima misurazione del vento salvata dal cron.
    private var windUpdatedText: String {
        if let date = wind?.measuredAt {
            return "Aggiornato \(date.formatted(date: .omitted, time: .shortened))"
        }
        return "Aggiornato 00:00"
    }

    // MARK: - Rete

    private func load() async {
        isLoading = true
        errorMessage = nil
        windFailed = false

        // Le due sorgenti sono indipendenti: un errore sul vento non deve
        // nascondere la temperatura, e viceversa.
        async let temperature = LakeTempService.fetch()
        async let currentWind = WindService.fetchCurrent()

        do {
            reading = try await temperature
            // Forza l'aggiornamento dei widget con il nuovo dato.
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = "Impossibile caricare la temperatura."
        }

        do {
            wind = try await currentWind
        } catch {
            wind = nil
            windFailed = true
        }

        isLoading = false
    }
}

/// Card di un dato attuale: emblema tondo a sinistra, valore grande e righe di
/// dettaglio a destra. La prima riga di dettaglio è la più in evidenza.
private struct CurrentValueCard<Emblem: View>: View {
    let title: String
    let value: String
    let unit: String
    let details: [String]

    /// Vero mentre il dato non è ancora arrivato: mostra i segnaposto.
    let isPlaceholder: Bool

    /// Se valorizzato prende il posto del contenuto.
    let failureMessage: String?
    let failureIcon: String

    @ViewBuilder let emblem: Emblem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            if let failureMessage {
                Label(failureMessage, systemImage: failureIcon)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                HStack(spacing: 20) {
                    emblem

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(value)
                                .font(.system(size: 44, weight: .thin))
                            Text(unit)
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        ForEach(Array(details.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(index == 0 ? .subheadline : .footnote)
                                .foregroundStyle(.white.opacity(index == 0 ? 0.85 : 0.7))
                        }
                    }

                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .redacted(reason: isPlaceholder ? .placeholder : [])
            }
        }
        .lakeCard()
    }
}

#Preview {
    ContentView()
}
