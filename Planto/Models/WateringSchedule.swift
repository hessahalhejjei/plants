import Foundation

/// Pure date calculations, kept separate from iOS notification permission and delivery.
enum WateringSchedule {
    static func nextNotificationDate(
        for plant: PlantReminder,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let due = plant.nextWateringDate(calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let day = max(due, today)
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        if morning > now { return morning }

        // If today's reminder time has passed, never schedule an alert in the past.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(86_400)
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    /// Fill the available notification slots with the earliest dates across all plants.
    static func upcomingReminders(
        for plants: [PlantReminder],
        limit: Int = 64,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [(plant: PlantReminder, date: Date)] {
        guard limit > 0 else { return [] }
        var candidates: [(plant: PlantReminder, date: Date)] = []
        for plant in plants {
            var date = nextNotificationDate(for: plant, now: now, calendar: calendar)
            for _ in 0..<limit {
                candidates.append((plant, date))
                guard let next = calendar.date(byAdding: .day, value: plant.frequency.intervalDays, to: date) else { break }
                date = next
            }
        }
        candidates.sort {
            if $0.date == $1.date { return $0.plant.id.uuidString < $1.plant.id.uuidString }
            return $0.date < $1.date
        }
        return Array(candidates.prefix(limit))
    }
}
