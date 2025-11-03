import SwiftUI
import PhotosUI

struct IconCalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var calibrationImage: UIImage?
    @State private var markerPositions: [CGPoint] = []
    @State private var imageSize: CGSize = .zero
    @State private var showingSaveConfirmation = false
    @State private var currentLayout: PassiveLayout = .threePassives
    
    private var expectedIconsText: String {
        "Expected: \(currentLayout.expectedCount) icon\(currentLayout.expectedCount == 1 ? "" : "s") • Marked: \(markerPositions.count)"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image = calibrationImage {
                    VStack(spacing: 12) {
                        VStack(spacing: 8) {
                            // Layout selection
                            Picker("Promotion Level", selection: $currentLayout) {
                                Text("1 Passive").tag(PassiveLayout.onePassive)
                                Text("2 Passives").tag(PassiveLayout.twoPassives)
                                Text("3 Passives").tag(PassiveLayout.threePassives)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: currentLayout) { _, _ in
                                loadMarkersForCurrentLayout()
                            }
                            
                            VStack(spacing: 4) {
                                Text("Tap the CENTER of each PASSIVE icon")
                                    .mineOpsBody()
                                    .foregroundColor(Color.accentCyan)
                                    .bold()
                                
                                Text("RIGHT side under \"Passive\" label")
                                    .mineOpsCaption()
                                    .foregroundColor(.secondary)
                                
                                Text("(warehouse 🏭, dollar 💲, box 📦)")
                                    .mineOpsCaption()
                                    .foregroundStyle(.secondary)
                                
                                Text(expectedIconsText)
                                    .mineOpsCaption()
                                    .foregroundStyle(markerPositions.count == currentLayout.expectedCount ? .green : .accentCyan)
                                    .bold()
                            }
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .topLeading) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .background(
                                        GeometryReader { imageGeo in
                                            Color.clear.onAppear {
                                                imageSize = imageGeo.size
                                                print("📐 Image display size: \(imageGeo.size)")
                                                print("📐 Actual image size: \(image.size)")
                                            }
                                        }
                                    )
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onEnded { value in
                                                let location = value.location
                                                print("👆 Tap at: \(location) in container: \(geo.size)")
                                                addMarker(at: location, in: geo.size)
                                            }
                                    )
                                
                                ForEach(Array(markerPositions.enumerated()), id: \.offset) { index, position in
                                    ZStack {
                                        // Show the crop box that will be used
                                        Rectangle()
                                            .stroke(Color.accentCyan, lineWidth: 2)
                                            .frame(width: imageSize.width * 0.08, height: imageSize.height * 0.055)
                                            .position(position)
                                        
                                        // Center marker
                                        Circle()
                                            .fill(Color.accentCyan)
                                            .frame(width: 20, height: 20)
                                            .overlay(
                                                Text("\(index + 1)")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.white)
                                            )
                                            .position(position)
                                    }
                                }
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button("Clear Markers") {
                                markerPositions.removeAll()
                            }
                            .buttonStyle(.bordered)
                            .disabled(markerPositions.isEmpty)
                            
                            Button("Save \(currentLayout.displayName)") {
                                saveCalibration()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentCyan)
                            .disabled(markerPositions.count != currentLayout.expectedCount)
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: 24) {
                        Image(systemName: "viewfinder.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.accentCyan)
                        
                        Text("Calibrate Icon Detection")
                            .mineOpsHeadingStyle()
                        
                        Text("Select a Super Manager screenshot to calibrate the passive ability icon positions. This helps ensure accurate icon harvesting across different screen sizes.")
                            .mineOpsBody()
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Select Screenshot", systemImage: "photo")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentCyan)
                        .onChange(of: selectedPhoto) { _, newValue in
                            Task { await loadSelectedImage() }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Icon Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Calibration Saved", isPresented: $showingSaveConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Icon positions have been calibrated. New screenshots will use these coordinates.")
            }
        }
    }
    
    private func addMarker(at location: CGPoint, in containerSize: CGSize) {
        guard markerPositions.count < currentLayout.expectedCount else { return }
        
        print("✅ Marker \(markerPositions.count + 1) added at: \(location)")
        print("   Normalized: x=\(location.x / containerSize.width), y=\(location.y / containerSize.height)")
        
        // Store the tap location directly in the container's coordinate space
        // The markers will be displayed correctly since they use the same coordinate system
        markerPositions.append(location)
    }
    
    private func loadSelectedImage() async {
        guard let selectedPhoto else { return }
        
        do {
            if let data = try await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    calibrationImage = image
                    loadMarkersForCurrentLayout()
                }
            }
        } catch {
            print("Failed to load image: \(error)")
        }
    }
    
    private func loadMarkersForCurrentLayout() {
        if let coords = IconCalibration.getCalibrationCoordinates(for: currentLayout) {
            // Convert saved normalized coords back to display coords
            markerPositions = coords.map { coord in
                CGPoint(
                    x: coord["x"]! * imageSize.width,
                    y: coord["y"]! * imageSize.height
                )
            }
        } else {
            markerPositions.removeAll()
        }
    }
    
    private func saveCalibration() {
        guard markerPositions.count == currentLayout.expectedCount,
              let image = calibrationImage else { return }
        
        // Convert display coordinates to normalized image coordinates (0-1 range)
        let imageAspect = image.size.width / image.size.height
        let displayAspect = imageSize.width / imageSize.height
        
        // Calculate the actual image frame within the display area
        let imageFrame: CGRect
        if imageAspect > displayAspect {
            // Image is wider - fits width
            let displayHeight = imageSize.width / imageAspect
            let yOffset = (imageSize.height - displayHeight) / 2
            imageFrame = CGRect(x: 0, y: yOffset, width: imageSize.width, height: displayHeight)
        } else {
            // Image is taller - fits height
            let displayWidth = imageSize.height * imageAspect
            let xOffset = (imageSize.width - displayWidth) / 2
            imageFrame = CGRect(x: xOffset, y: 0, width: displayWidth, height: imageSize.height)
        }
        
        // Convert marker positions to normalized coordinates relative to the actual image
        let normalizedCoords = markerPositions.map { marker -> (x: Double, y: Double) in
            let relativeX = (marker.x - imageFrame.origin.x) / imageFrame.width
            let relativeY = (marker.y - imageFrame.origin.y) / imageFrame.height
            return (x: Double(relativeX), y: Double(relativeY))
        }
        
        // Save to UserDefaults with layout-specific key
        let coords = normalizedCoords.map { ["x": $0.x, "y": $0.y] }
        IconCalibration.saveCalibration(coords, for: currentLayout)
        
        print("✅ Saved calibration for \(currentLayout.displayName):")
        for (index, coord) in normalizedCoords.enumerated() {
            print("  Icon \(index + 1): x=\(String(format: "%.3f", coord.x)), y=\(String(format: "%.3f", coord.y))")
        }
        
        showingSaveConfirmation = true
    }
}

/// Passive ability layout types based on promotion level
public enum PassiveLayout: String, CaseIterable {
    case zeroPassives = "0_passives"
    case onePassive = "1_passive"
    case twoPassives = "2_passives"
    case threePassives = "3_passives" // Also used for legendary
    
    var displayName: String {
        switch self {
        case .zeroPassives: return "0 Passives"
        case .onePassive: return "1 Passive"
        case .twoPassives: return "2 Passives"
        case .threePassives: return "3 Passives/Legendary"
        }
    }
    
    var expectedCount: Int {
        switch self {
        case .zeroPassives: return 0
        case .onePassive: return 1
        case .twoPassives: return 2
        case .threePassives: return 3
        }
    }
}

/// Helper to load calibrated coordinates
public enum IconCalibration {
    
    /// Get calibration rectangles for a specific layout
    public static func getCalibrationRects(for layout: PassiveLayout) -> [(index: Int, rect: CGRect)]? {
        guard let coords = getCalibrationCoordinates(for: layout) else {
            return nil
        }
        
        // Convert to crop rects
        // User taps the CENTER of the icon, so offset to get top-left corner
        let iconWidth = 0.10   // Increased to capture full icon
        let iconHeight = 0.07  // Increased to capture full icon
        
        return coords.enumerated().map { index, coord in
            // Tap is at icon center, so offset by half width/height to get top-left
            let x = coord["x"]! - (iconWidth / 2)
            let y = coord["y"]! - (iconHeight / 2)
            return (index, CGRect(x: x, y: y, width: iconWidth, height: iconHeight))
        }
    }
    
    /// Get raw coordinates for a layout
    public static func getCalibrationCoordinates(for layout: PassiveLayout) -> [[String: Double]]? {
        let key = "iconCalibration_\(layout.rawValue)"
        return UserDefaults.standard.array(forKey: key) as? [[String: Double]]
    }
    
    /// Save calibration for a specific layout
    public static func saveCalibration(_ coords: [[String: Double]], for layout: PassiveLayout) {
        let key = "iconCalibration_\(layout.rawValue)"
        UserDefaults.standard.set(coords, forKey: key)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "\(key)_timestamp")
    }
    
    /// Get the best matching layout based on detected passive count
    public static func getCalibrationRects(forPassiveCount count: Int) -> [(index: Int, rect: CGRect)]? {
        let layout: PassiveLayout
        switch count {
        case 0: layout = .zeroPassives
        case 1: layout = .onePassive
        case 2: layout = .twoPassives
        default: layout = .threePassives
        }
        return getCalibrationRects(for: layout)
    }
    
    /// Check if any layout is calibrated
    public static var isCalibrated: Bool {
        PassiveLayout.allCases.contains { layout in
            getCalibrationCoordinates(for: layout) != nil
        }
    }
    
    /// Clear calibration for a specific layout
    public static func clearCalibration(for layout: PassiveLayout) {
        let key = "iconCalibration_\(layout.rawValue)"
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: "\(key)_timestamp")
    }
    
    /// Clear all calibrations
    public static func clearAllCalibrations() {
        PassiveLayout.allCases.forEach { layout in
            clearCalibration(for: layout)
        }
    }
}
