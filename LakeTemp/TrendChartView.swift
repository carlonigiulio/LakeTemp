//
//  TrendChartView.swift
//  LakeTemp
//
//  Grafico storico con selettore Giorno/Settimana/Mese, condiviso da
//  temperatura dell'acqua e velocità del vento.
//

import SwiftUI
import Charts

/// Un punto del grafico, indipendente dalla metrica rappresentata.
struct TrendPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

struct TrendChartView: View {
    let title: String

    /// Etichette dell'asse Y, es. "21,6°" oppure "12".
    let axisLabel: (Double) -> String

    /// Caricamento dei punti per il range selezionato.
    let load: (HistoryRange) async throws -> [TrendPoint]

    /// Vero per le grandezze che non possono scendere sotto zero (il vento).
    var clampsToZero = false

    /// Cambia questo valore dall'esterno per forzare un ricaricamento.
    var reloadToken: Int = 0

    @State private var range: HistoryRange = .daily
    @State private var points: [TrendPoint] = []
    @State private var isLoading = false
    @State private var failed = false
    @State private var drawProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            rangePicker

            chartContent
                .frame(height: 200)
        }
        .lakeCard()
        .task(id: "\(range.rawValue)-\(reloadToken)") { await loadPoints() }
    }

    /// Selettore personalizzato (leggibile su sfondo scuro).
    private var rangePicker: some View {
        HStack(spacing: 0) {
            ForEach(HistoryRange.allCases) { r in
                let selected = r == range
                Text(r.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? Color(red: 0.08, green: 0.30, blue: 0.52) : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if selected {
                            Capsule().fill(.white)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { range = r }
                    }
            }
        }
        .padding(4)
        .background(.white.opacity(0.15), in: Capsule())
    }

    @ViewBuilder
    private var chartContent: some View {
        if isLoading {
            centered { ProgressView().tint(.white) }
        } else if failed {
            centered {
                Label("Dati non disponibili", systemImage: "chart.line.downtrend.xyaxis")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.footnote)
            }
        } else if points.count < 2 {
            centered {
                Text("Dati insufficienti per il grafico")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.footnote)
            }
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Data", point.date),
                yStart: .value("Min", yBounds.lowerBound),
                yEnd: .value(title, point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                .linearGradient(
                    colors: [.white.opacity(0.35), .white.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Data", point.date),
                y: .value(title, point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.white)
            .lineStyle(StrokeStyle(lineWidth: 2.5))

            PointMark(
                x: .value("Data", point.date),
                y: .value(title, point.value)
            )
            .foregroundStyle(.white)
            .symbolSize(28)
        }
        .chartYScale(domain: yBounds)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.15))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(axisLabel(v))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.1))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: xAxisFormat)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        // Effetto "disegno": la maschera si allarga da sinistra a destra.
        .mask(alignment: .leading) {
            GeometryReader { geo in
                Rectangle()
                    .frame(width: geo.size.width * drawProgress + 5)
            }
        }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Estremi Y con un po' di margine sopra e sotto.
    private var yBounds: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let low = values.min(), let high = values.max() else { return 0...30 }
        let padding = Swift.max((high - low) * 0.2, 0.5)
        let lower = clampsToZero ? Swift.max(0, low - padding) : low - padding
        return lower...(high + padding)
    }

    /// Formato dell'asse X in base al range.
    private var xAxisFormat: Date.FormatStyle {
        let italian = Locale(identifier: "it_IT")
        switch range {
        case .daily:
            return .dateTime.hour().minute().locale(italian)
        case .weekly:
            return .dateTime.weekday(.abbreviated).hour().minute().locale(italian)
        case .monthly:
            return .dateTime.day().month(.abbreviated).locale(italian)
        }
    }

    private func loadPoints() async {
        isLoading = true
        failed = false
        drawProgress = 0
        do {
            points = try await load(range)
        } catch {
            points = []
            failed = true
        }
        isLoading = false
        // Avvia l'animazione di disegno quando ci sono dati sufficienti.
        if points.count >= 2 {
            withAnimation(.easeOut(duration: 0.9)) { drawProgress = 1 }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(red: 0.13, green: 0.45, blue: 0.72),
                     Color(red: 0.05, green: 0.22, blue: 0.42)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()

        TrendChartView(
            title: "Andamento",
            axisLabel: { String(format: "%.1f°", $0) },
            load: HistoryService.trend
        )
        .padding()
    }
}
