import Foundation
import UIKit

final class ExportManager {
    func exportAsMarkdown(_ summary: String, fileName: String = "MineOps_StrategyReport") -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        let fullFileName = "\(fileName)_\(dateString).md"

        let fileContent = """
        # MineOps Strategy Report

        Generated: \(Date())

        ## Summary

        \(summary)

        ---
        *Exported from MineOps Companion*
        """

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent(fullFileName)

        do {
            try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to export file: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    func shareReport(_ url: URL, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        viewController.present(activityVC, animated: true)
    }
}
