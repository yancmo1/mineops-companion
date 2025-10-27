import SwiftUI
import PhotosUI

struct OCRReviewView: View {
    @StateObject private var ocr = OCRProcessor()
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        VStack {
            PhotosPicker("Select Screenshots", selection: $selectedPhotos, matching: .images, photoLibrary: .shared())
                .onChange(of: selectedPhotos) { _ in Task { await importSelected() } }

            List(ocr.results) { result in
                VStack(alignment: .leading) {
                    Text(result.parsedName).font(.headline)
                    Text("Level \(result.parsedLevel)   +\(Int(result.parsedBoost))% \(result.parsedBoostType)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .navigationTitle("Import & Review")
    }

    private func importSelected() async {
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                await ocr.processImages([img])
            }
        }
    }
}
