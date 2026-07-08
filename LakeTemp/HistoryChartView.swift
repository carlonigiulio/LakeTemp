//
//  HistoryChartView.swift
//  LakeTemp
//
//  Grafico storico della temperatura con selettore Giorno/Settimana/Mese.
//

import SwiftUI
import Charts

struct HistoryChartView: View {
    /// Cambia questo valore dall'esterno per forzare un ricaricamento.
    var reloadToken: Int = 0

    @State private var range: HistoryRange = .daily
    @State private var points: [HistoryPoint] = []
    @State private var isLoading = false
    @State private var failed = false
    @State private var drawProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Andamento")
                .font(.headline)
                .foregroundStyle(.white)

            rangePicker

            chartContent
                .frame(height: 200)
        }
        .padding(16)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
        .task(id: "\(range.rawValue)-\(reloadToken)") { await load() }
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
            if let date = point.parsedDate {
                AreaMark(
                    x: .value("Data", date),
                    yStart: .value("Min", yBounds.lowerBound),
                    yEnd: .value("Temperatura", point.temperature)
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
                    x: .value("Data", date),
                    y: .value("Temperatura", point.temperature)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.white)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                PointMark(
                    x: .value("Data", date),
                    y: .value("Temperatura", point.temperature)
                )
                .foregroundStyle(.white)
                .symbolSize(28)
            }
        }
        .chartYScale(domain: yBounds)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.15))
                AxisValueLabel {
                    if let t = value.as(Double.self) {
                        Text("\(t, specifier: "%.1f")°")
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
        let temps = points.map(\.temperature)
        guard let min = temps.min(), let max = temps.max() else { return 0...30 }
        let padding = Swift.max((max - min) * 0.2, 0.5)
        return (min - padding)...(max + padding)
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

    private func load() async {
        isLoading = true
        failed = false
        drawProgress = 0
        do {
            points = try await HistoryService.fetch(range)
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
        HistoryChartView()
            .padding()
    }
}
