//
//  ContentView.swift
//  arkynFeature
//
//  Created by Peter Hannibal Hildorf on 10/03/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var serverStatus: String = "Tjekker forbindelse..."
    @State private var isConnected: Bool = false
    @State private var isLoading: Bool = true

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(isConnected ? .green : .red)
                .font(.system(size: 60))

            Text("Arkyn Server")
                .font(.title)
                .bold()

            Text(serverStatus)
                .foregroundStyle(.secondary)

            if isLoading {
                ProgressView()
            }

            Button("Test forbindelse igen") {
                Task { await checkServer() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .task {
            await checkServer()
        }
    }

    private func checkServer() async {
        isLoading = true
        serverStatus = "Forbinder til server..."
        do {
            let ok = try await NetworkService.shared.checkHealth()
            isConnected = ok
            serverStatus = ok ? "Forbundet til localhost:8080 ✓" : "Server svarede ikke korrekt"
        } catch {
            isConnected = false
            serverStatus = "Fejl: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

#Preview {
    ContentView()
}
