// lib/data/firestore_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai_planner/core/models/item.dart';

class FirestoreRepo {
  FirestoreRepo(this.uid);
  final String uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('items');

  // Yardımcı: DateTime? -> Timestamp?
  Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);
  //  KAYDET
  Future<void> addItem(Item item) async {
    final doc = _col.doc(item.id);
    final map = item.toJson();

    final sortAtTs =
        _ts(item.dueAt ?? item.startAt); // fallback: server timestamp
    await doc.set({
      ...map,
      'startAt_ts': _ts(item.startAt),
      'endAt_ts': _ts(item.endAt),
      'dueAt_ts': _ts(item.dueAt),
      'sortAt_ts': sortAtTs ?? FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  //  GÜNCELLE
  Future<void> updateItem(Item item) async {
    await _col.doc(item.id).update({
      ...item.toJson(),
      'startAt_ts': _ts(item.startAt),
      'endAt_ts': _ts(item.endAt),
      'dueAt_ts': _ts(item.dueAt),
      'sortAt_ts': _ts(item.dueAt ?? item.startAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  //  SİL
  Future<void> deleteItem(String id) async {
    await _col.doc(id).delete();
  }

  //  TAMAMLANDI (tik kutusu)
  Future<void> toggleItem(Item item) async {
    final ref = _col.doc(item.id);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;

        final data = snap.data() as Map<String, dynamic>? ?? {};
        final currentStatus = data['status'];
        final currentDone = data['isDone'] ?? false;
        final doneToday = data['doneToday'] ?? false;

        bool newDone = false;

        // Görev (Task)
        if (item.type == ItemType.task) {
          final isDone = currentStatus == 'done' || currentDone == true;
          newDone = !isDone;
          tx.update(ref, {
            'status': newDone ? 'done' : 'todo',
            'statusCode': newDone ? 1 : 0,
            'isDone': newDone,
            'updatedAt': FieldValue.serverTimestamp(),
            if (newDone) 'completedAt': FieldValue.serverTimestamp(),
          });
        }

        // Alışkanlık (Habit)
        else if (item.type == ItemType.habit) {
          final nowDone = !(doneToday == true);
          tx.update(ref, {
            'doneToday': nowDone,
            'updatedAt': FieldValue.serverTimestamp(),
            if (nowDone) 'lastDoneAt': FieldValue.serverTimestamp(),
          });
        }

        // Etkinlik (Event) -> toggle yok
      });
    } catch (e) {
      print('⚠️ toggleItem hatası: $e');
    }
  }

  //  LİSTE (canlı izleme)
  Stream<List<Item>> watchAll() {
    return _col
        .orderBy('sortAt_ts', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Item.fromJson(d.data())).toList());
  }

  //  TEK SEFERLİK LİSTE
  Future<List<Item>> getAll() async {
    final snap = await _col.orderBy('sortAt_ts', descending: false).get();
    return snap.docs.map((d) => Item.fromJson(d.data())).toList();
  }
}
