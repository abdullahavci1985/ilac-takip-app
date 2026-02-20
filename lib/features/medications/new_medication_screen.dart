import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_db.dart';
import '../../core/db/db_provider.dart';
import '../../core/time/time_service.dart';
import '../doses/dose_scheduler.dart';

class NewMedicationScreen extends ConsumerStatefulWidget {
  const NewMedicationScreen({super.key});

  @override
  ConsumerState<NewMedicationScreen> createState() => _NewMedicationScreenState();
}

class _NewMedicationScreenState extends ConsumerState<NewMedicationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController(text: '1');
  String _unit = 'adet';

  String _scheduleType = 'daily'; // daily | weekly
  final Set<int> _weekDays = {1, 2, 3, 4, 5, 6, 7};

  final List<TimeOfDay> _times = [const TimeOfDay(hour: 9, minute: 0)];

  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    super.dispose();
  }

  String _weekdayLabel(int d) {
    return switch (d) {
      1 => 'Pzt',
      2 => 'Sal',
      3 => 'Çar',
      4 => 'Per',
      5 => 'Cum',
      6 => 'Cmt',
      7 => 'Paz',
      _ => '$d',
    };
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times.isNotEmpty ? _times.last : const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;

    setState(() {
      _times.add(picked);
      _times.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    });
  }

  void _removeTime(int index) {
    setState(() => _times.removeAt(index));
  }

  String _toHHmm(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az 1 saat eklemelisin.')),
      );
      return;
    }
    if (_scheduleType == 'weekly' && _weekDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Haftalık plan için en az 1 gün seçmelisin.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final db = ref.read(dbProvider);
      final scheduler = DoseScheduler(db);

      final dose = double.tryParse(_doseCtrl.text.replaceAll(',', '.')) ?? 1.0;

      final medId = await db.createMedication(
        MedicationsCompanion.insert(
          name: _nameCtrl.text.trim(),
          doseAmount: dose,
          doseUnit: _unit,
        ),
      );

      final timesJson = jsonEncode(_times.map(_toHHmm).toList());
      final today = TimeService.now();
      final startDate = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      final scheduleId = await db.createSchedule(
        SchedulesCompanion.insert(
          medicationId: medId,
          type: Value(_scheduleType),
          timesJson: Value(timesJson),
          daysOfWeekJson: _scheduleType == 'weekly'
              ? Value(jsonEncode(_weekDays.toList()..sort()))
              : const Value.absent(),
          startDateIso: Value(startDate),
        ),
      );

      await scheduler.rescheduleSchedule(scheduleId, daysAhead: 14);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni İlaç'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'İlaç adı',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _doseCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Doz',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final d = double.tryParse((v ?? '').replaceAll(',', '.'));
                          if (d == null || d <= 0) return 'Geçerli doz gir';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Birim',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'adet', child: Text('adet')),
                          DropdownMenuItem(value: 'mg', child: Text('mg')),
                          DropdownMenuItem(value: 'ml', child: Text('ml')),
                        ],
                        onChanged: (v) => setState(() => _unit = v ?? 'adet'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _scheduleType,
                  decoration: const InputDecoration(
                    labelText: 'Plan türü',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Her gün')),
                    DropdownMenuItem(value: 'weekly', child: Text('Haftalık')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _scheduleType = v ?? 'daily';
                      if (_scheduleType == 'daily') {
                        _weekDays
                          ..clear()
                          ..addAll([1,2,3,4,5,6,7]);
                      } else {
                        _weekDays
                          ..clear()
                          ..addAll([1,2,3,4,5]);
                      }
                    });
                  },
                ),
                if (_scheduleType == 'weekly') ...[
                  const SizedBox(height: 12),
                  const Text('Günler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final selected = _weekDays.contains(day);
                      return FilterChip(
                        label: Text(_weekdayLabel(day), style: const TextStyle(fontSize: 18)),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _weekDays.add(day);
                            } else {
                              _weekDays.remove(day);
                            }
                          });
                        },
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saatler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    TextButton.icon(
                      onPressed: _addTime,
                      icon: const Icon(Icons.add),
                      label: const Text('Saat ekle'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_times.length, (i) {
                  final label = _toHHmm(_times[i]);
                  return Card(
                    child: ListTile(
                      title: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _times.length == 1 ? null : () => _removeTime(i),
                        tooltip: 'Sil',
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
