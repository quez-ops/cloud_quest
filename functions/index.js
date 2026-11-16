import { onCall, HttpsError } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
export { askQuestCoach } from "./questCoach.js";

initializeApp();
const db = getFirestore();

export const completeToday = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  if (request.data?.challengeId !== "today") {
    throw new HttpsError("invalid-argument", "Unknown challenge.");
  }

  const uid = request.auth.uid;
  const progressRef = db.doc(`users/${uid}/progress/today`);

  // Transaction ensures idempotency so duplicate calls never double-award points
  return db.runTransaction(async (transaction) => {
    const progress = await transaction.get(progressRef);
    if (progress.exists) {
      return {
        completed: true,
        points: progress.data().points,
        badgeId: progress.data().badgeId,
        alreadyCompleted: true,
      };
    }

    // Reward values are hardcoded server-side so client payloads cannot tamper with them
    const reward = {
      completed: true,
      points: 10,
      badgeId: "first-quest",
      completedAt: FieldValue.serverTimestamp(),
    };
    transaction.set(progressRef, reward);

    return {
      completed: true,
      points: reward.points,
      badgeId: reward.badgeId,
      alreadyCompleted: false,
    };
  });
});
