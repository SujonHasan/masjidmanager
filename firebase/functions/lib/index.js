"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requestBackupExport = exports.updateMonthlySummary = void 0;
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const firestore_2 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
(0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
function monthKey(dateValue) {
    const date = dateValue || new Date().toISOString().slice(0, 10);
    return date.slice(0, 7).replace("-", "_");
}
exports.updateMonthlySummary = (0, firestore_2.onDocumentWritten)("mosques/{mosqueId}/transactions/{transactionId}", async (event) => {
    const mosqueId = event.params.mosqueId;
    const before = event.data?.before.exists
        ? event.data.before.data()
        : null;
    const after = event.data?.after.exists
        ? event.data.after.data()
        : null;
    const affectedMonths = new Set();
    if (before?.date)
        affectedMonths.add(monthKey(before.date));
    if (after?.date)
        affectedMonths.add(monthKey(after.date));
    if (!affectedMonths.size)
        affectedMonths.add(monthKey(after?.date || before?.date));
    await Promise.all([...affectedMonths].map(async (month) => {
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
            const data = doc.data();
            const amount = Number(data.amount || 0);
            if (data.type === "income")
                income += amount;
            if (data.type === "expense")
                expense += amount;
        });
        await db
            .collection("mosques")
            .doc(mosqueId)
            .collection("summaries")
            .doc(`monthly_${month}`)
            .set({
            income,
            expense,
            balance: income - expense,
            updatedAt: firestore_1.FieldValue.serverTimestamp()
        }, { merge: true });
    }));
});
exports.requestBackupExport = (0, https_1.onCall)(async (request) => {
    const uid = request.auth?.uid;
    const mosqueId = request.data?.mosqueId;
    if (!uid || !mosqueId) {
        throw new https_1.HttpsError("unauthenticated", "Login and mosqueId are required.");
    }
    const membership = await db.doc(`mosques/${mosqueId}/users/${uid}`).get();
    const role = membership.data()?.role;
    if (!membership.exists || !["owner", "admin"].includes(role)) {
        throw new https_1.HttpsError("permission-denied", "Only owner/admin can request backup export.");
    }
    const jobRef = await db.collection(`mosques/${mosqueId}/exportJobs`).add({
        requestedBy: uid,
        status: "queued",
        createdAt: firestore_1.FieldValue.serverTimestamp()
    });
    return { jobId: jobRef.id, status: "queued" };
});
//# sourceMappingURL=index.js.map