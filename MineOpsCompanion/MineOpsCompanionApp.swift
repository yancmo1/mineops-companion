import SwiftUI
import MineOpsCompanionFeature

@main
struct MineOpsCompanionApp: App {
    @StateObject private var review = OCRReviewViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(review)
        }
    }
}
