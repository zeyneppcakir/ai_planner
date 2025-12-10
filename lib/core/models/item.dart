// lib/core/models/item.dart
import 'package:flutter/material.dart';
// Firestore timestamp'larını düzgün parse edebilmek için:
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

enum ItemType { task, event, habit }

enum Category { egitim, kariyer, yasam }

enum TaskStatus { todo, doing, done }

enum RecurrenceFreq { none, daily, weekly, monthly }

class Recurrence {
  final RecurrenceFreq freq;
  final int interval;
  final DateTime? until;

  const Recurrence({
    this.freq = RecurrenceFreq.none,
    this.interval = 1,
    this.until,
  });

  Map<String, dynamic> toJson() => {
        'freq': freq.name,
        'interval': interval,
        'until': until?.toIso8601String(),
      };

  factory Recurrence.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const Recurrence();
    return Recurrence(
      freq: RecurrenceFreq.values.firstWhere(
        (e) => e.name == (j['freq'] ?? 'none'),
        orElse: () => RecurrenceFreq.none,
      ),
      interval: (j['interval'] is int)
          ? j['interval'] as int
          : int.tryParse('${j['interval'] ?? 1}') ?? 1,
      until: _toDt(j['until']),
    );
  }

  Recurrence copyWith({RecurrenceFreq? freq, int? interval, DateTime? until}) {
    return Recurrence(
      freq: freq ?? this.freq,
      interval: interval ?? this.interval,
      until: until ?? this.until,
    );
  }

  bool get isRepeating => freq != RecurrenceFreq.none;
}

// Yardımcı: dynamic -> DateTime?
DateTime? _toDt(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

// Yardımcı: dynamic -> bool?
bool? _toBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final t = v.toLowerCase().trim();
    if (t == 'true' || t == '1' || t == 'yes') return true;
    if (t == 'false' || t == '0' || t == 'no') return false;
  }
  return null;
}

// Priority yi güvenli şekilde 1–3 aralığına çeker.
int _clampPriority(int? v) {
  final p = v ?? 1;
  if (p < 1) return 1;
  if (p > 3) return 3;
  return p;
}

class Item {
  final String id;
  final ItemType type;
  final Category category;
  final String title;

  // Öğeye özel emoji; null ise kategori varsayılanı kullanılır.
  final String? emoji;

  // Zaman alanları
  final bool allDay;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? dueAt;

  // Tahmini süre (dakika cinsinden). Kullanıcı isterse boş bırakabilir.
  final int? estimatedMinutes;

  // Tekrarlama & hatırlatma
  final Recurrence recurrence;
  final int? remindMinutes;

  // Diğer
  final List<String> tags;

  // 1: düşük, 2: orta, 3: yüksek
  final int priority;

  final String? notes;

  // Türlere özel
  final TaskStatus? status; // sadece task
  final bool? doneToday; // sadece habit

  const Item({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    this.emoji,
    this.allDay = false,
    this.startAt,
    this.endAt,
    this.dueAt,
    this.estimatedMinutes,
    this.recurrence = const Recurrence(),
    this.remindMinutes,
    this.tags = const [],
    this.priority = 1,
    this.notes,
    this.status,
    this.doneToday,
  });

  Item copyWith({
    String? id,
    ItemType? type,
    Category? category,
    String? title,
    String? emoji,
    bool? allDay,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? dueAt,
    int? estimatedMinutes,
    Recurrence? recurrence,
    int? remindMinutes,
    List<String>? tags,
    int? priority,
    String? notes,
    TaskStatus? status,
    bool? doneToday,
  }) {
    return Item(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category ?? this.category,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      allDay: allDay ?? this.allDay,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      dueAt: dueAt ?? this.dueAt,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      recurrence: recurrence ?? this.recurrence,
      remindMinutes: remindMinutes ?? this.remindMinutes,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      doneToday: doneToday ?? this.doneToday,
    );
  }

  // Ekranda kullanmak için 1–3 garantili öncelik değeri
  int get effectivePriority => _clampPriority(priority);

  bool isToday(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    bool sameDay(DateTime t) =>
        t.year == d.year && t.month == d.month && t.day == d.day;

    if (type == ItemType.event && startAt != null) return sameDay(startAt!);

    if (type == ItemType.task) {
      if (startAt != null) return sameDay(startAt!);
      if (dueAt != null) return sameDay(dueAt!);
      return true;
    }

    if (type == ItemType.habit) return true;
    return false;
  }

  // Kategori ilerleme hesapları için “tamamlanmış mı?”
  bool isCompleted() {
    final now = DateTime.now();

    // Görev: kullanıcı tik atınca tamamlanmış
    if (type == ItemType.task) {
      return status == TaskStatus.done;
    }

    // Alışkanlık: bugün yapıldıysa tamamlanmış say
    if (type == ItemType.habit) {
      return doneToday == true;
    }

    // Etkinlik: tarihi (dueAt / endAt / startAt) geçtiyse tamamlanmış kabul et
    if (type == ItemType.event) {
      final dt = dueAt ?? endAt ?? startAt;
      if (dt == null) return false;
      return now.isAfter(dt);
    }

    return false;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'category': category.name,
        'title': title,
        'emoji': emoji,
        'allDay': allDay,
        'startAt': startAt?.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'dueAt': dueAt?.toIso8601String(),
        'estimatedMinutes': estimatedMinutes,
        'recurrence': recurrence.toJson(),
        'remindMinutes': remindMinutes,
        'tags': tags,
        'priority': priority,
        'notes': notes,
        'status': status?.name,
        'doneToday': doneToday,
      };

  factory Item.fromJson(Map<String, dynamic> j) {
    // Eski/çeşitli alan adları için uyumluluk
    final id = (j['id'] ?? j['docId'] ?? '').toString();
    final title = (j['title'] ?? j['name'] ?? '').toString();

    // Not alanı farklı anahtarlarla gelmiş olabilir
    final notes = (j['notes'] ??
            j['note'] ??
            j['not'] ??
            j['aciklama'] ??
            j['desc'] ??
            j['description'] ??
            j['notes_txt'])
        ?.toString();

    // tür/kategori güvenli parse
    final type = ItemType.values.firstWhere(
      (e) => e.name == (j['type'] ?? 'task'),
      orElse: () => ItemType.task,
    );
    final category = Category.values.firstWhere(
      (e) => e.name == (j['category'] ?? 'yasam'),
      orElse: () => Category.yasam,
    );

    // zaman alanları hem ISO string hem Timestamp olabilir (ek anahtarlar eklendi)
    final startAt = _toDt(j['startAt'] ?? j['start_ts'] ?? j['startAt_ts']);
    final endAt = _toDt(j['endAt'] ?? j['end_ts'] ?? j['endAt_ts']);
    final dueAt = _toDt(j['dueAt'] ??
        j['deadline'] ??
        j['due'] ??
        j['due_ts'] ??
        j['dueAt_ts']);

    // allDay güvenli bool
    final allDay = _toBool(j['allDay']) ?? false;

    // status yoksa ama 'done' bool'u varsa onu statüye çevir
    TaskStatus? status;
    if (j['status'] != null) {
      status = TaskStatus.values.firstWhere(
        (e) => e.name == j['status'],
        orElse: () => TaskStatus.todo,
      );
    } else {
      final done = _toBool(j['done']);
      if (done != null) {
        status = done ? TaskStatus.done : TaskStatus.todo;
      }
    }

    // alışkanlıklar için doneToday, bazı kayıtlarda 'done' olarak da gelmiş olabilir
    final doneToday = _toBool(j['doneToday'] ?? j['done']);

    // tags güvenli cast
    final tagsRaw = (j['tags'] as List?) ?? const [];
    final tags = tagsRaw.map((e) => e.toString()).toList();

    // recurrence map ise parse et
    final recurrence = Recurrence.fromJson(
      j['recurrence'] is Map
          ? (j['recurrence'] as Map).cast<String, dynamic>()
          : null,
    );

    // priority güvenli parse + 1–3 aralığına çek
    int? rawPriority;
    if (j['priority'] is int) {
      rawPriority = j['priority'] as int;
    } else {
      rawPriority = int.tryParse('${j['priority'] ?? ''}');
    }

    return Item(
      id: id,
      type: type,
      category: category,
      title: title,
      emoji: j['emoji'] as String?,
      allDay: allDay,
      startAt: startAt,
      endAt: endAt,
      dueAt: dueAt,
      estimatedMinutes: (j['estimatedMinutes'] is int)
          ? j['estimatedMinutes'] as int
          : int.tryParse('${j['estimatedMinutes'] ?? ''}'),
      recurrence: recurrence,
      remindMinutes: (j['remindMinutes'] is int)
          ? j['remindMinutes'] as int
          : int.tryParse('${j['remindMinutes'] ?? ''}'),
      tags: tags,
      priority: _clampPriority(rawPriority),
      notes: notes,
      status: status,
      doneToday: doneToday,
    );
  }
}

class CategoryStyle {
  final Color color;
  final String emoji;
  const CategoryStyle(this.color, this.emoji);
}

const Map<Category, CategoryStyle> defaultCategoryStyles = {
  Category.egitim: CategoryStyle(Colors.blue, '🎓'),
  Category.kariyer: CategoryStyle(Colors.purple, '💼'),
  Category.yasam: CategoryStyle(Colors.green, '🌿'),
};

extension CategoryX on Category {
  String get label {
    switch (this) {
      case Category.egitim:
        return 'Eğitim';
      case Category.kariyer:
        return 'Kariyer';
      case Category.yasam:
        return 'Yaşam';
    }
  }

  String get defaultEmoji => defaultCategoryStyles[this]!.emoji;
  Color get defaultColor => defaultCategoryStyles[this]!.color;
  CategoryStyle get defaultStyle => defaultCategoryStyles[this]!;
}
