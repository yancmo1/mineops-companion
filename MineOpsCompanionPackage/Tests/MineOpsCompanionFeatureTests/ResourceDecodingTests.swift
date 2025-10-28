@testable import MineOpsCompanionFeature
import Foundation
import Testing

@Suite
struct ResourceDecodingTests {
    @Test("sm_directory.json is bundled and reachable")
    func resourceExists() throws {
        _ = try ResourceLoader.url(for: "sm_directory", ext: "json")
    }

    @Test("sm_directory.json decodes into SuperManager list")
    func directoryDecodes() throws {
        let managers: [SuperManager] = try ResourceLoader.decode([SuperManager].self, from: "sm_directory")
        #expect(!managers.isEmpty, "Directory should contain at least one manager")
    }
}
