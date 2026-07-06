# Pulse

A WHOOP-style Recovery / Strain / Sleep app for iPhone + Apple Watch — no band, no subscription. Reads your Apple Watch data via HealthKit and computes:

- **Recovery (0–100%)** — overnight HRV + resting heart rate vs. your 30-day personal baseline, plus sleep performance
- **Strain (0–21)** — logarithmic cardio-load score from heart-rate zones, WHOOP-style
- **Sleep** — stages (Deep/REM/Core), efficiency, sleep debt, and tonight's sleep-need target
- **Calories** — active + resting

## Requirements

- iPhone with iOS 17+, Apple Watch (SE or later) worn during sleep
- Mac with Xcode to build/install (see [SETUP.md](SETUP.md))

## Build

```bash
brew install xcodegen
xcodegen generate
open Pulse.xcodeproj
```

Then select your device and Run. Full step-by-step instructions in [SETUP.md](SETUP.md).

## Structure

- `Pulse/Engines.swift` — the scoring algorithms (recovery, strain, sleep need)
- `Pulse/HealthKitManager.swift` — HealthKit queries and daily metric assembly
- `Pulse/DashboardView.swift` — the dashboard UI
- `.github/workflows/build.yml` — CI compile check on macOS runners

🤖 Built with [Claude Code](https://claude.com/claude-code)
