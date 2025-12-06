import Foundation
import Testing
@testable import MineOpsCompanionFeature

struct IconLegendLoaderTests {
    @Test("Bundled icon legend decodes")
    func bundledLegendDecodes() throws {
        let url = try #require(
            Bundle.module.url(
                forResource: "icon_legend",
                withExtension: "json",
                subdirectory: "Data"
            )
        )
        let data = try Data(contentsOf: url)
        let legend = try JSONDecoder().decode(IconLegend.self, from: data)
        #expect(!legend.icons.isEmpty)
    }
}
