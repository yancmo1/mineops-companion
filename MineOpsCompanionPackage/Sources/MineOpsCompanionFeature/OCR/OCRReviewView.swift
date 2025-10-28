import PhotosUI
import SwiftUI
import UIKit

struct OCRReviewView: View {
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var importError: String?
    @State private var progressMessage: String?
    @StateObject private var ocr = OCRProcessor()

    var body: some View {
        VStack(spacing: 16) {
            PhotosPicker("Select Screenshots", selection: $selectedPhotos, matching: .images, photoLibrary: .shared())
                .photosPickerAccessoryVisibility(.visible)
                .onChange(of: selectedPhotos, initial: false) { _, _ in
                    Task { @MainActor in await importSelected() }
                }
                .accessibilityIdentifier("selectScreenshotsButton")

            if let progressMessage {
                Text(progressMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("importProgressLabel")
            }

            if let importError {
                Text(importError)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("importErrorLabel")
            }

            List(ocr.results) { result in
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.parsedName)
                        .font(.headline)
                    Text("Level \(result.parsedLevel)   +\(Int(result.parsedBoost))% \(result.parsedBoostType)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("ocrResultRow_\(result.id.uuidString)")
            }
            .overlay { if isImporting { ProgressView().progressViewStyle(.circular) } }
        }
        .padding()
        .navigationTitle("Import & Review")
    }

    @MainActor
    private func importSelected() async {
        guard !selectedPhotos.isEmpty else { return }
        isImporting = true
        importError = nil
        progressMessage = "Importing \(selectedPhotos.count) screenshot(s)…"

        defer {
            isImporting = false
            progressMessage = nil
        }

        for item in selectedPhotos {
            do {
                guard let data = try await item.loadTransferable(type: Data.self), let img = UIImage(data: data) else {
                    throw ImportError.decodeFailed
                }
                await ocr.processImages([img])
            } catch {
                importError = "Failed to import one or more screenshots."
            }
        }
    }
}

private enum ImportError: Error {
    case decodeFailed
}
