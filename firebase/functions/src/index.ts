import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

initializeApp();

const db = getFirestore();

type TransactionRecord = {
  type?: "income" | "expense";
  amount?: number;
  date?: string;
};

function monthKey(dateValue?: string) {
  const date = dateValue || new Date().toISOString().slice(0, 10);
  return date.slice(0, 7).replace("-", "_");
}

export const updateMonthlySummary = onDocumentWritten(
  "mosques/{mosqueId}/transactions/{transactionId}",
  async (event) => {
    const mosqueId = event.params.mosqueId;
    const before = event.data?.before.exists
      ? (event.data.before.data() as TransactionRecord)
      : null;
    const after = event.data?.after.exists
      ? (event.data.after.data() as TransactionRecord)
      : null;

    const affectedMonths = new Set<string>();
    if (before?.date) affectedMonths.add(monthKey(before.date));
    if (after?.date) affectedMonths.add(monthKey(after.date));
    if (!affectedMonths.size) affectedMonths.add(monthKey(after?.date || before?.date));

    await Promise.all(
      [...affectedMonths].map(async (month) => {
        const monthPrefix = month.replace("_", "-");
        const start = `${monthPrefix}-01`;
        const end = `${monthPrefix}-31`;
        const snapshot = await db
          .collection("mosques")
          .doc(mosqueId)
          .collection("transactions")
          .where("date", ">=", start)
          .where("date", "<=", end)
          .get();

        let income = 0;
        let expense = 0;
        snapshot.forEach((doc) => {
          const data = doc.data() as TransactionRecord;
          const amount = Number(data.amount || 0);
          if (data.type === "income") income += amount;
          if (data.type === "expense") expense += amount;
        });

        await db
          .collection("mosques")
          .doc(mosqueId)
          .collection("summaries")
          .doc(`monthly_${month}`)
          .set(
            {
              income,
              expense,
              balance: income - expense,
              updatedAt: FieldValue.serverTimestamp()
            },
            { merge: true }
          );
      })
    );
  }
);

export const requestBackupExport = onCall(async (request) => {
  const uid = request.auth?.uid;
  const mosqueId = request.data?.mosqueId;

  if (!uid || !mosqueId) {
    throw new HttpsError("unauthenticated", "Login and mosqueId are required.");
  }

  const membership = await db.doc(`mosques/${mosqueId}/users/${uid}`).get();
  const role = membership.data()?.role;
  if (!membership.exists || !["owner", "admin"].includes(role)) {
    throw new HttpsError("permission-denied", "Only owner/admin can request backup export.");
  }

  const jobRef = await db.collection(`mosques/${mosqueId}/exportJobs`).add({
    requestedBy: uid,
    status: "queued",
    createdAt: FieldValue.serverTimestamp()
  });

  return { jobId: jobRef.id, status: "queued" };
});
