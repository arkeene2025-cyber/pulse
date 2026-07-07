import SwiftUI
import PhotosUI

struct FoodTab: View {
    @EnvironmentObject var health: HealthKitManager
    @StateObject private var store = MealStore()

    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var showSettings = false

    var caloriesOut: Int {
        Int((health.today?.activeCalories ?? 0) + (health.today?.basalCalories ?? 0))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BalanceCard(caloriesIn: store.todaysCaloriesIn, caloriesOut: caloriesOut)

                    HStack(spacing: 12) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Scan meal", systemImage: "camera.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.green, in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(.black)
                        }
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.headline)
                                .padding()
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    if isScanning {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Analyzing your meal…").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding()
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                    }

                    ForEach(store.todaysMeals().reversed()) { meal in
                        MealCard(meal: meal) { store.delete(meal) }
                    }

                    if store.todaysMeals().isEmpty && !isScanning {
                        Text("No meals logged today.\nSnap a photo of your plate and I'll estimate the calories. 📸")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .card()
                    }
                }
                .padding(.horizontal)
            }
            .background(Theme.bg)
            .navigationTitle("Food")
            .toolbar {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in Task { await scan(image) } }
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showSettings) { APIKeySettings() }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await scan(image)
                    }
                    photoItem = nil
                }
            }
        }
    }

    func scan(_ image: UIImage) async {
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }
        do {
            let est = try await ClaudeService.estimateMeal(from: image)
            store.add(Meal(date: Date(), name: est.meal_name, items: est.items,
                           calories: est.calories, proteinG: est.protein_g,
                           carbsG: est.carbs_g, fatG: est.fat_g, confidence: est.confidence))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BalanceCard: View {
    let caloriesIn: Int
    let caloriesOut: Int

    private let profile = UserProfile.load()

    var target: Int { profile.targetCalories }
    var remaining: Int { target - caloriesIn }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                stat(value: caloriesIn, label: "Eaten", color: Theme.green)
                stat(value: target, label: goalLabel, color: Theme.blue)
                stat(value: remaining, label: remaining >= 0 ? "Left to eat" : "Over target",
                     color: remaining >= 0 ? Theme.green : Theme.yellow)
                stat(value: caloriesOut, label: "Burned", color: .orange)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 10)
                    Capsule().fill(Theme.green.gradient)
                        .frame(width: min(geo.size.width * Double(caloriesIn) / Double(max(target, 1)), geo.size.width), height: 10)
                }
            }
            .frame(height: 10)

            Text(statusLine)
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }

    var goalLabel: String {
        switch profile.goal {
        case .bulk: return "Bulk target"
        case .cut: return "Cut target"
        case .maintain: return "Target"
        }
    }

    var statusLine: String {
        if profile.goal == .bulk {
            return remaining > 0
                ? "Eat \(remaining) more kcal to hit your bulking target — don't skip it, this is where the muscle comes from."
                : "Bulking target hit ✅ — surplus achieved for today."
        } else {
            return remaining >= 0
                ? "\(remaining) kcal left within your target."
                : "You're \(-remaining) kcal over target today."
        }
    }

    func stat(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title3.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MealCard: View {
    let meal: Meal
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.name).font(.headline)
                    Text(meal.date.formatted(date: .omitted, time: .shortened) + " · " + meal.confidence + " confidence")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(meal.calories) kcal").font(.title3.bold()).foregroundStyle(Theme.green)
            }
            Text(meal.items.joined(separator: " · "))
                .font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                macro("P", meal.proteinG, Theme.blue)
                macro("C", meal.carbsG, Theme.yellow)
                macro("F", meal.fatG, Theme.purple)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").font(.caption)
                }
            }
        }
        .card()
    }

    func macro(_ label: String, _ grams: Int, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.caption2.bold()).foregroundStyle(color)
            Text("\(grams)g").font(.caption)
        }
    }
}

struct APIKeySettings: View {
    @State private var key = ClaudeService.apiKey
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-...", text: $key)
                } header: {
                    Text("Anthropic API key")
                } footer: {
                    Text("Get one at console.anthropic.com → API Keys. Each meal scan costs roughly ₹1–3. The key is stored only on this device.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        ClaudeService.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// UIKit camera bridge — SwiftUI has no native camera view.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
