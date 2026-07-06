import SwiftUI

@main
struct PulseApp: App {
    @StateObject private var health = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(health)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var health: HealthKitManager

    var body: some View {
        Group {
            if health.isAuthorized {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var health: HealthKitManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Pulse")
                .font(.largeTitle.bold())
            Text("Recovery, Strain and Sleep scores\nfrom your Apple Watch.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await health.requestAuthorization() }
            } label: {
                Text("Connect Apple Health")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}
