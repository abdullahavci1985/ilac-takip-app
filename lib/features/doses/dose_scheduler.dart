import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;

import '../../core/db/app_db.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/time/time_service.dart';

class DoseScheduler {
  DoseScheduler(this.db);

  final AppDb db;

  Future<void> generateAndSchedule({int daysAhead = 14}) async {
    final schedules = await db.getEnabledSchedules();

    final now = TimeService.now();
    final startDay = TimeService.startOfDay(now);

    for (final s in schedules) {
      final sStart = DateTime.parse(s.startDateIso);
      final sEnd = s.endDateIso == null ? null : DateTime.parse(s.endDateIso!);

      for (int i = 0; i < daysAhead; i++) {
        final day = startDay.add(Duration(days: i));
        final dayDate = DateTime(day.year, day.month, day.day);

        if (dayDate.isBefore(DateTime(sStart.year, sStart.month, sStart.day))) continue;
        if (sEnd != null) {
          final endDate = DateTime(sEnd.year, sEnd.month, sEnd.day);
          if (dayDate.isAfter(endDate)) continue;
        }

        if (!_isScheduleActiveOnDay(s, day)) continue;

        final times = AppDb.parseTimes(s.timesJson);
        for (final t in times) {
          final when = _combineDayAndTime(day, t);
          if (when.isBefore(now)) continue;

          final doseEventId = await db.createDoseEvent(
            DoseEventsCompanion.insert(
              scheduleId: s.id,
              medicationId: s.medicationId,
              plannedAtIso: when.toIso8601String(),
            ),
          );

          await NotificationService.scheduleDose(
            notificationId: doseEventId,
            doseEventId: doseEventId,
            title: 'İlaç zamanı',
            body: 'Planlanan doz: ${_formatTime(t)}',
            when: when,
          );
        }
      }
    }
  }

  Future<void> rescheduleSchedule(int scheduleId, {int daysAhead = 14}) async {
    final now = TimeService.now();
    final nowIso = now.toIso8601String();

    final ids = await db.getFutureDoseEventIdsBySchedule(scheduleId, nowIso);
    for (final id in ids) {
      await NotificationService.cancel(id);
    }

    await db.deleteFutureDoseEventsBySchedule(scheduleId, nowIso);

    await generateAndSchedule(daysAhead: daysAhead);
  }

  bool _isScheduleActiveOnDay(Schedule s, tz.TZDateTime day) {
    if (s.type == 'daily') return true;
    if (s.type == 'weekly') {
      final days = AppDb.parseDaysOfWeek(s.daysOfWeekJson);
      final weekday = day.weekday; // Mon=1..Sun=7
      return days.contains(weekday);
    }
    return true;
  }

  tz.TZDateTime _combineDayAndTime(tz.TZDateTime day, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return tz.TZDateTime(tz.local, day.year, day.month, day.day, h, m);
  }

  String _formatTime(String hhmm) => hhmm;

  Future<void> handleAction(int doseEventId, String actionId) async {
    final ev = await db.getDoseEventById(doseEventId);
    if (ev == null) return;

    if (actionId == NotificationService.actionTaken) {
      final now = TimeService.now();
      await db.updateDoseEventStatus(
        id: doseEventId,
        status: 'taken',
        takenAtIso: now.toIso8601String(),
      );
      await db.decrementStockIfAny(ev.medicationId, amount: 1);
      await NotificationService.cancel(doseEventId);
      return;
    }

    if (actionId == NotificationService.actionMissed) {
      await db.updateDoseEventStatus(id: doseEventId, status: 'missed');
      await NotificationService.cancel(doseEventId);
      return;
    }

    if (actionId == NotificationService.actionSnooze) {
      final oldPlanned = DateTime.parse(ev.plannedAtIso);
      final newPlanned = tz.TZDateTime.from(oldPlanned, tz.local).add(const Duration(minutes: 10));
      final newCount = ev.snoozeCount + 1;

      await db.updateDoseEventStatus(
        id: doseEventId,
        status: 'snoozed',
        snoozeCount: newCount,
        plannedAtIso: newPlanned.toIso8601String(),
      );

      await NotificationService.cancel(doseEventId);
      await NotificationService.scheduleDose(
        notificationId: doseEventId,
        doseEventId: doseEventId,
        title: 'İlaç zamanı (ertelendi)',
        body: '10 dk ertelendi',
        when: newPlanned,
      );
    }
  }

  Future<void> autoMarkMissed({Duration grace = const Duration(minutes: 60)}) async {
    final now = TimeService.now();
    final cutoff = now.subtract(grace);

    final start = TimeService.startOfDay(now.subtract(const Duration(days: 1))).toIso8601String();
    final end = TimeService.endOfDayExclusive(now).toIso8601String();
    final recent = await db.getTodayDoseEvents(start, end);

    for (final ev in recent) {
      if (ev.status == 'taken' || ev.status == 'missed') continue;
      final planned = DateTime.parse(ev.plannedAtIso);
      if (planned.isBefore(DateTime.parse(cutoff.toIso8601String()))) {
        await db.updateDoseEventStatus(id: ev.id, status: 'missed');
        await NotificationService.cancel(ev.id);
      }
    }
  }
}
