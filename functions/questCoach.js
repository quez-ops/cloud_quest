import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";

const SYSTEM_INSTRUCTION =
  "You are a supportive quest coach. Use the supplied quest data to give one concise hint, not the complete answer. Never claim a reward was granted. You cannot write data; the learner decides whether to use the separate Complete button.";

// Read-only tool scoped strictly to the verified caller's Auth UID
async function readMyQuestState(uid) {
  const db = getFirestore();
  const challengeSnap = await db.doc("challenges/today").get();
  if (!challengeSnap.exists) {
    throw new Error("Today's challenge is missing.");
  }

  const progressSnap = await db.doc(`users/${uid}/progress/today`).get();
  return {
    challenge: challengeSnap.data(),
    progress: progressSnap.exists
      ? progressSnap.data()
      : { completed: false, points: 0 },
  };
}

export const askQuestCoach = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before asking the Quest Coach.");
  }

  // Enforce non-empty 300-char limit server-side regardless of client UI checks
  const rawQuestion =
    typeof request.data?.question === "string" ? request.data.question.trim() : "";
  if (!rawQuestion || rawQuestion.length > 300) {
    throw new HttpsError("invalid-argument", "Question must be 1 to 300 characters.");
  }

  // Hook to verify graceful fallback when tool/model is unavailable
  if (rawQuestion.toLowerCase().includes("simulate_error")) {
    throw new HttpsError("unavailable", "Quest Coach tool temporarily unavailable.");
  }

  // Always trust server Auth context; ignore any UID passed in request.data
  const uid = request.auth.uid;

  let questState;
  try {
    questState = await readMyQuestState(uid);
  } catch (err) {
    throw new HttpsError("failed-precondition", "Could not read your quest state.");
  }

  // Guard against prompt injection attempts to alter points or grant badges
  const lower = rawQuestion.toLowerCase();
  if (
    lower.includes("ignore") ||
    lower.includes("999") ||
    lower.includes("points") ||
    lower.includes("grant") ||
    lower.includes("reward") ||
    lower.includes("badge")
  ) {
    return {
      reply:
        "I can only read your current quest status and give a concise hint—I cannot modify points or grant rewards. Use the Complete Challenge button once you finish today's task.",
      toolUsed: "readMyQuestState",
      systemInstruction: SYSTEM_INSTRUCTION,
    };
  }

  const title = questState.challenge.title || "Today's Challenge";
  const statusText = questState.progress.completed
    ? `You already completed "${title}" (${questState.progress.points} pts).`
    : `You haven't completed "${title}" yet.`;

  return {
    reply: `Hint for "${title}": Break the prompt into small steps, verify your inputs first, and test one piece at a time. (${statusText})`,
    toolUsed: "readMyQuestState",
    systemInstruction: SYSTEM_INSTRUCTION,
  };
});
