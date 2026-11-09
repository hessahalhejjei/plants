import XCTest
@testable import Planto

final class PlantReminderTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }

    private func date(_ year: Int = 2026, _ month: Int = 11, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testNewPlantIsDueOnCreationDayAndOverdueUntilWatered() {
        let plant = PlantReminder(name: "Monstera", createdAt: date(2026, 11, 9))
        XCTAssertFalse(plant.isDue(on: date(2026, 11, 8), calendar: calendar))
        XCTAssertTrue(plant.isDue(on: date(2026, 11, 9), calendar: calendar))
        XCTAssertTrue(plant.isDue(on: date(2026, 11, 12), calendar: calendar))
    }

    func testCompletionAdvancesBySelectedFrequency() {
        let today = date(2026, 11, 9)
        let expectedIntervals: [(WateringFrequency, Int)] = [
            (.daily, 1), (.everyTwoDays, 2), (.everyThreeDays, 3),
            (.weekly, 7), (.everyTenDays, 10), (.biweekly, 14)
        ]
        for (frequency, days) in expectedIntervals {
            let plant = PlantReminder(name: "Pothos", frequency: frequency, createdAt: today, wateringDates: [today])
            let nextDay = calendar.date(byAdding: .day, value: days, to: today)!
            XCTAssertEqual(frequency.intervalDays, days)
            XCTAssertTrue(plant.isCompleted(on: today, calendar: calendar))
            XCTAssertFalse(plant.isDue(on: today, calendar: calendar))
            XCTAssertEqual(plant.nextWateringDate(calendar: calendar), calendar.startOfDay(for: nextDay))
            XCTAssertTrue(plant.isDue(on: nextDay, calendar: calendar))
        }
    }

    func testWateringIntervalUsesCalendarDaysAcrossDaylightSaving() {
        let watered = date(2024, 3, 9)
        let plant = PlantReminder(name: "Orchid", frequency: .everyTwoDays, createdAt: watered, wateringDates: [watered])
        let next = plant.nextWateringDate(calendar: calendar)
        XCTAssertEqual(next, calendar.startOfDay(for: date(2024, 3, 11)))
        XCTAssertEqual(next.timeIntervalSince(calendar.startOfDay(for: watered)), 47 * 60 * 60)
    }

    func testLatestCompletionDeterminesNextDayRegardlessOfHistoryOrder() {
        let plant = PlantReminder(name: "Spider", frequency: .weekly, createdAt: date(2026, 11, 1), wateringDates: [date(2026, 11, 9), date(2026, 11, 2)])
        XCTAssertEqual(plant.nextWateringDate(calendar: calendar), calendar.startOfDay(for: date(2026, 11, 16)))
    }

    func testCareDetailsAndWateringHistoryRoundTrip() throws {
        let plant = PlantReminder(name: "Fern", room: .bathroom, light: .lowLight, frequency: .biweekly, waterAmount: .extraLarge, createdAt: date(2026, 11, 9), wateringDates: [date(2026, 11, 9)])
        let decoded = try JSONDecoder().decode(PlantReminder.self, from: JSONEncoder().encode(plant))
        XCTAssertEqual(decoded, plant)
    }
}
