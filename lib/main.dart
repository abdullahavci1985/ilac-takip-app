import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/accessibility/voice_service.dart';
import 'core/db/db_provider.dart';
import 'core/notifications/notification_service.dart';
import 'core/time/time_service.dart';
import 'features/doses/dose_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TimeService.init();
  await VoiceService.instance.init();

  final container = ProviderContainer();
  final db = container.read(dbProvider);
  final scheduler = DoseScheduler(db);

  await NotificationService.init(
    onAction: (doseEventId, actionId) async {
      await scheduler.handleAction(doseEventId, actionId);
    },
  );

  // Uygulama açılınca kaçırılanları otomatik toparla
  await scheduler.autoMarkMissed();

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
