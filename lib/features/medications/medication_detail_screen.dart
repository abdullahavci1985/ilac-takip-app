import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_db.dart';
import '../../core/db/db_provider.dart';
import 'schedule_edit_screen.dart';

final medicationDetailProvider = FutureProvider.family<Medication?, int>((ref, id) async {
  final db = ref.watch(dbProvider);
  return db.getMedicationById(id);
});

final medicationScheduleProvider = FutureProvider.family<Schedule?, int>((ref, medicationId) async {
  final db = ref.watch(dbProvider);
  return db.getScheduleByMedicationId(medicationId);
});

class MedicationDetailScreen extends ConsumerWidget {
  const MedicationDetailScreen({super.key, required this.medicationId});
  final int medicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final med = ref.watch(medicationDetailProvider(medicationId));
    final sched = ref.watch(medicationScheduleProvider(medicationId));

    return Scaffold(
      appBar: AppBar(title: const Text('İlaç'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: med.when(
          data: (m) {
            if (m == null) return const Center(child: Text('İlaç bulunamadı.'));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text('${m.doseAmount} ${m.doseUnit}', style: const TextStyle(fontSize: 20)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                sched.when(
                  data: (s) {
                    if (s == null) return const _InfoCard(text: 'Plan bulunamadı.');
                    final typeLabel = s.type == 'weekly' ? 'Haftalık' : 'Her gün';
                    return _InfoCard(text: 'Plan: $typeLabel');
                  },
                  loading: () => const _InfoCard(text: 'Plan yükleniyor...'),
                  error: (e, st) => _InfoCard(text: 'Plan hatası: $e'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ScheduleEditScreen(medicationId: medicationId)),
                    );
                    ref.invalidate(medicationScheduleProvider(medicationId));
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Planı Düzenle'),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Hata: $e')),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});
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
