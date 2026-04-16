import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/firebase/firestore_paths.dart';

class FirestoreCollections {
  FirestoreCollections({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> categories(String mosqueId) {
    return firestore.collection(FirestorePaths.categories(mosqueId));
  }

  CollectionReference<Map<String, dynamic>> transactions(String mosqueId) {
    return firestore.collection(FirestorePaths.transactions(mosqueId));
  }

  CollectionReference<Map<String, dynamic>> members(String mosqueId) {
    return firestore.collection(FirestorePaths.members(mosqueId));
  }

  CollectionReference<Map<String, dynamic>> announcements(String mosqueId) {
    return firestore.collection(FirestorePaths.announcements(mosqueId));
  }

  CollectionReference<Map<String, dynamic>> prayerTimes(String mosqueId) {
    return firestore.collection(FirestorePaths.prayerTimes(mosqueId));
  }
}
