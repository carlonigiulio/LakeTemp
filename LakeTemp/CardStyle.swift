//
//  CardStyle.swift
//  LakeTemp
//
//  Contenitore condiviso dalle card della schermata (dati attuali e grafici).
//

import SwiftUI

extension View {
    /// Riquadro traslucido con angoli arrotondati, largo quanto la schermata.
    func lakeCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
    }
}
