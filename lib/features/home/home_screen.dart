import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accessibility/voice_service.dart';
import '../../core/db/app_db.dart';
import '../../core/db/db_provider.dart';
import '../../core/time/time_service.dart';
import '../doses/dose_scheduler.dart';

final todayDosesProvider = FutureProvider<List<DoseEvent>>((ref) async {
  final db = ref.watch(dbProvider);
  final now = TimeService.now();
  final start = TimeService.startOfDay(now).toIso8601String();
  final end = TimeService.endOfDayExclusive(now).toIso8601String();
  return db.getTodayDoseEvents(start, end);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doses = ref.watch(todayDosesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bugün'),
        centerTitle: true,
      ),
      body: doses.when(
        data: (items) {
          final now = TimeService.now();

          final next = items
              .where((d) => d.status != 'taken' && d.status != 'missed')
              .map((d) => (d, DateTime.parse(d.plannedAtIso)))
              .toList()
            ..sort((a, b) => a.$2.compareTo(b.$2));

          final nextDose = next.isEmpty ? null : next.first.$1;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                if (nextDose != null) ...[
                  _BigNextDoseCard(dose: nextDose),
                  const SizedBox(height: 16),
                ] else ...[
                  const _BigInfoCard(text: 'Bugün için sıradaki doz yok.'),
                  const SizedBox(height: 16),
                ],
                const Text('Bugünün Dozları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const _BigInfoCard(text: 'Bugün için planlı doz yok.')
                else
                  ...items.map((d) => _LargeDoseTile(dose: d)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}

class _BigNextDoseCard extends ConsumerWidget {
  const _BigNextDoseCard({required this.dose});
  final DoseEvent dose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(dbProvider);
    final scheduler = DoseScheduler(db);

    final time = dose.plannedAtIso.length >= 16 ? dose.plannedAtIso.substring(11, 16) : dose.plannedAtIso;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sıradaki Doz', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(time, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: 'Sesli oku',
              child: OutlinedButton(
                onPressed: () async {
                  await VoiceService.instance.speak('Sıradaki ilaç saati $time. Lütfen ilacınızı alınız.');
                },
                child: const Text('🔊 Sesli Oku', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: 'İlacı aldım',
              child: FilledButton(
                onPressed: () async {
                  await scheduler.handleAction(dose.id, 'ACTION_TAKEN');
                  ref.invalidate(todayDosesProvider);
                },
                child: const Text('✅ Aldım'),
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label: 'İlacı 10 dakika ertele',
              child: FilledButton(
                onPressed: () async {
                  await scheduler.handleAction(dose.id, 'ACTION_SNOOZE');
                  ref.invalidate(todayDosesProvider);
                },
                child: const Text('⏰ 10 dk Ertele'),
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label: 'Bu dozu atladım',
              child: FilledButton(
                onPressed: () async {
                  await scheduler.handleAction(dose.id, 'ACTION_MISSED');
                  ref.invalidate(todayDosesProvider);
                },
                child: const Text('❌ Atladım'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeDoseTile extends StatelessWidget {
  const _LargeDoseTile({required this.dose});
  final DoseEvent dose;

  @override
  Widget build(BuildContext context) {
    final time = dose.plannedAtIso.length >= 16 ? dose.plannedAtIso.substring(11, 16) : dose.plannedAtIso;
    final status = switch (dose.status) {
      'taken' => 'Aldı',
      'missed' => 'Atladı',
      'snoozed' => 'Ertelendi',
      _ => 'Planlı',
    };

    return Card(
      child: ListTile(
        title: Text(time, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        subtitle: Text('Durum: $status', style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

class _BigInfoCard extends StatelessWidget {
  const _BigInfoCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
