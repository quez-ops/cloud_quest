# Cloud Quest (CW-02 #03 — Firebase Cloud Services)

**Pathway:** Undergraduate  
**Target Platform:** Flutter Web (Chrome) connected to the local Firebase Emulator Suite (auth, firestore, functions) on localhost.

## How to Run Locally
1. Start the local Firebase emulators from the project root:
   `firebase emulators:start --only auth,firestore,functions`
2. Open the Firestore Emulator UI (`[http://127.0.0.1:4000/firestore](http://127.0.0.1:4000/firestore)`) and add a document at `challenges/today` with two string fields: `title` and `prompt`.
3. In a second terminal, launch the Flutter app in Chrome:
   `flutter run -d chrome`

## How Security & Boundaries Are Set Up
- **Sign-In Gate (`lib/app.dart`):** Uses `StreamBuilder<User?>` with `authStateChanges()` so unauthenticated users only see the sign-in/register screen, and signing out clears private quest data from the UI.
- **Firestore Rules (`firestore.rules`):** Any signed-in user can read `challenges/today`, while `users/{uid}/progress/today` can only be read by that specific user. All direct client writes are blocked.
- **Trusted Reward Function (`functions/index.js`):** `completeToday` checks `request.auth.uid` on the server and runs a Firestore transaction to award `10` points and the `"first-quest"` badge once, ignoring duplicate clicks.
- **Quest Coach (`functions/questCoach.js`):** `askQuestCoach` validates the user's session and prompt length (1–300 characters), reads only the caller's own quest data through `readMyQuestState`, and has zero write access to Firestore.

## Test Evidence
1. **Signed-Out View:** ![Signed Out](evidence/01_signed_out.png)
2. **Signed-In Challenge & Starting Progress:** ![Signed In](evidence/02_signed_in_challenge.png)
3. **Quest Coach Fallback & Adversarial Check:** ![Coach Fallback](evidence/03_coach_error_fallback.png)
4. **Reward Completion & Retry Check:** ![Reward and Retry](evidence/04_reward_and_retry.png)

## Reflection
For the Quest Coach, I set up a single read-only helper function (`readMyQuestState`) that pulls the user's ID directly from `request.auth.uid` and only reads `challenges/today` and `users/{uid}/progress/today`. When I tested the coach in the local emulator with both a normal hint request and an adversarial prompt asking it to ignore its rules and give me 999 points, the Functions endpoint threw a service error. Instead of crashing or making up fake progress, the Flutter app caught the error cleanly and displayed `"The coach is unavailable. Try again."`, and checking the Firestore Emulator showed that `users/{uid}/progress/today` stayed untouched. The main limitation right now is that the local Functions emulator endpoint dropped its connection during testing, so my next step would be fixing that port routing and wiring up a live Genkit model flow while keeping `readMyQuestState` strictly read-only.
