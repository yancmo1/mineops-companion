@testable import MineOpsCompanionFeature
import Foundation
import Testing

@Suite("Kolibri Debug ID Parser")
struct KolibriDebugIDParserTests {

    @Test("Extracts last UUID from full debug string with two UUIDs")
    func extractsLastUUID() {
        let input = "ID: 5.56.0 95973ir b1febfd3-f04f-4a05-8f3d-329fcdae7bef 5C6E939D2BEAF907 Disconnected dbffca92-27e9-485a-831a-feb5bfc2e3c4"
        let extracted = KolibriDebugIDParser.extractLastUUID(from: input)
        #expect(extracted == "dbffca92-27e9-485a-831a-feb5bfc2e3c4")
    }

    @Test("Single UUID is returned lowercased")
    func singleUUIDLowercased() {
        let input = "dbFFCA92-27E9-485A-831A-FEB5BFC2E3C4"
        let extracted = KolibriDebugIDParser.extractLastUUID(from: input)
        #expect(extracted == "dbffca92-27e9-485a-831a-feb5bfc2e3c4")
    }

    @Test("Whitespace and newlines are tolerated")
    func whitespaceAndNewlines() {
        let input = "Some text\n  dbffca92-27e9-485a-831a-feb5bfc2e3c4\nMore"
        let extracted = KolibriDebugIDParser.extractLastUUID(from: input)
        #expect(extracted == "dbffca92-27e9-485a-831a-feb5bfc2e3c4")
    }

    @Test("Invalid strings return nil")
    func invalidReturnsNil() {
        let input = "no uuids here"
        let extracted = KolibriDebugIDParser.extractLastUUID(from: input)
        #expect(extracted == nil)
    }
}
