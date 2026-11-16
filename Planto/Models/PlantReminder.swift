import Foundation

enum Room: String, CaseIterable, Codable, Identifiable {
    case bedroom, livingRoom, kitchen, balcony, bathroom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bedroom: return "Bedroom"
        case .livingRoom: return "Living Room"
        case .kitchen: return "Kitchen"
        case .balcony: return "Balcony"
        case .bathroom: return "Bathroom"
        }
    }

    var symbolName: String { "location" }
}

enum LightLevel: String, CaseIterable, Codable, Identifiable {
    case fullSun, partialSun, lowLight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullSun: return "Full Sun"
        case .partialSun: return "Partial Sun"
        case .lowLight: return "Low Light"
        }
    }

    var symbolName: String {
        switch self {
        case .fullSun: return "sun.max"
        case .partialSun: return "sun.haze"
        case .lowLight: return "moon"
        }
    }
}

enum WateringFrequency: String, CaseIterable, Codable, Identifiable {
    case daily, everyTwoDays, everyThreeDays, weekly, everyTenDays, biweekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Every day"
        case .everyTwoDays: return "Every 2 days"
        case .everyThreeDays: return "Every 3 days"
        case .weekly: return "Once a week"
        case .everyTenDays: return "Every 10 days"
        case .biweekly: return "Every 2 weeks"
        }
    }

    var intervalDays: Int {
        switch self {
        case .daily: return 1
        case .everyTwoDays: return 2
        case .everyThreeDays: return 3
        case .weekly: return 7
        case .everyTenDays: return 10
        case .biweekly: return 14
        }
    }

    var symbolName: String { "drop" }
}

enum WaterAmount: String, CaseIterable, Codable, Identifiable {
    case small, medium, large, extraLarge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "20–50 ml"
        case .medium: return "50–100 ml"
        case .large: return "100–200 ml"
        case .extraLarge: return "200–300 ml"
        }
    }

    var symbolName: String { "drop" }
}

struct PlantReminder: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var room: Room
    var light: LightLevel
    var frequency: WateringFrequency
    var waterAmount: WaterAmount
    var createdAt: Date
    var wateringDates: [Date]

    init(
        id: UUID = UUID(),
        name: String,
        room: Room = .bedroom,
        light: LightLevel = .fullSun,
        frequency: WateringFrequency = .daily,
        waterAmount: WaterAmount = .small,
        createdAt: Date = Date(),
        wateringDates: [Date] = []
    ) {
        self.id = id
        self.name = name
        self.room = room
        self.light = light
        self.frequency = frequency
        self.waterAmount = waterAmount
        self.createdAt = createdAt
        self.wateringDates = wateringDates
    }

    func isCompleted(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        wateringDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    func isDue(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        nextWateringDate(calendar: calendar) <= calendar.startOfDay(for: date)
            && !isCompleted(on: date, calendar: calendar)
    }

    /// Calendar arithmetic preserves a local watering day across daylight-saving changes.
    func nextWateringDate(calendar: Calendar = .current) -> Date {
        guard let lastWatered = wateringDates.max() else {
            return calendar.startOfDay(for: createdAt)
        }
        let lastDay = calendar.startOfDay(for: lastWatered)
        return calendar.date(byAdding: .day, value: frequency.intervalDays, to: lastDay) ?? lastDay
    }
}
