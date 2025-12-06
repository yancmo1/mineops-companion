import Observation
import SwiftUI
import UIKit
import OSLog

@MainActor
@Observable
final class IconLibrary {
    enum IconState {
        case unlocked
        case locked
    }

    static let shared = IconLibrary()

    var icons: [IconInfo] = []
    var searchText: String = ""
    var selectedCategory: String = "All"

    private let fileManager = FileManager.default

    private init() {
        loadLegend()
    }

    func loadLegend() {
        do {
            let result = try IconLegendLoader().loadLegend()
            icons = result.legend.icons.sorted { $0.displayName < $1.displayName }
            Logger.iconLibrary.info("✅ Loaded \(result.legend.icons.count) icons from legend (v\(result.legend.version)) using \(result.sourceDescription)")
        } catch {
            Logger.iconLibrary.error("❌ Failed to load icon legend: \(error.localizedDescription)")
            icons = []
        }
    }

    func image(for icon: IconInfo, state: IconState) -> Image? {
        let targetFile = state == .locked ? icon.iconLocked : icon.iconUnlocked
        if let url = documentURL(for: targetFile, locked: state == .locked),
           fileManager.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }

        let assetName = (targetFile as NSString).deletingPathExtension
        if !assetName.isEmpty, let uiImage = UIImage(named: assetName) {
            return Image(uiImage: uiImage)
        }

        return nil
    }

    var filteredIcons: [IconInfo] {
        icons.filter { icon in
            let matchesCategory = selectedCategory == "All" || icon.boostCategory == selectedCategory
            if searchText.isEmpty {
                return matchesCategory
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return matchesCategory }
            return matchesCategory && (
                icon.displayName.localizedCaseInsensitiveContains(query) ||
                icon.description.localizedCaseInsensitiveContains(query) ||
                icon.id.localizedCaseInsensitiveContains(query)
            )
        }
    }

    var categories: [String] {
        var result: Set<String> = ["All"]
        icons.forEach { result.insert($0.boostCategory) }
        return result.sorted()
    }

    private func documentURL(for iconFile: String, locked: Bool) -> URL? {
        guard let docs = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return nil
        }
        let folder = locked ? "locked" : "unlocked"
        return docs
            .appendingPathComponent("SMIcons", isDirectory: true)
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent(iconFile, isDirectory: false)
    }
}

private struct IconLegendLoader {
    struct LoadResult {
        let legend: IconLegend
        let sourceDescription: String
    }

    private struct Candidate {
        let name: String
        let load: () throws -> Data
        let cleanupOnCorruption: () -> Void

        init(name: String, load: @escaping () throws -> Data, cleanupOnCorruption: @escaping () -> Void = {}) {
            self.name = name
            self.load = load
            self.cleanupOnCorruption = cleanupOnCorruption
        }
    }

    func loadLegend() throws -> LoadResult {
        let decoder = JSONDecoder()
        var lastError: Error = CocoaError(.fileNoSuchFile)

        for candidate in candidates() {
            do {
                let data = try candidate.load()
                guard !data.isEmpty else { continue }
                let legend = try decoder.decode(IconLegend.self, from: data)
                return LoadResult(legend: legend, sourceDescription: candidate.name)
            } catch let decodingError as DecodingError {
                lastError = decodingError
                candidate.cleanupOnCorruption()
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    private func candidates() -> [Candidate] {
        var result: [Candidate] = []

        // Try Bundle.module first (SPM resource bundle)
        result.append(Candidate(name: "Bundle.module/Data/icon_legend.json") {
            do {
                return try ResourceLoader.data(named: "icon_legend", ext: "json", subdirectory: "Data")
            } catch {
                Logger.iconLibrary.debug("  ⚠️ Bundle.module lookup failed: \(error.localizedDescription)")
                throw error
            }
        })

        // Fallback to Bundle.main with subdirectory
        result.append(Candidate(name: "Bundle.main/Data/icon_legend.json") {
            guard let url = Bundle.main.url(forResource: "icon_legend", withExtension: "json", subdirectory: "Data") else {
                Logger.iconLibrary.debug("  ⚠️ Bundle.main/Data lookup failed")
                throw CocoaError(.fileNoSuchFile)
            }
            Logger.iconLibrary.debug("  ✅ Found in Bundle.main/Data at \(url.path)")
            return try Data(contentsOf: url)
        })

        // Fallback to Bundle.main root
        result.append(Candidate(name: "Bundle.main/icon_legend.json") {
            guard let url = Bundle.main.url(forResource: "icon_legend", withExtension: "json") else {
                Logger.iconLibrary.debug("  ⚠️ Bundle.main root lookup failed")
                throw CocoaError(.fileNoSuchFile)
            }
            Logger.iconLibrary.debug("  ✅ Found in Bundle.main root at \(url.path)")
            return try Data(contentsOf: url)
        })

        if let docs = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let docURL = docs
                .appendingPathComponent("Data", isDirectory: true)
                .appendingPathComponent("icon_legend.json")
            result.append(
                Candidate(
                    name: docURL.path,
                    load: {
                        guard FileManager.default.fileExists(atPath: docURL.path) else {
                            throw CocoaError(.fileNoSuchFile)
                        }
                        return try Data(contentsOf: docURL)
                    },
                    cleanupOnCorruption: {
                        try? FileManager.default.removeItem(at: docURL)
                    }
                )
            )
        }

        return result
    }
}
