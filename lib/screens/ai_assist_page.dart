// lib/screens/ai_assist_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';

// LLM bağlantısı için baseUrl seçimi (emülatör/cihaz)
// Gerekirse sabit bir URL yaz: return 'http://<PC_IP_ADRESIN>:11434';
String _llmBaseUrl() {
  if (kIsWeb) return 'http://127.0.0.1:11434';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:11434'; // Android emülatör
    case TargetPlatform.iOS:
      return 'http://127.0.0.1:11434'; // iOS simülatör
    default:
      return 'http://127.0.0.1:11434'; // Desktop
  }
}

// Basit Ollama istemcisi
class LlmClient {
  final String baseUrl;
  final String model;
  LlmClient({required this.baseUrl, required this.model});

  Future<String> generate({
    required String prompt,
    Map<String, dynamic>? options,
    String? format, // json dersen LLM JSON döndürmeye zorlanır
  }) async {
    final uri = Uri.parse('$baseUrl/api/generate');
    final body = {
      'model': model,
      'prompt': prompt,
      'stream': false,
      if (options != null) 'options': options,
      if (format != null) 'format': format,
    };
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('LLM error ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['response'] as String).trim();
  }
}

// TTS servisi
class TtsService {
  final _tts = FlutterTts();
  Future<void> init({String lang = 'tr-TR'}) async {
    await _tts.setLanguage(lang);
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }
}

// Bugünün görevlerini çek
// SENDEKİ ŞEMA: users/{uid}/items  ve alan adı: dueAt (Timestamp)
Future<List<Map<String, dynamic>>> loadTodayTasks(
  FirebaseFirestore db,
  String uid, {
  bool fresh = false,
}) async {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));

  final query = db
      .collection('users')
      .doc(uid)
      .collection('items')
      .where('dueAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('dueAt', isLessThan: Timestamp.fromDate(end))
      .orderBy('dueAt');

  final qs = await query.get(
    fresh ? const GetOptions(source: Source.server) : null,
  );

  return qs.docs.map((d) {
    final m = d.data();
    m['id'] = d.id;
    return m;
  }).toList();
}

// Etiketleme servisi
class TaggingService {
  final LlmClient llm;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  TaggingService({required this.llm, required this.db, required this.auth});

  // Klasik: LLM doğrudan etiket listesi döndürür (JSON).
  Future<void> tagTasks({
    required List<Map<String, dynamic>> tasks,
    required List<String> allowedTags,
  }) async {
    //  JSON-encodable liste oluştur (Timestamp -> ISO string)
    String _iso(dynamic v) {
      if (v == null) return '';
      if (v is Timestamp) return v.toDate().toIso8601String();
      if (v is DateTime) return v.toIso8601String();
      return v.toString();
    }

    final safeTasks = tasks.map((t) {
      final tags =
          ((t['tags'] ?? []) as List).map((e) => e.toString()).toList();
      return {
        'id': t['id']?.toString() ?? '',
        'title': (t['title'] ?? '').toString(),
        'description': (t['description'] ?? '').toString(),
        'dueDate': _iso(t['dueAt']),
        'tags': tags,
      };
    }).toList();

    final schema = {
      "type": "object",
      "properties": {
        "items": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "id": {"type": "string"},
              "tags": {
                "type": "array",
                "items": {"type": "string"}
              }
            },
            "required": ["id", "tags"]
          }
        }
      },
      "required": ["items"]
    };

    final prompt = '''
Sen bir görev etiketleyicisisin.
Sadece şu etiketlerden kullan: ${allowedTags.join(", ")}.
Uymuyorsa [] döndür. Maksimum 3 etiket ver. Sadece JSON dön.

GÖREVLER:
${jsonEncode(safeTasks)}

JSON ŞEMASI:
${jsonEncode(schema)}
''';

    final response = await llm.generate(
      prompt: prompt,
      format: "json",
      options: {"temperature": 0.2},
    );

    // Modele güvenmeyelim - JSON u sağlam parse edelim
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(response) as Map<String, dynamic>;
    } catch (_) {
      final first = response.indexOf('{');
      final last = response.lastIndexOf('}');
      if (first != -1 && last != -1 && last > first) {
        parsed = jsonDecode(response.substring(first, last + 1))
            as Map<String, dynamic>;
      } else {
        parsed = {"items": []};
      }
    }

    final items = (parsed?['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (items.isEmpty) return;

    final uid = auth.currentUser!.uid;
    final batch = db.batch();
    for (final it in items) {
      final id = (it['id'] ?? '').toString();
      final tags =
          ((it['tags'] ?? []) as List).map((e) => e.toString()).toList();
      if (id.isEmpty) continue;
      final ref =
          db.collection('users').doc(uid).collection('items').doc(id); // 🔴
      batch.update(ref, {
        'tags': tags,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await db.waitForPendingWrites();
  }

  // Tohumlu: Kullanıcının verdiği 2 etiket üzerinden her göreve
  // allowed list içinden EN AZ 1 yeni etiket öner, mevcutlarla birleştir.
  Future<void> tagTasksWithSeeds({
    required List<Map<String, dynamic>> tasks,
    required List<String> allowedTags,
    required List<String> userSeeds, // örn: ["work","focus"]
  }) async {
    // normalize + allowed filtre
    String norm(String s) => s.trim().toLowerCase();
    final allowed = allowedTags.map(norm).toSet();
    final seeds =
        userSeeds.map(norm).where((t) => allowed.contains(t)).toList();

    if (seeds.length < 2) {
      throw Exception(
          "En az 2 geçerli tohum etiket gerekli (allowed list içinde olmalı).");
    }

    String _iso(dynamic v) {
      if (v == null) return '';
      if (v is Timestamp) return v.toDate().toIso8601String();
      if (v is DateTime) return v.toIso8601String();
      return v.toString();
    }

    final safeTasks = tasks.map((t) {
      final tags =
          ((t['tags'] ?? []) as List).map((e) => norm(e.toString())).toList();
      return {
        'id': t['id']?.toString() ?? '',
        'title': (t['title'] ?? '').toString(),
        'notes': (t['description'] ?? t['notes'] ?? '').toString(),
        'due': _iso(t['dueAt']),
        'tags': tags,
      };
    }).toList();

    // LLM promptu: tohumlar + allowed set ver, her görev için min 1 yeni etiket iste.
    final schema = {
      "type": "object",
      "properties": {
        "items": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "id": {"type": "string"},
              "new_tags": {
                "type": "array",
                "items": {"type": "string"},
                "minItems": 1,
                "maxItems": 2
              }
            },
            "required": ["id", "new_tags"]
          }
        }
      },
      "required": ["items"]
    };

    final prompt = '''
Sen AI Planner'ın görev etiketleyicisisin.
Kullanıcının verdiği tohum etiketler: ${seeds.join(", ")}.
Sadece şu etiket setinden seçebilirsin: ${allowed.join(", ")}.
Her görev için tohum etiketlere UYAN, fakat onlardan FARKLI en az 1 yeni etiket öner.
Aynı etiketi tekrarlama, toplamda göreve en fazla 2 yeni etiket ver.
Sadece JSON döndür.

GÖREVLER:
${jsonEncode(safeTasks)}

JSON ŞEMASI (örnek):
${jsonEncode(schema)}
ÖRNEK ÇIKTI:
{"items":[{"id":"abc","new_tags":["focus"]},{"id":"def","new_tags":["habit","health"]}]}
''';

    final response = await llm.generate(
      prompt: prompt,
      format: "json",
      options: {"temperature": 0.2},
    );

    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(response) as Map<String, dynamic>;
    } catch (_) {
      final first = response.indexOf('{');
      final last = response.lastIndexOf('}');
      if (first != -1 && last != -1 && last > first) {
        parsed = jsonDecode(response.substring(first, last + 1))
            as Map<String, dynamic>;
      } else {
        parsed = {"items": []};
      }
    }

    final items = (parsed?['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (items.isEmpty) return;

    // Birleştir ve Firestore'a yaz
    final uid = auth.currentUser!.uid;
    final batch = db.batch();
    for (final it in items) {
      final id = (it['id'] ?? '').toString();
      if (id.isEmpty) continue;

      final suggested = ((it['new_tags'] ?? []) as List)
          .map((e) => norm(e.toString()))
          .where((t) => allowed.contains(t))
          .toSet();

      final ref =
          db.collection('users').doc(uid).collection('items').doc(id); // 🔴
      final snap = await ref.get();
      final current = (snap.data()?['tags'] as List?)
              ?.map((e) => norm(e.toString()))
              .toSet() ??
          <String>{};

      final merged = <String>{}
        ..addAll(current)
        ..addAll(seeds)
        ..addAll(suggested);

      batch.update(ref, {
        'tags': merged.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await db.waitForPendingWrites();
  }
}

// UI: İki butonlu sayfa
class AiAssistPage extends StatefulWidget {
  const AiAssistPage({super.key});

  @override
  State<AiAssistPage> createState() => _AiAssistPageState();
}

class _AiAssistPageState extends State<AiAssistPage> {
  late final LlmClient _llm;
  late final TaggingService _tagging;
  late final TtsService _tts;
  bool _busy = false;

  // Örnek izinli etiketler (ayarlar ekranından da gelebilir)
  final List<String> _allowedTags = const [
    'work',
    'study',
    'health',
    'family',
    'finance',
    'errand',
    'focus',
    'habit'
  ];

  @override
  void initState() {
    super.initState();
    _llm =
        LlmClient(baseUrl: _llmBaseUrl(), model: 'phi3:mini'); // sonra mixtral
    _tagging = TaggingService(
      llm: _llm,
      db: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
    );
    _tts = TtsService()..init(lang: 'tr-TR');
  }

  Future<void> _aiTag() async {
    try {
      setState(() => _busy = true);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Önce giriş yapmalısın.');
      final tasks =
          await loadTodayTasks(FirebaseFirestore.instance, uid, fresh: true);
      if (tasks.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bugün için görev bulunamadı.')),
        );
        return;
      }
      await _tagging.tagTasks(tasks: tasks, allowedTags: _allowedTags);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etiketler güncellendi ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Kullanıcı 2 tohum etiketi girer; LLM her göreve en az 1 yeni etiket önerir
  Future<void> _aiTagWithSeeds() async {
    try {
      setState(() => _busy = true);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Önce giriş yapmalısın.');

      final seeds = await _askUserSeeds();
      if (seeds == null) return; // vazgeçti
      final allowedSet = _allowedTags.map((e) => e.toLowerCase()).toSet();
      final validSeeds =
          seeds.where((s) => allowedSet.contains(s.toLowerCase())).toList();
      if (validSeeds.length < 2) {
        throw Exception(
            'Etiketler izinli listede olmalı: ${_allowedTags.join(", ")}');
      }

      final tasks =
          await loadTodayTasks(FirebaseFirestore.instance, uid, fresh: true);
      if (tasks.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bugün için görev bulunamadı.')),
        );
        return;
      }

      await _tagging.tagTasksWithSeeds(
        tasks: tasks,
        allowedTags: _allowedTags,
        userSeeds: validSeeds.take(2).toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Tohumlara göre etiketler eklendi ✅ (${validSeeds.join(", ")})')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<String>?> _askUserSeeds() async {
    final t1 = TextEditingController();
    final t2 = TextEditingController();
    final res = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İki etiket gir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: t1,
                decoration:
                    const InputDecoration(labelText: 'Etiket 1 (ör. work)')),
            TextField(
                controller: t2,
                decoration:
                    const InputDecoration(labelText: 'Etiket 2 (ör. focus)')),
            const SizedBox(height: 8),
            Text(
              'İzinli etiketler: ${_allowedTags.join(", ")}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
              onPressed: () {
                final a = t1.text.trim().toLowerCase();
                final b = t2.text.trim().toLowerCase();
                if (a.isEmpty || b.isEmpty) return;
                Navigator.pop(ctx, [a, b]);
              },
              child: const Text('Tamam')),
        ],
      ),
    );
    return res;
  }

  Future<void> _readPlan() async {
    try {
      setState(() => _busy = true);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Önce giriş yapmalısın.');
      //  Etiketlemelerden sonra günceli okuması için fresh:true
      final tasks =
          await loadTodayTasks(FirebaseFirestore.instance, uid, fresh: true);
      if (tasks.isEmpty) {
        await _tts.speak('Bugün için planlanmış bir göreviniz yok.');
        return;
      }
      tasks.sort((a, b) {
        final ta = (a['dueAt'] as Timestamp).toDate(); // 🔴 dueAt
        final tb = (b['dueAt'] as Timestamp).toDate();
        return ta.compareTo(tb);
      });

      final b = StringBuffer()..writeln('Günün planı:');
      for (final t in tasks) {
        final dt = (t['dueAt'] as Timestamp).toDate(); // 🔴 dueAt
        final saat = DateFormat('HH:mm').format(dt);
        final title = (t['title'] ?? '').toString();
        final tags =
            ((t['tags'] ?? []) as List).map((e) => e.toString()).toList();
        if (tags.isNotEmpty) {
          b.writeln('$saat — $title. Etiketler: ${tags.join(", ")}.');
        } else {
          b.writeln('$saat — $title.');
        }
      }
      await _tts.speak(b.toString());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Planner • AI Asistan')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'Bugünün görevlerini AI ile etiketle ve hoparlörden okut.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Klasik etiketleme
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI ile Etiketle'),
                  onPressed: _busy ? null : _aiTag,
                ),
              ),
              const SizedBox(height: 8),

              //  Tohumlu etiketleme
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.local_florist_outlined),
                  label: const Text('AI ile Etiketle (2 tohumla)'),
                  onPressed: _busy ? null : _aiTagWithSeeds,
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Günlük Planı Seslendir'),
                  onPressed: _busy ? null : _readPlan,
                ),
              ),
              const SizedBox(height: 20),
              if (_busy) const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'LLM: phi3:mini  •  URL: ${_llmBaseUrl()}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
