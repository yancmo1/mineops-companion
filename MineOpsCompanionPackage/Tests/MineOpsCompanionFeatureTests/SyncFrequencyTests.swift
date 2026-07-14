@testable import MineOpsCompanionFeature
import Foundation
import Testing

@Suite("Sync Frequency")
struct SyncFrequencyTests {

    @Test("Off has no interval")
    func offHasNoInterval() {
        #expect(SyncFrequency.off.interval == nil)
    }

    @Test("Intervals are correct for hourly presets")
    func intervalValues() {
        #expect(SyncFrequency.hourly.interval == 3_600)
        #expect(SyncFrequency.sixHours.interval == 21_600)
        #expect(SyncFrequency.twelveHours.interval == 43_200)
        #expect(SyncFrequency.daily.interval == 86_400)
    }

    @Test("Freshness rule requests sync only when due")
    func freshnessDueRule() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let oneHourAgo = now.addingTimeInterval(-3_600)
        let thirtyMinutesAgo = now.addingTimeInterval(-1_800)

        #expect(SyncFrequency.off.isDue(lastSuccessfulSyncAt: nil, now: now) == false)
        #expect(SyncFrequency.hourly.isDue(lastSuccessfulSyncAt: nil, now: now) == true)
        #expect(SyncFrequency.hourly.isDue(lastSuccessfulSyncAt: oneHourAgo, now: now) == true)
        #expect(SyncFrequency.hourly.isDue(lastSuccessfulSyncAt: thirtyMinutesAgo, now: now) == false)
    }
}
