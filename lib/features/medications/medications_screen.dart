import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_db.dart';
import '../../core/db/db_provider.dart';
import 'medication_detail_screen.dart';
import 'new_medication_screen.dart';

final medicationsProvider = FutureProvider<List<Medication>>((ref) async {
  final db = ref.watch(dbProvider);
  return db.getAllMedications();
});

class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(medicationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('İlaçlar'), centerTitle: true),
      body: meds.when(
        data: (items) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('Henüz ilaç yok.', style: TextStyle(fontSize: 20)))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final m = items[i];
                            return Card(
                              child: ListTile(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => MedicationDetailScreen(medicationId: m.id)),
                                  );
                                },
                                title: Text(m.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                                subtitle: Text('${m.doseAmount} ${m.doseUnit}', style: const TextStyle(fontSize: 18)),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NewMedicationScreen()),
                    );
                    ref.invalidate(medicationsProvider);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('İlaç Ekle'),
                ),
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
