import Foundation

@MainActor
final class Persistence {
    static let shared = Persistence()

    private init() {}

    func save() {
        // Core Data stack to be implemented in a future phase.
    }
}
