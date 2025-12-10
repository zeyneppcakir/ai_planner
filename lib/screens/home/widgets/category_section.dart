import 'package:flutter/material.dart';
import '../../../core/models/item.dart';
import '../../../core/utils/progress.dart';
import 'item_tile.dart';

typedef ItemCallback = void Function(Item);

class CategorySection extends StatelessWidget {
  final String title;
  final String emoji;
  final Color color;
  final List<Item> items;

  final ItemCallback? onToggle;
  final ItemCallback? onEdit;
  final ItemCallback? onDelete;

  // Emoji avatarına dokununca çalışır (ör. _pickEmoji(Category.egitim))
  final VoidCallback? onEmojiTap;

  // Kart arka plan tinti
  final bool tint;

  //  Yeni: kategori kapalı mı?
  final bool collapsed;

  //  Yeni: aç/kapa butonuna basınca çalışacak callback
  final VoidCallback? onToggleCollapse;

  const CategorySection({
    super.key,
    required this.title,
    required this.emoji,
    required this.color,
    required this.items,
    this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onEmojiTap,
    this.tint = true,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  // İlerleme yüzdesine göre renk skalası
  // 0.00 -> koyu kırmızı
  // 0.25 -> açık kırmızı
  // 0.50 -> sarı
  // 0.75 -> açık yeşil
  // 1.00 -> tam yeşil
  Color _progressColor(double value) {
    // 0.0–1.0 arasında tut
    value = value.clamp(0.0, 1.0);

    const darkRed = Color(0xFFB00020); // koyu kırmızı
    const lightRed = Color(0xFFFF8A80); // açık kırmızı
    const yellow = Color(0xFFFFF176); // sarı
    const lightGreen = Color(0xFFB9F6CA); // açık yeşil
    const green = Color(0xFF00C853); // tam yeşil

    if (value < 0.25) {
      // 0.00 - 0.25 : koyu kırmızı -> açık kırmızı
      final t = value / 0.25;
      return Color.lerp(darkRed, lightRed, t)!;
    } else if (value < 0.5) {
      // 0.25 - 0.50 : açık kırmızı -> sarı
      final t = (value - 0.25) / 0.25;
      return Color.lerp(lightRed, yellow, t)!;
    } else if (value < 0.75) {
      // 0.50 - 0.75 : sarı -> açık yeşil
      final t = (value - 0.5) / 0.25;
      return Color.lerp(yellow, lightGreen, t)!;
    } else {
      // 0.75 - 1.00 : açık yeşil -> tam yeşil
      final t = (value - 0.75) / 0.25;
      return Color.lerp(lightGreen, green, t)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final done = items.where((i) => i.isCompleted()).length;
    final p = total == 0 ? 0.0 : done / total;
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: tint ? color.withOpacity(.12) : null,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1.5,
      child: Column(
        children: [
          // Üst renk şeridi
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: color.withOpacity(.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    // Emoji (tıklanabilir)
                    if (onEmojiTap != null)
                      Tooltip(
                        message: 'Emojiyi değiştir',
                        child: InkWell(
                          onTap: onEmojiTap,
                          borderRadius: BorderRadius.circular(16),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                cs.primaryContainer.withOpacity(.35),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: cs.primaryContainer.withOpacity(.35),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),

                    const SizedBox(width: 8),

                    // Başlık
                    Expanded(
                      child: Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: color.withOpacity(.95),
                                  fontWeight: FontWeight.w700,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Tüm görevler bitmişse küçük tik
                    if (p >= 1.0)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.check_circle,
                          color: cs.primary,
                          size: 20,
                        ),
                      ),

                    // Progress + yüzde + collapse ikonu
                    SizedBox(
                      width: 180,
                      child: Row(
                        children: [
                          Expanded(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: p),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                              builder: (context, value, _) {
                                final barColor = _progressColor(value);

                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    minHeight: 6,
                                    backgroundColor:
                                        progressTrackColor(context),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      barColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(p * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (onToggleCollapse != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              iconSize: 20,
                              tooltip: collapsed
                                  ? 'Kategoriyi aç'
                                  : 'Kategoriyi gizle',
                              icon: Icon(
                                collapsed
                                    ? Icons.keyboard_arrow_down
                                    : Icons.keyboard_arrow_up,
                              ),
                              onPressed: onToggleCollapse,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                //  İçerik (görevler) – collapse ise hiç göstermiyoruz
                if (!collapsed)
                  (items.isEmpty)
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Bu kategoride öğe yok.'),
                          ),
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          separatorBuilder: (_, __) => const Divider(height: 8),
                          itemBuilder: (_, i) {
                            final it = items[i];
                            return ItemTile(
                              item: it,
                              onToggle: onToggle,
                              onEdit: onEdit,
                              onDelete: onDelete,
                            );
                          },
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
