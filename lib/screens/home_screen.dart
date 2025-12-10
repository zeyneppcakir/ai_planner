// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, User, EmailAuthProvider, FirebaseAuthException;

import 'package:ai_planner/core/models/item.dart';
import 'package:ai_planner/data/firestore_repo.dart';
import 'home/widgets/category_section.dart';
import 'home/widgets/add_item_sheet.dart';
import 'home/widgets/item_tile.dart'; //  YAKLAŞAN HATIRLATMALAR için

import 'package:shared_preferences/shared_preferences.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;

import 'package:ai_planner/services/tts_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

//  Tema yönetimi (Riverpod)
import 'package:ai_planner/theme_mode_notifier.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

//  ConsumerState: ref ile themeModeProvider ı okuyacağız
class _HomeScreenState extends ConsumerState<HomeScreen> {
  //  TAG BAR
  String? activeTag;
  bool _tagsExpanded = false;
  static const int _initialTagCount = 12;

  //  CATEGORY COLLAPSE STATE
  final Map<Category, bool> _collapsed = {
    Category.egitim: false,
    Category.kariyer: false,
    Category.yasam: false,
  };

  void _toggleCollapse(Category c) {
    setState(() {
      _collapsed[c] = !_collapsed[c]!;
    });
  }

  //  EMOJI STATE
  final Map<Category, String> _catEmojis = {};
  late final FirestoreRepo _repo;
  final ScrollController _listCtrl = ScrollController();

  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _repo = FirestoreRepo(uid);
    _loadCategoryEmojis();
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  //  Emoji persist
  Future<void> _loadCategoryEmojis() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _catEmojis[Category.egitim] = prefs.getString('emoji_egitim') ??
          defaultCategoryStyles[Category.egitim]!.emoji;
      _catEmojis[Category.kariyer] = prefs.getString('emoji_kariyer') ??
          defaultCategoryStyles[Category.kariyer]!.emoji;
      _catEmojis[Category.yasam] = prefs.getString('emoji_yasam') ??
          defaultCategoryStyles[Category.yasam]!.emoji;
    });
  }

  Future<void> _saveCategoryEmoji(Category c, String emoji) async {
    final prefs = await SharedPreferences.getInstance();
    switch (c) {
      case Category.egitim:
        await prefs.setString('emoji_egitim', emoji);
        break;
      case Category.kariyer:
        await prefs.setString('emoji_kariyer', emoji);
        break;
      case Category.yasam:
        await prefs.setString('emoji_yasam', emoji);
        break;
    }
  }

  String _emojiFor(Category c) =>
      _catEmojis[c] ?? defaultCategoryStyles[c]!.emoji;

  Future<void> _pickEmoji(Category c) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.45,
          child: ep.EmojiPicker(
            onEmojiSelected: (category, emoji) =>
                Navigator.pop(ctx, emoji.emoji),
          ),
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _catEmojis[c] = selected);
    await _saveCategoryEmoji(c, selected);
  }

  //  Yardımcılar
  String _displayNameOf(User u) {
    final name = (u.displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    final email = u.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'Kullanıcı';
  }

  bool _hasPassword(User u) =>
      u.providerData.any((p) => p.providerId == 'password');

  Future<void> _addPassword(BuildContext context, User user) async {
    final pass1 = TextEditingController();
    final pass2 = TextEditingController();

    final String? newPass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabına parola ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pass1,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Yeni parola (en az 6 karakter)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pass2,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Parolayı tekrar'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              if (pass1.text.length < 6) return;
              if (pass1.text != pass2.text) return;
              Navigator.pop(ctx, pass1.text);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (newPass == null) return;

    try {
      await user.linkWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: newPass),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Parola eklendi. Artık e-posta/şifre ile de giriş yapabilirsin.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'provider-already-linked':
          msg = 'Hesabında zaten parola var.';
          break;
        case 'credential-already-in-use':
          msg = 'Bu e-posta başka bir hesapta kullanılıyor.';
          break;
        case 'requires-recent-login':
          msg =
              'Güvenlik için yeniden giriş gerekiyor. Lütfen tekrar Google ile giriş yap.';
          break;
        default:
          msg = e.message ?? 'Parola eklenemedi.';
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bilinmeyen hata oluştu.')),
        );
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: const Text('Oturumu kapatmak istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkış yap'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Oturum kapatıldı')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Çıkış hatası: $e')));
        }
      }
    }
  }

  //  Günlük görevi okuma
  Future<void> _readTodaysTasks() async {
    setState(() => _speaking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));

      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('items');

      final snap = await col.get();

      final tasks = <Map<String, dynamic>>[];
      for (final d in snap.docs) {
        final data = d.data();
        final title = (data['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        if (data['done'] == true) continue;

        DateTime? due;
        final raw = data['dueAt'] ?? data['deadline'] ?? data['due'];
        if (raw is Timestamp) due = raw.toDate();
        if (raw is String) due = DateTime.tryParse(raw);

        if (due == null) continue;
        if (due.isAfter(start) && due.isBefore(end)) {
          tasks.add({'title': title, 'due': due});
        }
      }

      if (tasks.isEmpty) {
        await TtsService.speak("Bugün görevin yok.");
        return;
      }

      tasks.sort(
          (a, b) => (a['due'] as DateTime).compareTo(b['due'] as DateTime));

      final f = DateFormat("HH:mm");
      final sb = StringBuffer("Bugün ${tasks.length} görevin var. ");

      for (int i = 0; i < tasks.length; i++) {
        final t = tasks[i];
        sb.writeln(
            "${i + 1}) ${t['title']} — ${f.format(t['due'] as DateTime)}");
      }

      await TtsService.speak(sb.toString());
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  //  CRUD
  Future<void> _openAddSheet() async {
    final item = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddItemSheet(),
    );
    if (item == null) return;

    await _repo.addItem(item);
    if (!mounted) return;

    setState(() => activeTag = null);
    if (_listCtrl.hasClients) {
      _listCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Kaydedildi")));
  }

  Future<void> _openEditSheet(Item item) async {
    final updated = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddItemSheet(initial: item),
    );
    if (updated == null) return;
    await _repo.updateItem(updated);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Güncellendi")));
    }
  }

  Future<void> _toggleItem(Item item) async {
    await _repo.toggleItem(item);
  }

  Future<void> _confirmDelete(Item item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Silinsin mi?"),
        content: Text('"${item.title}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (ok == true) await _repo.deleteItem(item.id);
  }

  //  TAG işlemleri
  List<String> _sortedTagsByPopularity(List<Item> items) {
    final counts = <String, int>{};
    for (final i in items) {
      for (final t in i.tags) {
        final k = t.trim();
        if (k.isEmpty) continue;
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }

    final list = counts.keys.toList();
    list.sort((a, b) {
      final c = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      return c != 0 ? c : a.compareTo(b);
    });
    return list;
  }

  List<Widget> _buildChips(List<String> source) {
    final chips = <Widget>[];

    chips.add(
      ChoiceChip(
        label: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off, size: 16),
            SizedBox(width: 4),
            Text("Sıfırla"),
          ],
        ),
        selected: false,
        onSelected: (_) => setState(() => activeTag = null),
        backgroundColor: Colors.white,
        selectedColor: Colors.white,
        side: const BorderSide(color: Colors.grey),
      ),
    );

    for (final t in source) {
      chips.add(
        ChoiceChip(
          label: Text(t),
          selected: activeTag == t,
          onSelected: (_) =>
              setState(() => activeTag = (activeTag == t) ? null : t),
          backgroundColor: Colors.grey.shade200,
          selectedColor: Colors.grey.shade300,
        ),
      );
    }

    return chips;
  }

  //  Yaklaşan hatırlatmalar (son tarih önümüzdeki X gün içinde olan görevler)
  List<Item> _getUpcoming(List<Item> items, {int withinDays = 3}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcoming = items.where((item) {
      if (item.type != ItemType.task) return false;
      if (item.dueAt == null) return false;
      final target = DateTime(
        item.dueAt!.year,
        item.dueAt!.month,
        item.dueAt!.day,
      );
      final diff = target.difference(today).inDays;
      if (diff < 0 || diff > withinDays) return false;
      // tamamlanmış görevleri hatırlatma olarak gösterme
      if (item.status == TaskStatus.done) return false;
      return true;
    }).toList();

    upcoming.sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    return upcoming;
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Mevcut tema modunu oku (ikon için)
    final themeMode = ref.watch(themeModeProvider);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (ctx, snap) {
        final user = snap.data ?? FirebaseAuth.instance.currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final name = _displayNameOf(user);
        final canAddPassword = !_hasPassword(user) &&
            (user.email != null && user.email!.isNotEmpty);

        return Scaffold(
          appBar: AppBar(
            title: Text("Hoş geldin, $name"),
            actions: [
              IconButton(
                tooltip: 'Bugünkü görevleri seslendir',
                onPressed: _speaking ? null : _readTodaysTasks,
                icon: _speaking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.volume_up),
              ),
              if (canAddPassword)
                IconButton(
                  tooltip: 'Parola ekle',
                  icon: const Icon(Icons.key_outlined),
                  onPressed: () => _addPassword(context, user),
                ),

              //  Tema değiştir (logout'un solunda)
              IconButton(
                tooltip: 'Tema değiştir',
                onPressed: () {
                  ref.read(themeModeProvider.notifier).toggleDarkLight();
                },
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
              ),

              IconButton(
                tooltip: 'Çıkış yap',
                icon: const Icon(Icons.logout),
                onPressed: () => _confirmSignOut(context),
              ),
            ],
          ),

          //  İki FAB (üstte hoparlör, altta Ekle)
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'tts_fab',
                onPressed: _speaking ? null : _readTodaysTasks,
                child: _speaking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.volume_up),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: 'add_fab',
                onPressed: _openAddSheet,
                label: const Text("Ekle"),
                icon: const Icon(Icons.add),
              ),
            ],
          ),

          //  BODY
          body: StreamBuilder<List<Item>>(
            stream: _repo.watchAll(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final all = snap.data!;
              final items = [...all];

              items.sort((a, b) {
                int n1 = int.tryParse(a.id) ?? 0;
                int n2 = int.tryParse(b.id) ?? 0;
                return n2.compareTo(n1);
              });

              List<Item> filtered = items;
              if (activeTag != null) {
                filtered =
                    filtered.where((i) => i.tags.contains(activeTag)).toList();
              }

              final edu =
                  filtered.where((i) => i.category == Category.egitim).toList();
              final work = filtered
                  .where((i) => i.category == Category.kariyer)
                  .toList();
              final life =
                  filtered.where((i) => i.category == Category.yasam).toList();

              final tags = _sortedTagsByPopularity(items);
              final collapsed = tags.take(_initialTagCount).toList();
              final expanded = tags;

              //  Yaklaşan hatırlatmalar (filtrelenmiş liste üzerinden)
              final upcoming = _getUpcoming(filtered);

              return ListView(
                key: const PageStorageKey("home_list"),
                controller: _listCtrl,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                children: [
                  //  YAKLAŞAN HATIRLATMALAR BLOĞU
                  if (upcoming.isNotEmpty) ...[
                    Text(
                      'Yaklaşan Hatırlatmalar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...upcoming.map(
                      (it) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ItemTile(
                          item: it,
                          onToggle: _toggleItem,
                          onEdit: _openEditSheet,
                          onDelete: _confirmDelete,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  //  TAG BAR
                  !_tagsExpanded
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ..._buildChips(collapsed).map(
                                (w) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: w,
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _tagsExpanded = true),
                                child: const Text("Daha fazla"),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              children: _buildChips(expanded),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _tagsExpanded = false),
                                child: const Text("Daha az"),
                              ),
                            ),
                          ],
                        ),

                  const SizedBox(height: 16),

                  //  CATEGORY SECTIONS
                  CategorySection(
                    title: "Eğitim",
                    emoji: _emojiFor(Category.egitim),
                    color: defaultCategoryStyles[Category.egitim]!.color,
                    items: edu,
                    onToggle: _toggleItem,
                    onEdit: _openEditSheet,
                    onDelete: _confirmDelete,
                    onEmojiTap: () => _pickEmoji(Category.egitim),
                    collapsed: _collapsed[Category.egitim]!,
                    onToggleCollapse: () => _toggleCollapse(Category.egitim),
                  ),

                  CategorySection(
                    title: "Kariyer",
                    emoji: _emojiFor(Category.kariyer),
                    color: defaultCategoryStyles[Category.kariyer]!.color,
                    items: work,
                    onToggle: _toggleItem,
                    onEdit: _openEditSheet,
                    onDelete: _confirmDelete,
                    onEmojiTap: () => _pickEmoji(Category.kariyer),
                    collapsed: _collapsed[Category.kariyer]!,
                    onToggleCollapse: () => _toggleCollapse(Category.kariyer),
                  ),

                  CategorySection(
                    title: "Yaşam",
                    emoji: _emojiFor(Category.yasam),
                    color: defaultCategoryStyles[Category.yasam]!.color,
                    items: life,
                    onToggle: _toggleItem,
                    onEdit: _openEditSheet,
                    onDelete: _confirmDelete,
                    onEmojiTap: () => _pickEmoji(Category.yasam),
                    collapsed: _collapsed[Category.yasam]!,
                    onToggleCollapse: () => _toggleCollapse(Category.yasam),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
