import Foundation
import OSLog

public extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.mineopscompanion"
    
    static let iconLibrary = Logger(subsystem: subsystem, category: "IconLibrary")
    static let ocr = Logger(subsystem: subsystem, category: "OCR")
    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let strategy = Logger(subsystem: subsystem, category: "Strategy")
    static let app = Logger(subsystem: subsystem, category: "App")
}
