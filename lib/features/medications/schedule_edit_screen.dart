import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_db.dart';
import '../../core/db/db_provider.dart';
import '../../core/time/time_service.dart';
import '../doses/dose_scheduler.dart';

class ScheduleEditScreen extends ConsumerStatefulWidget {
  const ScheduleEditScreen({super.key, required this.medicationId});
  final int medicationId;

  @override
  ConsumerState<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends ConsumerState<ScheduleEditScreen> {
  bool _loading = true;
  bool _saving = false;

  int? _scheduleId;
  String _scheduleType = 'daily';
  final Set<int> _weekDays = {1,2,3,4,5,6,7};
  final List<TimeOfDay> _times = [const TimeOfDay(hour: 9, minute: 0)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _weekdayLabel(int d) {
    return switch (d) {
      1 => 'Pzt', 2 => 'Sal', 3 => 'Çar', 4 => 'Per', 5 => 'Cum', 6 => 'Cmt', 7 => 'Paz', _ => '$d'
    };
  }

  String _toHHmm(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  TimeOfDay _fromHHmm(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  Future<void> _load() async {
    final db = ref.read(dbProvider);
    final sched = await db.getScheduleByMedicationId(widget.medicationId);
    if (sched != null) {
      _scheduleId = sched.id;
      _scheduleType = sched.type;

      final times = AppDb.parseTimes(sched.timesJson).map(_fromHHmm).toList();
      _times
        ..clear()
        ..addAll(times.isEmpty ? [const TimeOfDay(hour: 9, minute: 0)] : times);

      if (_scheduleType == 'weekly') {
        final days = AppDb.parseDaysOfWeek(sched.daysOfWeekJson);
        _weekDays
          ..clear()
          ..addAll(days.isEmpty ? [1,2,3,4,5] : days);
      } else {
        _weekDays
          ..clear()
          ..addAll([1,2,3,4,5,6,7]);
      }
    }
    setState(() => _loading = false);
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

  Future<void> _save() async {
    if (_scheduleId == null) return;
    if (_times.isEmpty) return;

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

      final timesJson = jsonEncode(_times.map(_toHHmm).toList());
      final daysJson = _scheduleType == 'weekly'
          ? jsonEncode((_weekDays.toList()..sort()))
          : null;

      final now = TimeService.now();
      final startDate = '${now.year.toString().padLeft(4,'0')}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';

      await db.updateSchedule(
        scheduleId: _scheduleId!,
        type: _scheduleType,
        timesJson: timesJson,
        daysOfWeekJson: daysJson,
        startDateIso: startDate,
      );

      await scheduler.rescheduleSchedule(_scheduleId!, daysAhead: 14);

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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Planı Düzenle'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
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
                        if (v) _weekDays.add(day); else _weekDays.remove(day);
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
                    onPressed: _times.length == 1 ? null : () => setState(() => _times.removeAt(i)),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
