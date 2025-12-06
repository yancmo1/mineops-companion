import SwiftUI
import PhotosUI

struct IconAlignmentTransform: Equatable {
    var offset: CGSize = .zero
    var scale: CGFloat = 1.0
}

struct IconAlignmentView: View {
    let entry: HarvestEntry
    let initialTransform: IconAlignmentTransform
    let onSave: (HarvestEntry, IconAlignmentTransform) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var fullImage: UIImage?
    @State private var offset: CGSize
    @State private var lastOffset: CGSize
    @State private var scale: CGFloat
    @State private var lastScale: CGFloat
    @State private var displayedImageSize = CGSize.zero
    @State private var containerSize = CGSize.zero
    @State private var isMagnifying = false
    @State private var magnifyInitialOffset = CGSize.zero
    @State private var magnifyInitialScale: CGFloat
    
    private let cropSize: CGFloat = 200
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 8.0
    
    init(entry: HarvestEntry, initialTransform: IconAlignmentTransform = .init(), onSave: @escaping (HarvestEntry, IconAlignmentTransform) -> Void) {
        self.entry = entry
        self.initialTransform = initialTransform
        self.onSave = onSave
        _offset = State(initialValue: initialTransform.offset)
        _lastOffset = State(initialValue: initialTransform.offset)
        _scale = State(initialValue: initialTransform.scale)
        _lastScale = State(initialValue: initialTransform.scale)
        _magnifyInitialScale = State(initialValue: initialTransform.scale)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Align the Icon")
                    .font(.headline)
                    .foregroundStyle(Color.accentCyan)
                
                Text(fullImage == nil ? "Select the manager screenshot, then drag and pinch to align the icon within the crop box" : "Drag and pinch to align the icon within the crop box")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal)
                
                // Photo picker (only show if no image loaded)
                if fullImage == nil {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Select Manager Screenshot")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.mineDarkLight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal)
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                await MainActor.run {
                                    fullImage = image
                                    offset = .zero
                                    lastOffset = .zero
                                    magnifyInitialOffset = .zero
                                    magnifyInitialScale = scale
                                    lastScale = scale
                                }
                            }
                        }
                    }
                }
                
                if let fullImage {
                    VStack(spacing: 12) {
                        // Interactive canvas
                        ZStack {
                            Color.mineDarkLight.opacity(0.5)
                            
                            // Full screenshot with drag/zoom
                            GeometryReader { geometry in
                                let _ = {
                                    // Calculate actual displayed size after scaledToFit
                                    let imageSize = fullImage.size
                                    let container = geometry.size
                                    let scaleFactor = min(container.width / imageSize.width, container.height / imageSize.height)
                                    let baseDisplayedSize = CGSize(
                                        width: imageSize.width * scaleFactor,
                                        height: imageSize.height * scaleFactor
                                    )
                                    if displayedImageSize != baseDisplayedSize {
                                        displayedImageSize = baseDisplayedSize
                                    }
                                    if containerSize != container {
                                        containerSize = container
                                    }
                                }()
                                
                                Image(uiImage: fullImage)
                                    .resizable()
                                    .scaledToFit()
                                    .scaleEffect(scale, anchor: .center)
                                    .offset(offset)
                                    .gesture(
                                        SimultaneousGesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    offset = CGSize(
                                                        width: lastOffset.width + value.translation.width,
                                                        height: lastOffset.height + value.translation.height
                                                    )
                                                }
                                                .onEnded { _ in
                                                    lastOffset = offset
                                                },
                                            MagnificationGesture()
                                                .onChanged { value in
                                                    if !isMagnifying {
                                                        isMagnifying = true
                                                        magnifyInitialScale = scale
                                                        magnifyInitialOffset = offset
                                                    }

                                                    let proposed = magnifyInitialScale * value
                                                    let clamped = min(max(proposed, minScale), maxScale)
                                                    scale = clamped

                                                    let ratio = clamped / magnifyInitialScale
                                                    offset = CGSize(
                                                        width: magnifyInitialOffset.width * ratio,
                                                        height: magnifyInitialOffset.height * ratio
                                                    )
                                                }
                                                .onEnded { _ in
                                                    isMagnifying = false
                                                    lastScale = scale
                                                    lastOffset = offset
                                                }
                                        )
                                    )
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            }
                            
                            // Crop box overlay (fixed in center)
                            Rectangle()
                                .stroke(Color.accentCyan, lineWidth: 2)
                                .frame(width: cropSize, height: cropSize)
                            
                            // Crosshairs
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: cropSize, y: cropSize))
                                path.move(to: CGPoint(x: cropSize, y: 0))
                                path.addLine(to: CGPoint(x: 0, y: cropSize))
                            }
                            .stroke(Color.accentCyan.opacity(0.3), lineWidth: 1)
                            .frame(width: cropSize, height: cropSize)
                        }
                        .frame(height: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        
                        // Live preview of what will be cropped
                        if let previewImage = generatePreviewCrop() {
                            VStack(spacing: 4) {
                                Text("Preview")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                                
                                Image(uiImage: previewImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .background(Color.mineDarkLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    
                    Text("Drag to move • Pinch to zoom")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    // Actions
                    HStack(spacing: 16) {
                        Button("Reset") {
                            offset = .zero
                            lastOffset = .zero
                            scale = 1.0
                            lastScale = 1.0
                            magnifyInitialOffset = .zero
                            magnifyInitialScale = 1.0
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Save Crop") {
                            saveCroppedIcon()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentCyan)
                    }
                } else {
                    ContentUnavailableView(
                        "No Image Selected",
                        systemImage: "photo.badge.plus",
                        description: Text("Select the manager screenshot to begin alignment")
                    )
                    .frame(height: 300)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.mineDark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSourceImage()
        }
    }
    
    private func loadSourceImage() {
        guard let docsURL = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        
        let sourceURL = docsURL
            .appendingPathComponent("Icons", isDirectory: true)
            .appendingPathComponent("\(entry.managerId)_source.png")
        
        if let data = try? Data(contentsOf: sourceURL),
           let image = UIImage(data: data) {
            fullImage = image
            print("✅ Loaded source image for alignment: \(entry.managerId)")
        } else {
            print("⚠️ No source image found at: \(sourceURL.path)")
        }
    }
    
    private func generatePreviewCrop() -> UIImage? {
        guard let fullImage else { return nil }
        guard displayedImageSize != .zero && containerSize != .zero else { return nil }
        
        // Calculate scaled displayed size
        let scaledDisplayedSize = CGSize(
            width: displayedImageSize.width * scale,
            height: displayedImageSize.height * scale
        )
        
        // Crop box center is at container center
        let cropBoxCenter = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        
        // When offset is positive (drag right/down), image moves right/down
        // So the point under the crop box is LEFT/UP in the image = SUBTRACT offset
        // Normalize: center of scaled image = 0.5, edges = 0 and 1
        let normalizedX = 0.5 - (offset.width / scaledDisplayedSize.width)
        let normalizedY = 0.5 - (offset.height / scaledDisplayedSize.height)
        
        let centerInImage = CGPoint(
            x: normalizedX * fullImage.size.width,
            y: normalizedY * fullImage.size.height
        )
        
        let cropPixelsPerPoint = fullImage.size.width / scaledDisplayedSize.width
        let cropWidthInImage = cropSize * cropPixelsPerPoint
        let cropHeightInImage = cropSize * cropPixelsPerPoint
        
        let cropRect = CGRect(
            x: max(0, centerInImage.x - cropWidthInImage / 2),
            y: max(0, centerInImage.y - cropHeightInImage / 2),
            width: min(cropWidthInImage, fullImage.size.width),
            height: min(cropHeightInImage, fullImage.size.height)
        ).integral
        
        guard let cgImage = fullImage.cgImage?.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cgImage, scale: fullImage.scale, orientation: fullImage.imageOrientation)
    }
    
    private func saveCroppedIcon() {
        guard let fullImage else { return }
        guard displayedImageSize != .zero && containerSize != .zero else { return }
        
        // Calculate scaled displayed size
        let scaledDisplayedSize = CGSize(
            width: displayedImageSize.width * scale,
            height: displayedImageSize.height * scale
        )
        
        // Crop box center is at container center
        let cropBoxCenter = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        
        // When offset is positive (drag right/down), image moves right/down
        // So the point under the crop box is LEFT/UP in the image = SUBTRACT offset
        // Normalize: center of scaled image = 0.5, edges = 0 and 1
        let normalizedX = 0.5 - (offset.width / scaledDisplayedSize.width)
        let normalizedY = 0.5 - (offset.height / scaledDisplayedSize.height)
        
        // Convert to actual pixel coordinates in the source image
        let centerInImage = CGPoint(
            x: normalizedX * fullImage.size.width,
            y: normalizedY * fullImage.size.height
        )
        
        // Calculate the size of the crop box in source image pixels
        let cropPixelsPerPoint = fullImage.size.width / scaledDisplayedSize.width
        let cropWidthInImage = cropSize * cropPixelsPerPoint
        let cropHeightInImage = cropSize * cropPixelsPerPoint
        
        // Create crop rect centered on the calculated point
        let cropRect = CGRect(
            x: max(0, centerInImage.x - cropWidthInImage / 2),
            y: max(0, centerInImage.y - cropHeightInImage / 2),
            width: min(cropWidthInImage, fullImage.size.width),
            height: min(cropHeightInImage, fullImage.size.height)
        ).integral
        
        print("🎯 Crop calculation:")
        print("  Display size: \(displayedImageSize)")
        print("  Scaled display: \(scaledDisplayedSize)")
        print("  Offset: \(offset)")
        print("  Center in image: \(centerInImage)")
        print("  Crop rect: \(cropRect)")
        
        // Crop the image
        guard let cgImage = fullImage.cgImage?.cropping(to: cropRect) else {
            print("❌ Failed to crop image")
            return
        }
        
        let croppedUIImage = UIImage(cgImage: cgImage, scale: fullImage.scale, orientation: fullImage.imageOrientation)
        
        // Save the cropped image
        do {
            guard let docsURL = try? FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ) else { return }
            
            let iconsDir = docsURL.appendingPathComponent("Icons", isDirectory: true)
            let imageURL = iconsDir.appendingPathComponent(entry.filename)
            
            // Scale to 64x64 for consistency
            let scaledImage = croppedUIImage.scaled(to: CGSize(width: 64, height: 64))
            
            if let pngData = scaledImage?.pngData() {
                try pngData.write(to: imageURL)
                print("✅ Saved adjusted icon: \(entry.filename)")
                
                let transform = IconAlignmentTransform(offset: offset, scale: scale)
                onSave(entry, transform)
                dismiss()
            }
        } catch {
            print("❌ Failed to save adjusted icon: \(error)")
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func scaled(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
