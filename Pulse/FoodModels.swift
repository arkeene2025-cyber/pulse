import Foundation

struct Meal: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var name: String
    var items: [String]
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
    var confidence: String   // "high" | "medium" | "low"
}

/// Simple JSON-file persistence in the app's Documents directory.
@MainActor
final class MealStore: ObservableObject {
    @Published var meals: [Meal] = []

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("meals.json")
    }

    init() { load() }

    func add(_ meal: Meal) {
        meals.append(meal)
        save()
    }

    func delete(_ meal: Meal) {
        meals.removeAll { $0.id == meal.id }
        save()
    }

    func todaysMeals() -> [Meal] {
        meals.filter { Calendar.current.isDateInToday($0.date) }
    }

    var todaysCaloriesIn: Int {
        todaysMeals().reduce(0) { $0 + $1.calories }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Meal].self, from: data) else { return }
        meals = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(meals) {
            try? data.write(to: fileURL)
        }
    }
}
