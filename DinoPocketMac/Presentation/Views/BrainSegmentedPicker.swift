//
//  BrainSegmentedPicker.swift
//  Jarvis
//
//  Molecule: segmented picker over the available brain backends.
//

import SwiftUI

struct BrainSegmentedPicker: View {
    @Binding var selection: BrainKind

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(BrainKind.allCases) { kind in
                Text(kind.displayName).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

#Preview {
    BrainSegmentedPicker(selection: .constant(.ollama))
        .padding()
        .frame(width: 260)
}
