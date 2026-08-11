import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Accessi grezzi a Firebase.
///
/// Stanno qui e non dentro una feature perche' li usano tutte: tenerli nel
/// profilo, come erano, costringeva il feed e le istantanee a dipendere dal
/// profilo per raggiungere il database.
final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);
