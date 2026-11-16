# CW-02 #03 — Firebase Cloud Quest (Undergraduate Pathway)

## Platform Target & Run Steps
- **Selected Platform Target:** Flutter Web (`chrome`) connected to the local Firebase Emulator Suite (`auth`, `firestore`, `functions`) on `localhost`.
- **Setup & Run Steps:**
  1. Start the Firebase emulators:
     `firebase emulators:start --only auth,firestore,functions`
  2. Open `http://127.0.0.1:4000/firestore` and seed `challenges/today` with string fields `title` and `prompt`.
  3. Launch the Flutter app in Chrome:
     `flutter run -d chrome`

## Architecture & Trust Boundaries
- **Authentication (`lib/app.dart`):** `StreamBuilder<User?>` listens to `authStateChanges()`, gating `ChallengeScreen` behind sign-in and clearing private state on sign-out.
- **Firestore Security Rules (`firestore.rules`):** `challenges/{challengeId}` allows signed-in reads and denies all client writes. `users/{userId}/progress/{progressId}` allows owner-only reads (`request.auth.uid == userId`) and denies all client writes.
- **Trusted Reward Function (`functions/index.js`):** `completeToday` verifies `request.auth.uid` and uses a Firestore transaction to award `10` points and `"first-quest"` once, returning `alreadyCompleted: true` on retries.
- **Supervised Quest Coach (`functions/questCoach.js`):** `askQuestCoach` validates a non-empty prompt (1–300 chars), derives UID strictly from `request.auth.uid`, calls one read-only helper (`readMyQuestState`), and fails safely without modifying Firestore state.

## Verification Evidence
1. **Signed-Out Auth Gate:** ![Signed Out](evidence/01_signed_out.png)
2. **Signed-In Challenge & Initial Progress:** ![Signed In](evidence/02_signed_in_challenge.png)
3. **Quest Coach Service Error Fallback & Adversarial No-Write Check:** ![Coach Fallback](evidence/03_coach_error_fallback.png)
4. **One-Time Reward & Retry Idempotency (with Firestore Record):** ![Reward and Retry](evidence/04_reward_and_retry.png)

## Reflection
In this implementation, the Quest Coach relies on a single read-only server tool, `readMyQuestState`, which derives the caller's identity strictly from `request.auth.uid` and fetches only `challenges/today` and `users/{uid}/progress/today`. During local emulator testing, I verified both an ordinary hint prompt and an adversarial request asking to ignore instructions and grant 999 points while the Functions emulator endpoint returned a service error. Instead of fabricating quest state or mutating progress, the client caught the `FirebaseFunctionsException` and displayed the safe fallback message `"The coach is unavailable. Try again."`, and inspecting the Firestore Emulator confirmed `users/{uid}/progress/today` remained completely unmodified. One current limitation is that the local Functions emulator endpoint did not stay bound to the web client during testing; a next step would be resolving the local Functions emulator port routing and adding a live Genkit model flow while keeping `readMyQuestState` strictly read-only.
