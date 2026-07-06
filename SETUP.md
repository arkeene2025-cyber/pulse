# Pulse — Setup Guide (friend's Mac, ~30 minutes)

Your WHOOP-style app: Recovery, Strain, Sleep, Calories from your Apple Watch SE.

## What to bring
- This `pulse` folder (USB drive, or push to GitHub and clone on the Mac)
- Your iPhone + its cable
- Your Apple ID password

## On the Mac

1. **Install Xcode** from the Mac App Store (free, large download — ask your friend to pre-install it before you visit).
2. Open Xcode → **File → New → Project → iOS App**.
   - Product Name: `Pulse`
   - Interface: SwiftUI, Language: Swift
   - Team: sign in with your Apple ID (Xcode → Settings → Accounts → add Apple ID, then select it as Team)
3. In the new project, **delete** the generated `ContentView.swift` and `PulseApp.swift`, then drag all four `.swift` files from this folder's `Pulse/` directory into the project (check "Copy items if needed").
4. Click the project → target **Pulse** → **Signing & Capabilities**:
   - Enable "Automatically manage signing"
   - Click **+ Capability** → add **HealthKit**
5. Target → **Info** tab → add key:
   - `Privacy - Health Share Usage Description` = `Pulse reads your Apple Watch data to calculate Recovery, Strain and Sleep scores.`
6. Plug in your iPhone → select it as the run destination (top bar) → press **Run (⌘R)**.
   - First time: on iPhone go to Settings → General → VPN & Device Management → trust your developer certificate.
   - iPhone may ask to enable Developer Mode (Settings → Privacy & Security → Developer Mode → on → restart).
7. App launches → tap **Connect Apple Health** → allow ALL categories.

## Important limits

- **Free Apple ID: app expires after 7 days** — you must re-run from Xcode weekly.
- **Paid Apple Developer account (₹8,000/yr): installs last 1 year** + TestFlight support. Recommended once you know you'll use it daily.

## Daily habit
- Wear the watch to sleep (enable Sleep Focus for better HRV sampling)
- Charge it while showering / getting ready
- Recovery scores get accurate after ~2 weeks of baseline data (works from day 1, improves with history)
