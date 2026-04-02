# BlinkBreak
**A Sci-Fi AR Ocular Combat Trainer & Eye Health Gamification System**

Welcome to **BlinkBreak**, a cyberpunk-themed anti-gravity spaceship game built entirely in Swift and SwiftUI. This is not just a game—it's a **"health-as-a-game"** system designed to combat digital eye strain through advanced ARKit facial tracking.

<p align="center">
  <img src="BlinkBreak.swiftpm/Assets/hangar.png" width="30%" />
  <img src="BlinkBreak.swiftpm/Assets/calibration.png" width="30%" />
  <img src="BlinkBreak.swiftpm/Assets/gameplay.png" width="30%" />
</p>

---

## 🚀 The Mission
Digital eye strain affects millions of developers and gamers. **BlinkBreak** transforms eye health best practices (like the 20-20-20 rule and frequent blinking) into an immersive AAA-style arcade experience.

Navigate deep space, dodge asteroids, and purge digital glitches using nothing but the movement of your eyes.

## ✨ Core Features

* **AR Ocular Controls**: Steer your ship by looking up and down. Fire your laser cannons by double-blinking. Perform barrel rolls and phase through obstacles by tilting your head ("Ghost Mode").
* **Vision Index Gamification**: Your in-game performance translates to a real-world "Vision Index" score. Maintain healthy blink rates and avoid staring to score high.
* **Modular Hangar System**: Unlock, equip, and customize vector-drawn ship models with the XP you earn from daily bounties.
* **Daily Bounties & Streaks**: Infinite, real-time mission generation system to keep you tracking your health daily.
* **Tactical Reminders & Health Protocols**: A smart, non-intrusive local notification system that gently reminds you to recalibrate your focus and protect your daily streak.
* **Neural Performance Reports**: Glassmorphic analytics dashboards tracking your ocular health history, blink rates, and strain reduction.

## 🛠 Tech Stack

* **Platform**: iOS / iPadOS
* **Language**: Swift 6
* **Frameworks**: 
  * `SwiftUI` (UI, animations, glassmorphism, vector graphics)
  * `ARKit` (Real-time TrueDepth facial geometry tracking)
  * `SpriteKit` (2D physics and rendering engine)
  * `AVFoundation` (Synthesizer hums and dynamic audio)
  * `UserNotifications` (Local, schedule-based health alerts)

## 🎮 How to Play

1. **System Calibration**: Hold your device at face level. Let the holographic AR scanner lock onto your biometric optical data.
2. **Look to Move**: Glance up and down to steer your ship through the asteroid fields.
3. **Blink to Attack**: Execute a double-blink to fire your laser projectiles and purge enemy glitches.
4. **Ghost Mode**: Tilt your head side-to-side to phase through incoming hazards.
5. **Monitor Your Strain**: Watch your Shield HP. If you stare too long without blinking, your shields will drop, and visual static will distort your HUD.
6. **Take Breaks**: Respect the 20-20-20 rule. Pause the game, look 20 feet away for 20 seconds, and return to the fight.

## 🔒 Privacy First
BlinkBreak operates **100% locally** on your device. We use the TrueDepth camera solely to control your ship and track eye health metrics during gameplay.
* **No network requests for tracking.**
* **No video or image data is ever saved or transmitted.**
* **All health reports are stored securely via `@AppStorage`.**

## 🏁 Getting Started

To run BlinkBreak:
1. Open `BlinkBreak.swiftpm` in **Swift Playgrounds** on iPad / Mac, or **Xcode** on macOS.
2. Ensure your target device has a TrueDepth camera system (Face ID enabled device).
3. Build and Run! 

---
*“Ocular systems standing by. Time to recalibrate your focus, Pilot.”*
