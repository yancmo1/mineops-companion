import PhotosUI
import SwiftUI
import UIKit

/// A more memory-efficient photo picker using PHPickerViewController directly.
/// This avoids the SwiftUI PhotosPicker memory issues when browsing Collections.
struct PHPhotosPicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    let selectionLimit: Int
    let onDismiss: () -> Void
    
    init(
        selectedImages: Binding<[UIImage]>,
        selectionLimit: Int = 0,
        onDismiss: @escaping () -> Void = {}
    ) {
        self._selectedImages = selectedImages
        self.selectionLimit = selectionLimit
        self.onDismiss = onDismiss
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit
        configuration.preferredAssetRepresentationMode = .compatible
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPhotosPicker
        
        init(_ parent: PHPhotosPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss immediately to free memory
            picker.dismiss(animated: true)
            
            guard !results.isEmpty else {
                parent.onDismiss()
                return
            }
            
            // Process images in background to avoid UI blocking
            Task {
                var images: [UIImage] = []
                
                for result in results {
                    if let image = await loadImage(from: result) {
                        images.append(image)
                    }
                }
                
                await MainActor.run {
                    self.parent.selectedImages = images
                    self.parent.onDismiss()
                }
            }
        }
        
        private func loadImage(from result: PHPickerResult) async -> UIImage? {
            let itemProvider = result.itemProvider
            
            guard itemProvider.canLoadObject(ofClass: UIImage.self) else {
                return nil
            }
            
            return await withCheckedContinuation { continuation in
                itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    if let error {
                        print("❌ Failed to load image: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    if let image = object as? UIImage {
                        // Downsample large images to reduce memory pressure
                        let maxDimension: CGFloat = 2048
                        if image.size.width > maxDimension || image.size.height > maxDimension {
                            let downsampledImage = image.downsampled(toMaxDimension: maxDimension)
                            continuation.resume(returning: downsampledImage)
                        } else {
                            continuation.resume(returning: image)
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
}

// MARK: - Image Downsampling

private extension UIImage {
    func downsampled(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        guard scale < 1 else { return self }
        
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
