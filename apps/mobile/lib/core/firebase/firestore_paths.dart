class FirestorePaths {
  const FirestorePaths._();

  static String mosque(String mosqueId) => 'mosques/$mosqueId';
  static String mosqueUsers(String mosqueId) => 'mosques/$mosqueId/users';
  static String categories(String mosqueId) => 'mosques/$mosqueId/categories';
  static String transactions(String mosqueId) =>
      'mosques/$mosqueId/transactions';
  static String members(String mosqueId) => 'mosques/$mosqueId/members';
  static String documents(String mosqueId) => 'mosques/$mosqueId/documents';
  static String announcements(String mosqueId) =>
      'mosques/$mosqueId/announcements';
  static String prayerTimes(String mosqueId) => 'mosques/$mosqueId/prayerTimes';
  static String summaries(String mosqueId) => 'mosques/$mosqueId/summaries';
}
