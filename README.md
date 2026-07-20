# 🌿 goodTimeJournal

A modern Flutter mobile application based on the **Good Time Journal** concept from the best-selling book ***"Designing Your Life"*** by Bill Burnett and Dave Evans (Stanford Design Lab).

---

## 🎯 What the App Does

The **goodTimeJournal** app helps you track your daily activities to discover what energizes you, what drains you, and when you enter a state of deep flow.

### Key Features:
- **Log Daily Activities**: Record what you were doing with double-gauge ratings:
  - **Engagement Rating (0 - 10)**: How engaged or focused were you?
  - **Energy & Goodness Rating (0 - 10)**: Did this activity give you energy or drain you?
- **Flow State Tracking ⚡**: Checkbox to mark activities where you experienced deep focus, lost track of time, and felt completely immersed.
- **AEIOU Guidance Prompts 💡**: A non-intrusive, expandable helper based on the AEIOU framework (*Activities, Environments, Interactions, Objects, Users*) to help you describe activities with precision without getting in your way while typing.
- **Journal History & Advanced Filtering**:
  - Filter entries by Engagement score range.
  - Filter entries by Energy/Goodness score range.
  - Filter by Flow state (*All*, *Flow Only*, *Non-Flow*).
- **Edit & Manage Entries**: Edit any past journal entry (activity text, ratings, flow state, timestamp).
- **CSV Data Import & Export 📊**: Export your journal entries directly to your device's **Downloads** folder in CSV format (`date,activity,engagement,goodness,isFlow`), or import previously exported CSV logs.
- **Dark & Light Mode**: Sleek, responsive theme switching.

---

## 🚀 How to Run the Project

### Prerequisites

Ensure you have the following installed on your machine:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version ^3.12.0)
- Dart SDK (included with Flutter)
- Android Studio / Xcode or VS Code with Flutter extension
- An Android Emulator, iOS Simulator, or connected physical device

### Getting Started

1. **Clone or navigate to the repository:**
   ```bash
   cd goodTimeJournalApp
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run static analysis (optional):**
   ```bash
   flutter analyze
   ```

4. **Launch the application:**
   ```bash
   flutter run
   ```
