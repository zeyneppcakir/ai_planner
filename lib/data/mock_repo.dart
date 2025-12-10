// lib/data/mock_repo.dart
import 'package:ai_planner/core/models/item.dart';

// Yalnızca geliştirme/önizleme için mock veri üretir.
// Uygulama açıldığında HomeScreen, buradan gelen listeyi belleğe kopyalar.
class MockRepo {
  int _id = 0;
  String _nextId() {
    _id += 1;
    return _id.toString();
  }

  // Bugün için örnek veri
  List<Item> todayItems() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day, 9);

    return [
      // Eğitim
      Item(
        id: _nextId(),
        type: ItemType.task,
        category: Category.egitim,
        title: 'Algoritma ödevi',
        dueAt: base.add(const Duration(hours: 6)), // 15:00
        tags: const ['ödev', 'okul'],
        status: TaskStatus.doing,
      ),
      Item(
        id: _nextId(),
        type: ItemType.task,
        category: Category.egitim,
        title: 'Tez yazımı (2 saat)',
        startAt: base.add(const Duration(hours: 12)), // 21:00
        endAt: base.add(const Duration(hours: 14)), // 23:00
        tags: const ['tez'],
        status: TaskStatus.todo,
      ),

      // Kariyer
      Item(
        id: _nextId(),
        type: ItemType.event,
        category: Category.kariyer,
        title: 'Müşteri toplantısı',
        startAt: base.add(const Duration(hours: 2)), // 11:00
        endAt: base.add(const Duration(hours: 3)), // 12:00
        tags: const ['toplantı', 'iş'],
      ),

      // Yaşam
      Item(
        id: _nextId(),
        type: ItemType.habit,
        category: Category.yasam,
        title: '30 dk yürüyüş',
        tags: const ['spor', 'sağlık'],
        doneToday: false,
      ),
      Item(
        id: _nextId(),
        type: ItemType.task,
        category: Category.yasam,
        title: '20 sayfa kitap',
        tags: const ['okuma', 'hobi'],
        status: TaskStatus.todo,
      ),
    ];
  }
}
