import 'package:flutter/material.dart';
import '../../../core/models/item.dart';

typedef ItemCallback = void Function(Item);

class ItemTile extends StatelessWidget {
  final Item item;
  final ItemCallback? onToggle; // tamamlandı / doneToday toggle
  final ItemCallback? onEdit;
  final ItemCallback? onDelete;

  const ItemTile({
    super.key,
    required this.item,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  //  Durum yardımcıları
  bool get _isTask => item.type == ItemType.task;
  bool get _isHabit => item.type == ItemType.habit;

  bool get _taskDone {
    return item.status == TaskStatus.done;
  }

  bool get _habitDoneToday {
    return (item.doneToday ?? false);
  }

  IconData _leadingIcon() {
    if (_isTask) {
      return _taskDone ? Icons.check_box : Icons.check_box_outline_blank;
    } else if (_isHabit) {
      return _habitDoneToday ? Icons.task_alt : Icons.radio_button_unchecked;
    }
    return Icons.event; // Etkinlik
  }

  Color? _leadingColor(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    if (_isTask) {
      return _taskDone ? cs.primary : null;
    } else if (_isHabit) {
      return _habitDoneToday ? cs.primary : null;
    }
    return cs.tertiary; // event
  }

  String _fmt(DateTime dt, {bool allDay = false}) {
    final d =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    if (allDay) return d;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d  $hh:$mm';
  }

  // Türkçe karakter sadeleştirme (karşılaştırma için)
  String _baseTagKey(String s) {
    const map = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'Ç': 'c',
      'Ğ': 'g',
      'İ': 'i',
      'I': 'i',
      'Ö': 'o',
      'Ş': 's',
      'Ü': 'u',
    };

    final buffer = StringBuffer();
    for (final code in s.runes) {
      final ch = String.fromCharCode(code);
      buffer.write(map[ch] ?? ch);
    }
    return buffer.toString();
  }

  // Kötü yazılmış / kısaltılmış etiketleri düzgün Türkçeye çevirme
  String _canonicalizeTag(String t) {
    const map = {
      'mat': 'matematik',
      'matematik': 'matematik',
      'algoritm': 'algoritma',
      'yasam': 'yaşam',
      'saglik': 'sağlık',
      'egitim': 'eğitim',
    };

    return map[t] ?? t;
  }

  // Hatırlatma metni
  String? _reminderText(int? minutes) {
    if (minutes == null || minutes <= 0) return null;
    switch (minutes) {
      case 5:
        return '5 dk önce';
      case 10:
        return '10 dk önce';
      case 30:
        return '30 dk önce';
      case 60:
        return '1 saat önce';
      case 1440:
        return '1 gün önce';
      default:
        return '$minutes dk önce';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    //  ALT SATIR: Deadline + Hatırlatma + Not
    final meta = <InlineSpan>[];

    // Deadline (sadece task için)
    if (_isTask && item.dueAt != null) {
      meta.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.schedule, size: 16, color: cs.outline),
      ));
      meta.add(TextSpan(
        text: '  Son tarih: ${_fmt(item.dueAt!, allDay: item.allDay)}',
        style: TextStyle(color: cs.outline),
      ));
    }

    // Hatırlatma
    final reminder = _reminderText(item.remindMinutes);
    if (reminder != null) {
      if (meta.isNotEmpty) {
        meta.add(const TextSpan(text: '\n'));
      }
      meta.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.notifications_active, size: 16, color: cs.secondary),
      ));
      meta.add(TextSpan(
        text: '  $reminder',
        style: TextStyle(color: cs.secondary),
      ));
    }

    // Notlar
    if ((item.notes ?? '').trim().isNotEmpty) {
      if (meta.isNotEmpty) {
        meta.add(const TextSpan(text: '\n'));
      }
      meta.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.notes, size: 16, color: cs.outline),
      ));
      meta.add(TextSpan(
        text: '  ${item.notes!.trim()}',
        style: TextStyle(color: cs.outline),
      ));
    }

    //  Hem görev tamamlandığında hem de alışkanlık bugün yapıldığında üstü çiz
    final isDoneForStyle =
        (_isTask && _taskDone) || (_isHabit && _habitDoneToday);

    //  ETİKET LİSTESİ (TEMİZLENMİŞ)
    final rawTags = item.tags
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    final seen = <String>{};
    final cleanedTags = <String>[];

    for (var t in rawTags) {
      // önce düzgün Türkçe ye çevir
      t = _canonicalizeTag(t);

      // çok kısa kısaltmaları ele (örneğin bt vs)
      if (t.length < 3) continue;

      final key = _baseTagKey(t);
      if (seen.add(key)) {
        cleanedTags.add(t);
      }
    }

    // ekranda en fazla 3 etiket
    final visibleTags = cleanedTags.take(3).toList();

    // Öncelik için yıldızlar (kırmızı) – BAŞLIĞIN SAĞINDA
    // 1 = yüksek - 3 yıldız
    // 2 = orta   - 2 yıldız
    // 3 = düşük  - 1 yıldız
    int starCount = 0;
    final p = item.priority;
    if (p != null && p > 0) {
      starCount = (4 - p).clamp(1, 3);
    }
    final starIcons = <Widget>[];
    for (int i = 0; i < starCount; i++) {
      starIcons.add(const Icon(
        Icons.star,
        size: 16,
        color: Colors.red,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: IconButton(
              icon: Icon(_leadingIcon(), color: _leadingColor(context)),
              onPressed: onToggle == null ? null : () => onToggle!(item),
              tooltip: _isTask
                  ? (_taskDone ? 'Tamamlandı' : 'Tamamlandı olarak işaretle')
                  : (_isHabit
                      ? (_habitDoneToday
                          ? 'Bugün yapıldı'
                          : 'Bugün yapıldı olarak işaretle')
                      : 'Etkinlik'),
            ),
            title: Row(
              children: [
                // Başlık solda – max 2 satır, satır sonlarını boşluk yap
                Expanded(
                  child: Tooltip(
                    message: item.title, // üstüne gelince tam başlık
                    child: Text(
                      item.title.replaceAll('\n', ' ').replaceAll('\r', ' '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: TextStyle(
                        decoration:
                            isDoneForStyle ? TextDecoration.lineThrough : null,
                        color: isDoneForStyle ? cs.outline : null,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Row(children: starIcons),
              ],
            ),
            subtitle: meta.isEmpty
                ? null
                : RichText(
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall,
                      children: meta,
                    ),
                  ),
            trailing: Wrap(
              spacing: 6,
              children: [
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Düzenle',
                    onPressed: () => onEdit!(item),
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Sil',
                    onPressed: () => onDelete!(item),
                  ),
              ],
            ),
            onLongPress: onToggle == null ? null : () => onToggle!(item),
            onTap: onEdit == null ? null : () => onEdit!(item),
          ),

          //  ETİKETLERİN GÖSTERİLDİĞİ KISIM
          if (visibleTags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: -6,
                children: visibleTags.map((t) {
                  return Chip(
                    label: Text(
                      t,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: cs.primary.withOpacity(0.12),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity:
                        const VisualDensity(horizontal: -4, vertical: -4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
