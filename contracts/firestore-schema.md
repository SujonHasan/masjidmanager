# Firestore Schema

```txt
mosques/{mosqueId}
  users/{uid}
  categories/{categoryId}
  transactions/{transactionId}
  members/{memberId}
  documents/{documentId}
  announcements/{announcementId}
  prayerTimes/{scheduleId}
  summaries/{summaryId}
  auditLogs/{logId}
  deletedItems/{deletedItemId}

users/{uid}
plans/{planId}
subscriptions/{subscriptionId}
```

All mosque-owned records must include `mosqueId`, `createdAt`, and `updatedAt` where relevant.
