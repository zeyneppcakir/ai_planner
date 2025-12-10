import 'package:flutter/material.dart';
import '../../../core/models/item.dart';
import 'package:ai_planner/services/ollama_service.dart'; // 🔥 LLM servisi

class AddItemSheet extends StatefulWidget {
  const AddItemSheet({super.key, this.initial});
  final Item? initial;

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  // ⏱ Tahmini süre (dakika) için controller
  final _durationCtrl = TextEditingController();
  int? _estimatedMinutes;

  ItemType _type = ItemType.task;
  Category _category = Category.egitim;

  bool _allDay = false;
  DateTime? _startAt;
  DateTime? _endAt;
  DateTime? _dueAt;

  Recurrence _recurrence = const Recurrence();
  int? _remindMinutes;
  String? _notes;
  int? _priority;

  // Tagler
  final Set<String> _tags = {};
  List<String> _suggested = [];
  bool _autoTag = true; // Varsayılan: otomatik etiket açık
  bool _isSaving = false; // Kaydet butonu loading için

  @override
  void initState() {
    super.initState();
    final it = widget.initial;
    if (it != null) {
      _titleCtrl.text = it.title;
      _type = it.type;
      _category = it.category;
      _allDay = it.allDay;
      _startAt = it.startAt;
      _endAt = it.endAt;
      _dueAt = it.dueAt;
      _recurrence = it.recurrence;
      _remindMinutes = it.remindMinutes;
      _notes = it.notes;
      _priority = it.priority;
      _tags.addAll(it.tags);

      // ⏱ Düzenleme modunda mevcut tahmini süreyi doldur
      if (it.estimatedMinutes != null) {
        _estimatedMinutes = it.estimatedMinutes;
        final hours = it.estimatedMinutes! / 60.0;
        // 1 veya 1.5 gibi daha okunabilir string
        _durationCtrl.text =
            hours % 1 == 0 ? hours.toInt().toString() : hours.toString();
      }
    }
    _refreshSuggestions();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  // --- Basit otomatik etiketleyici (sadece ÖNERİ için) ---
  Set<String> _autoTagsFrom(String text) {
    final t = text.toLowerCase();
    final out = <String>{};
    void addIf(bool cond, String tag) {
      if (cond) out.add(tag);
    }

    addIf(t.contains('ödev') || t.contains('odev'), 'ödev');
    addIf(t.contains('sınav') || t.contains('sinav') || t.contains('quiz'),
        'sınav');
    addIf(t.contains('proje') || t.contains('project'), 'proje');
    addIf(t.contains('toplant') || t.contains('meet'), 'toplantı');
    addIf(t.contains('mail') || t.contains('e-posta') || t.contains('eposta'),
        'mail');
    addIf(t.contains('rapor') || t.contains('doküman') || t.contains('dokuman'),
        'rapor');
    addIf(
        t.contains('alışveriş') ||
            t.contains('alisveris') ||
            t.contains('market'),
        'alışveriş');
    addIf(t.contains('sağlık') || t.contains('saglik') || t.contains('doktor'),
        'sağlık');
    addIf(t.contains('spor') || t.contains('fitness') || t.contains('gym'),
        'spor');
    addIf(t.contains('staj') || t.contains('intern'), 'staj');
    addIf(t.contains('tez') || t.contains('thesis'), 'tez');

    return out;
  }

  void _refreshSuggestions() {
    final hits = _autoTagsFrom(_titleCtrl.text);
    setState(() {
      _suggested = hits.take(5).toList(); // sadece öneri listesi
    });
  }

  Future<DateTime?> _pickDateTime({DateTime? initial}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: initial ?? now,
    );
    if (date == null) return null;

    if (_allDay) {
      return DateTime(date.year, date.month, date.day);
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) {
      return DateTime(date.year, date.month, date.day);
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return 'Seç';
    final d =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    if (_allDay) return d;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d  $hh:$mm';
  }

  String _recurrenceLabel(Recurrence r) {
    switch (r.freq) {
      case RecurrenceFreq.none:
        return 'Tek seferlik';
      case RecurrenceFreq.daily:
        return 'Günlük (x${r.interval})';
      case RecurrenceFreq.weekly:
        return 'Haftalık (x${r.interval})';
      case RecurrenceFreq.monthly:
        return 'Aylık (x${r.interval})';
    }
  }

  void _openRecurrencePicker() async {
    RecurrenceFreq sel = _recurrence.freq;
    int interval = _recurrence.interval;
    DateTime? until = _recurrence.until;

    await showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setM) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tekrarlama',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RecurrenceFreq>(
                  value: sel,
                  isExpanded: true,
                  onChanged: (v) => setM(() => sel = v ?? RecurrenceFreq.none),
                  items: RecurrenceFreq.values
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(
                            switch (f) {
                              RecurrenceFreq.none => 'Tek seferlik',
                              RecurrenceFreq.daily => 'Günlük',
                              RecurrenceFreq.weekly => 'Haftalık',
                              RecurrenceFreq.monthly => 'Aylık',
                            },
                          ),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Sıklık'),
                ),
                if (sel != RecurrenceFreq.none) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: '$interval',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Aralık (her kaç g/hafta/ay)',
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) setM(() => interval = n);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bitiş: ${until == null ? 'Yok' : _fmt(until)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await _pickDateTime(initial: until);
                          setM(() => until = picked);
                        },
                        child: const Text('Tarih seç'),
                      ),
                      if (until != null)
                        IconButton(
                          onPressed: () => setM(() => until = null),
                          icon: const Icon(Icons.clear),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _recurrence = Recurrence(
                        freq: sel,
                        interval: interval,
                        until: until,
                      );
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Tamam'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _addFreeTag() {
    final t = _tagCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _tags.add(t);
      _tagCtrl.clear();
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // 🔥 Kaydet + LLM ile etiket üretme
  Future<void> _save() async {
    if (_isSaving) return; // çift tıklamaya karşı
    if (!_formKey.currentState!.validate()) return;

    if (_type == ItemType.event) {
      if (_startAt == null) {
        _showSnack('Etkinlik/Toplantı için başlangıç zamanı seçin.');
        return;
      }
      if (!_allDay && _endAt != null && _startAt!.isAfter(_endAt!)) {
        _showSnack('Bitiş, başlangıçtan önce olamaz.');
        return;
      }
    }

    setState(() => _isSaving = true);

    // Manuel tagleri kopyala
    final tags = <String>{..._tags};

    // Otomatik etiketleme: ✨ SADECE başlık + kategori
    if (_autoTag) {
      try {
        final llmTags = await OllamaService.generateTagsForTask(
          title: _titleCtrl.text.trim(),
          // ✅ notes gönderilmiyor
          category: _category.label, // eğitim / kariyer / yaşam
        );

        tags.addAll(llmTags.take(5));
      } catch (e) {
        _showSnack('Otomatik etiketleme başarısız: $e');
      }
    }

    final nowId = DateTime.now().microsecondsSinceEpoch.toString();
    final item = Item(
      id: widget.initial?.id ?? nowId,
      type: _type,
      category: _category,
      title: _titleCtrl.text.trim(),
      emoji: null, // öğe bazında emoji yok
      allDay: _allDay,
      startAt: _startAt,
      endAt: _endAt,
      dueAt: _dueAt,
      estimatedMinutes: _estimatedMinutes,
      recurrence: _recurrence,
      remindMinutes: _remindMinutes,
      notes: _notes, // notlar sadece açıklama için
      // 🔹 Varsayılanı ORTA (2) yaptık, ve 1–3 arası clamp’liyoruz
      priority: (_priority ?? 2).clamp(1, 3),
      tags: tags.toList(),
      status: _type == ItemType.task
          ? (widget.initial?.status ?? TaskStatus.todo)
          : null,
      doneToday:
          _type == ItemType.habit ? (widget.initial?.doneToday ?? false) : null,
    );

    setState(() => _isSaving = false);
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.initial == null ? 'Yeni öğe' : 'Öğeyi düzenle',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Başlık zorunlu' : null,
                  onChanged: (_) => _refreshSuggestions(),
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ItemType>(
                        value: _type,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Tür'),
                        onChanged: (v) =>
                            setState(() => _type = v ?? ItemType.task),
                        items: const [
                          DropdownMenuItem(
                              value: ItemType.task, child: Text('Görev')),
                          DropdownMenuItem(
                              value: ItemType.event,
                              child: Text('Etkinlik/Toplantı')),
                          DropdownMenuItem(
                              value: ItemType.habit, child: Text('Alışkanlık')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<Category>(
                        value: _category,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Kategori'),
                        onChanged: (v) =>
                            setState(() => _category = v ?? Category.egitim),
                        items: Category.values
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.label),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tüm gün'),
                  value: _allDay,
                  onChanged: (v) => setState(() => _allDay = v),
                ),
                if (_type != ItemType.task) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _PickButton(
                          label: 'Başlangıç',
                          value: _fmt(_startAt),
                          onTap: () async {
                            final picked =
                                await _pickDateTime(initial: _startAt);
                            if (picked != null) {
                              setState(() => _startAt = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PickButton(
                          label: 'Bitiş',
                          value: _fmt(_endAt),
                          onTap: () async {
                            final picked = await _pickDateTime(initial: _endAt);
                            if (picked != null) {
                              setState(() => _endAt = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  _PickButton(
                    label: 'Son tarih (deadline)',
                    value: _fmt(_dueAt),
                    onTap: () async {
                      final picked = await _pickDateTime(initial: _dueAt);
                      if (picked != null) setState(() => _dueAt = picked);
                    },
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PickButton(
                        label: 'Tekrarlama',
                        value: _recurrenceLabel(_recurrence),
                        onTap: _openRecurrencePicker,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _remindMinutes,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Hatırlatma'),
                        hint: const Text('Yok'),
                        onChanged: (v) => setState(() => _remindMinutes = v),
                        items: const [
                          DropdownMenuItem<int?>(
                              value: null, child: Text('Yok')),
                          DropdownMenuItem<int?>(
                              value: 5, child: Text('5 dk önce')),
                          DropdownMenuItem<int?>(
                              value: 10, child: Text('10 dk önce')),
                          DropdownMenuItem<int?>(
                              value: 30, child: Text('30 dk önce')),
                          DropdownMenuItem<int?>(
                              value: 60, child: Text('1 saat önce')),
                          DropdownMenuItem<int?>(
                              value: 1440, child: Text('1 gün önce')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _priority,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Öncelik'),
                        hint: const Text('Seçilmedi'),
                        onChanged: (v) => setState(() => _priority = v),
                        // 🔹 1 = düşük, 3 = yüksek → yıldız sayısıyla uyumlu
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Düşük')),
                          DropdownMenuItem(value: 2, child: Text('Orta')),
                          DropdownMenuItem(value: 3, child: Text('Yüksek')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _notes,
                        decoration: const InputDecoration(labelText: 'Notlar'),
                        onChanged: (v) => _notes = v,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // ⏱ Tahmini süre alanı
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tahmini süre',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _durationCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Saat',
                    hintText: 'Örn: 1.5 saat',
                  ),
                  onChanged: (value) {
                    final normalized = value.replaceAll(',', '.');
                    final h = double.tryParse(normalized);
                    if (h == null || h <= 0) {
                      _estimatedMinutes = null;
                    } else {
                      _estimatedMinutes = (h * 60).round();
                    }
                  },
                ),

                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Otomatik etiketle'),
                  subtitle: const Text('Başlığa göre etiket ekle'),
                  value: _autoTag,
                  onChanged: (v) {
                    setState(() {
                      _autoTag = v;
                      if (v) _refreshSuggestions();
                    });
                  },
                ),
                if (!_autoTag) ...[
                  if (_suggested.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Önerilen tag’ler',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: -8,
                      children: _suggested.map((t) {
                        final selected = _tags.contains(t);
                        return ChoiceChip(
                          label: Text(t),
                          selected: selected,
                          onSelected: (sel) => setState(() {
                            sel ? _tags.add(t) : _tags.remove(t);
                          }),
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: Colors.grey.shade300,
                          side: BorderSide(color: Colors.grey.shade300),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity:
                              const VisualDensity(horizontal: -3, vertical: -3),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Yeni tag yaz (Enter ile ekle)',
                          ),
                          onSubmitted: (_) => _addFreeTag(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _addFreeTag,
                        child: const Text('Ekle'),
                      ),
                    ],
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Seçili tag’ler',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: -8,
                      children: _tags
                          .map(
                            (t) => InputChip(
                              label: Text(t),
                              onDeleted: () => setState(() => _tags.remove(t)),
                              backgroundColor: Colors.grey.shade200,
                              deleteIconColor: Colors.black54,
                              side: BorderSide(color: Colors.grey.shade300),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                  horizontal: -3, vertical: -3),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.initial == null ? 'Kaydet' : 'Güncelle',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _PickButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
