//
//  ContentView.swift
//  slunk-swift
//
//  Created by June Kim on 2025-06-24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button("Trigger Action") {
                ButtonAction.perform()
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
