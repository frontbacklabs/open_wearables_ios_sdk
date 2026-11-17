import XCTest
import HealthKit
@testable import OpenWearablesHealthSDK

/// A missing offset reads as UTC on the backend, so a sample without
/// `HKMetadataKeyTimeZone` must carry the device's zone instead of `null`.
final class ZoneOffsetTests: XCTestCase {

    private let original = OpenWearablesHealthSDK.deviceTimeZone

    override func tearDown() {
        OpenWearablesHealthSDK.deviceTimeZone = original
        super.tearDown()
    }

    private func zoneOffset(at iso: String, metadata: [String: Any]? = nil) -> Any? {
        let date = ISO8601DateFormatter().date(from: iso)!
        let sample = HKQuantitySample(
            type: HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            quantity: HKQuantity(unit: .count(), doubleValue: 120),
            start: date,
            end: date.addingTimeInterval(60),
            metadata: metadata
        )
        let payload = OpenWearablesHealthSDK.shared.buildCombinedPayload(samples: [sample])
        let data = payload["data"] as? [String: Any]
        return (data?["records"] as? [[String: Any]])?.first?["zoneOffset"]
    }

    func testSampleWithoutZoneTakesTheDevicesOffsetAtItsDate() {
        OpenWearablesHealthSDK.deviceTimeZone = { TimeZone(identifier: "America/New_York")! }

        // Nov 16 20:00 EST: past UTC midnight, still the device's Nov 16.
        XCTAssertEqual(zoneOffset(at: "2026-11-17T01:00:00Z") as? String, "-05:00")
        // Daylight time applies to the sample's own date.
        XCTAssertEqual(zoneOffset(at: "2026-07-01T23:30:00Z") as? String, "-04:00")
    }

    func testSampleZoneWinsOverTheDevice() {
        OpenWearablesHealthSDK.deviceTimeZone = { TimeZone(identifier: "America/New_York")! }

        let offset = zoneOffset(at: "2026-11-17T01:00:00Z", metadata: [HKMetadataKeyTimeZone: "Asia/Tokyo"])
        XCTAssertEqual(offset as? String, "+09:00")
    }

    func testHalfHourZonesKeepTheirMinutes() {
        OpenWearablesHealthSDK.deviceTimeZone = { TimeZone(identifier: "Asia/Kolkata")! }

        XCTAssertEqual(zoneOffset(at: "2026-11-17T01:00:00Z") as? String, "+05:30")
    }
}
