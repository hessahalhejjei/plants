import Foundation

struct PlantRowViewModel {
    let plant: PlantReminder
    let day: Date
    var calendar: Calendar = .autoupdatingCurrent

    var isComplete: Bool { plant.isCompleted(on: day, calendar: calendar) }
    var canComplete: Bool { plant.isDue(on: day, calendar: calendar) || isComplete }
    var wateringStatus: String {
        if isComplete { return "Watered today" }
        if canComplete { return "Due today" }
        return nextWateringDescription
    }
    var nextWateringDescription: String {
        let date = plant.nextWateringDate(calendar: calendar)
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: day),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Water tomorrow"
        }
        return "Water \(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"
    }
}
