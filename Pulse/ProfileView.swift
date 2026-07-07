import SwiftUI

// MARK: - Profile model + energy math

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary, light, moderate, active, veryActive

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .active: return "Very active"
        case .veryActive: return "Athlete"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return "Desk job, little exercise"
        case .light: return "Exercise 1–3 days/week"
        case .moderate: return "Exercise 3–5 days/week"
        case .active: return "Hard exercise 6–7 days/week"
        case .veryActive: return "Physical job + daily training"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }
}

enum Goal: String, CaseIterable, Identifiable, Codable {
    case cut, maintain, bulk
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cut: return "Cut (lose fat)"
        case .maintain: return "Maintain"
        case .bulk: return "Bulk (gain muscle)"
        }
    }
}

struct UserProfile: Codable {
    var weightKg: Double = 70
    var heightCm: Double = 175
    var age: Int = 22
    var isMale: Bool = true
    var activity: ActivityLevel = .light
    var goal: Goal = .bulk

    /// Mifflin-St Jeor — the standard BMR equation.
    var bmr: Double {
        10 * weightKg + 6.25 * heightCm - 5 * Double(age) + (isMale ? 5 : -161)
    }

    /// Maintenance calories.
    var tdee: Double { bmr * activity.multiplier }

    /// Daily calorie target for the selected goal.
    var targetCalories: Int {
        switch goal {
        case .cut: return Int(tdee * 0.80)        // ~20% deficit
        case .maintain: return Int(tdee)
        case .bulk: return Int(tdee + 350)        // lean-bulk surplus ≈ +300–400
        }
    }

    /// ~1.8 g protein per kg for muscle gain, 1.6 otherwise.
    var proteinTargetG: Int {
        Int(weightKg * (goal == .bulk ? 1.8 : 1.6))
    }

    var maxHR: Double { 220 - Double(age) }

    // Persistence
    static func load() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: "user_profile"),
              let p = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile()
        }
        return p
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "user_profile")
        }
        StrainEngine.maxHR = maxHR   // strain zones now use your real age
    }
}

// MARK: - You tab

struct ProfileTab: View {
    @State private var profile = UserProfile.load()

    var body: some View {
        NavigationStack {
            Form {
                Section("About you") {
                    Picker("Sex", selection: $profile.isMale) {
                        Text("Male").tag(true)
                        Text("Female").tag(false)
                    }
                    Stepper("Age: \(profile.age)", value: $profile.age, in: 13...90)
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", value: $profile.weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("kg").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("cm", value: $profile.heightCm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("cm").foregroundStyle(.secondary)
                    }
                }

                Section("How active is your life?") {
                    Picker("Activity", selection: $profile.activity) {
                        ForEach(ActivityLevel.allCases) { level in
                            VStack(alignment: .leading) {
                                Text(level.label)
                                Text(level.detail).font(.caption).foregroundStyle(.secondary)
                            }.tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Goal") {
                    Picker("Goal", selection: $profile.goal) {
                        ForEach(Goal.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Your numbers") {
                    row("Base metabolism (BMR)", "\(Int(profile.bmr)) kcal",
                        "What your body burns doing nothing")
                    row("Maintenance (TDEE)", "\(Int(profile.tdee)) kcal",
                        "Eat this to stay the same weight")
                    row(profile.goal == .bulk ? "Bulking target" : profile.goal == .cut ? "Cutting target" : "Daily target",
                        "\(profile.targetCalories) kcal",
                        profile.goal == .bulk ? "~+350 surplus → ~1–1.5 kg muscle/month with training"
                        : profile.goal == .cut ? "~20% deficit → ~0.5 kg fat loss/week"
                        : "Matches what you burn")
                    row("Protein target", "\(profile.proteinTargetG) g/day",
                        profile.goal == .bulk ? "~1.8 g per kg — essential for muscle growth" : "~1.6 g per kg")
                }
            }
            .navigationTitle("You")
            .onChange(of: profile.age) { _, _ in profile.save() }
            .onChange(of: profile.weightKg) { _, _ in profile.save() }
            .onChange(of: profile.heightCm) { _, _ in profile.save() }
            .onChange(of: profile.isMale) { _, _ in profile.save() }
            .onChange(of: profile.activity) { _, _ in profile.save() }
            .onChange(of: profile.goal) { _, _ in profile.save() }
        }
        .preferredColorScheme(.dark)
    }

    func row(_ title: String, _ value: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(value).bold().foregroundStyle(Theme.green)
            }
            Text(note).font(.caption).foregroundStyle(.secondary)
        }
    }
}
