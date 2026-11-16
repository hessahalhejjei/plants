import XCTest
@testable import Planto

final class NotificationScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }

    private func date(_ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    func testDuePlantGetsNineAMTodayWhenStillInFuture() async {
        let now = date(9, hour: 8)
        let plant = PlantReminder(name: "Fern", createdAt: now)
        XCTAssertEqual(WateringSchedule.nextNotificationDate(for: plant, now: now, calendar: calendar), date(9, hour: 9))
    }

    func testOverduePlantNeverSchedulesInThePast() async {
        let now = date(9, hour: 14)
        let plant = PlantReminder(name: "Fern", createdAt: date(7, hour: 12))
        XCTAssertEqual(WateringSchedule.nextNotificationDate(for: plant, now: now, calendar: calendar), date(10, hour: 9))
    }

    func testWateredWeeklyPlantSchedulesNextWeekInsteadOfTomorrow() async {
        let now = date(9, hour: 14)
        let plant = PlantReminder(name: "Orchid", frequency: .weekly, createdAt: now, wateringDates: [now])
        XCTAssertEqual(WateringSchedule.nextNotificationDate(for: plant, now: now, calendar: calendar), date(16, hour: 9))
    }

    func testExactNineAMDoesNotScheduleAnAlreadyElapsedTrigger() {
        let now = date(9, hour: 9)
        let plant = PlantReminder(name: "Fern", createdAt: now)
        XCTAssertEqual(WateringSchedule.nextNotificationDate(for: plant, now: now, calendar: calendar), date(10, hour: 9))
    }

    func testQueueChoosesEarliestDatesAcrossDifferentIntervals() {
        let now = date(9, hour: 8)
        let daily = PlantReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Daily", createdAt: now
        )
        let weekly = PlantReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Weekly", frequency: .weekly, createdAt: now
        )
        // Reverse input order to check the deterministic tie-break for equal dates.
        let queue = WateringSchedule.upcomingReminders(for: [weekly, daily], limit: 5, now: now, calendar: calendar)
        XCTAssertEqual(queue.map(\.plant.id), [daily.id, weekly.id, daily.id, daily.id, daily.id])
        XCTAssertEqual(queue.map(\.date), [date(9, hour: 9), date(9, hour: 9), date(10, hour: 9), date(11, hour: 9), date(12, hour: 9)])
    }

    func testQueueHonorsIOSLimitAndUsesCurrentEditedDetails() {
        let now = date(9, hour: 8)
        var plant = PlantReminder(name: "Pothos", createdAt: now)
        plant.name = "Kitchen pothos"
        plant.room = .kitchen
        plant.waterAmount = .large
        let queue = WateringSchedule.upcomingReminders(for: [plant], now: now, calendar: calendar)
        XCTAssertEqual(queue.count, 64)
        XCTAssertTrue(queue.allSatisfy { $0.plant == plant && $0.date > now })
        XCTAssertEqual(Set(queue.map(\.date)).count, 64)
    }

    func testEmptyAndFullQueuesDoNotProduceExtraAlerts() {
        let plant = PlantReminder(name: "Fern")
        XCTAssertTrue(WateringSchedule.upcomingReminders(for: []).isEmpty)
        XCTAssertTrue(WateringSchedule.upcomingReminders(for: [plant], limit: 0).isEmpty)
        XCTAssertTrue(WateringSchedule.upcomingReminders(for: [plant], limit: -1).isEmpty)
    }

    func testRecurringAlertsKeepNineAMAcrossSpringDaylightSaving() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 3, day: 9, hour: 8)))
        let plant = PlantReminder(name: "Fern", createdAt: now)
        let queue = WateringSchedule.upcomingReminders(for: [plant], limit: 3, now: now, calendar: calendar)
        XCTAssertEqual(queue.map { calendar.component(.day, from: $0.date) }, [9, 10, 11])
        XCTAssertTrue(queue.allSatisfy { calendar.component(.hour, from: $0.date) == 9 })
        XCTAssertEqual(queue[1].date.timeIntervalSince(queue[0].date), 23 * 60 * 60)
    }

    func testRecurringAlertsKeepNineAMAcrossAutumnDaylightSaving() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 8)))
        let plant = PlantReminder(name: "Fern", createdAt: now)
        let queue = WateringSchedule.upcomingReminders(for: [plant], limit: 3, now: now, calendar: calendar)
        XCTAssertEqual(queue.map { calendar.component(.hour, from: $0.date) }, [9, 9, 9])
        XCTAssertEqual(queue[1].date.timeIntervalSince(queue[0].date), 25 * 60 * 60)
    }
}
