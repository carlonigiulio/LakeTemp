//
//  ContentView.swift
//  LakeTemp
//
//  Created by Giulio Carloni on 08/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var reading: LakeTemperature?
    @State private var errorMessage: String?
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

            VStack(spacing: 24) {
                header
                    .padding(.bottom)
                HistoryChartView(reloadToken: reloadToken)
                refreshButton
                Spacer(minLength: 0)
            }
            .padding()
            VStack {
                Spacer()
                Text("© \(Calendar.current.component(.year, from: Date()).description) - Giulio Carloni")
            }
            .font(.footnote)
            .fontWeight(.medium)
            .foregroundStyle(.white.secondary)
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

    private var header: some View {
        VStack(spacing: 8) {
            Text("Lago di Garda")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Image(systemName: "thermometer.medium")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 4)

            if let errorMessage {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                // Dato reale oppure segnaposto "redacted" durante il caricamento.
                VStack(spacing: 8) {
                    Text(reading?.displayTemp ?? "00.00°")
                        .font(.system(size: 90, weight: .thin))
                        .foregroundStyle(.white)

                    Text("Temperatura dell'acqua")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    Text(updatedText)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 2)
                }
                .redacted(reason: reading == nil ? .placeholder : [])
            }
        }
        .padding(.top, 20)
    }

    /// Testo dell'ultimo aggiornamento (segnaposto se il dato non è ancora arrivato).
    private var updatedText: String {
        if let date = reading?.measuredAt {
            return "Aggiornato \(date.formatted(date: .omitted, time: .shortened))"
        }
        return "Aggiornato 00:00"
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            reading = try await LakeTempService.fetch()
        } catch {
            errorMessage = "Impossibile caricare la temperatura."
        }
        isLoading = false
    }
}

#Preview {
    ContentView()
}
