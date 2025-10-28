import Foundation

#if canImport(Testing)
import Testing
#endif

private struct DirectoryEntryLite: Decodable {
    let name: String
    let department: String
}

private enum FixtureLoader {
    static func loadSample() throws -> [DirectoryEntryLite] {
        #if SWIFT_PACKAGE
        guard let url = Bundle.module.url(forResource: "sm_directory_sample", withExtension: "json") else {
            throw NSError(domain: "Fixtures", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing sm_directory_sample.json"])
        }
        #else
        guard let url = Bundle.main.url(forResource: "sm_directory_sample", withExtension: "json") else {
            throw NSError(domain: "Fixtures", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing sm_directory_sample.json in main bundle"])
        }
        #endif

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try JSONDecoder().decode([DirectoryEntryLite].self, from: data)
    }
}

#if canImport(Testing)
@Suite
struct SampleDirectoryTests {
    @Test("Fixture is bundled and decodes")
    func decodesLite() throws {
        let rows = try FixtureLoader.loadSample()
        #expect(!rows.isEmpty)
    }

    @Test("Contains key managers used by push loops")
    func containsKeyManagers() throws {
        let rows = try FixtureLoader.loadSample()
        let names = Set(rows.map { $0.name })
        #expect(names.contains("Mr Edmund"))
        #expect(names.contains("Dr Lilly"))
        #expect(names.contains("Mr Turner"))
        #expect(names.contains("Thalia"))
    }

    @Test("Departments look sane")
    func departments() throws {
        let rows = try FixtureLoader.loadSample()
        let depts = Set(rows.map { $0.department })
        #expect(depts.isSuperset(of: ["mineshaft", "elevator", "warehouse"]))
    }
}
#else
import XCTest

final class SampleDirectoryTests: XCTestCase {
    func testDecodesLite() throws {
        let rows = try FixtureLoader.loadSample()
        XCTAssertFalse(rows.isEmpty)
    }

    func testContainsKeyManagers() throws {
        let rows = try FixtureLoader.loadSample()
        let names = Set(rows.map { $0.name })
        XCTAssertTrue(names.contains("Mr Edmund"))
        XCTAssertTrue(names.contains("Dr Lilly"))
        XCTAssertTrue(names.contains("Mr Turner"))
        XCTAssertTrue(names.contains("Thalia"))
    }

    func testDepartmentsLookSane() throws {
        let rows = try FixtureLoader.loadSample()
        let depts = Set(rows.map { $0.department })
        XCTAssertTrue(depts.isSuperset(of: ["mineshaft", "elevator", "warehouse"]))
    }
}
#endif
