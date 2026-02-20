import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_db.g.dart';

class Medications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get doseAmount => real().withDefault(const Constant(1.0))();
  TextColumn get doseUnit => text().withDefault(const Constant('adet'))();
  TextColumn get instructions => text().nullable()();

  IntColumn get stockCount => integer().nullable()();
  IntColumn get stockThreshold => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Schedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicationId => integer()();

  TextColumn get type => text().withDefault(const Constant('daily'))(); // daily/weekly/interval
  TextColumn get timesJson => text().withDefault(const Constant('[]'))(); // ["09:00","21:00"]
  TextColumn get daysOfWeekJson => text().nullable()(); // [1,3,5]

  TextColumn get startDateIso => text()(); // YYYY-MM-DD
  TextColumn get endDateIso => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
}

class DoseEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get scheduleId => integer()();
  IntColumn get medicationId => integer()();

  TextColumn get plannedAtIso => text()(); // ISO datetime
  TextColumn get status => text().withDefault(const Constant('planned'))(); // planned/taken/snoozed/missed

  TextColumn get takenAtIso => text().nullable()();
  IntColumn get snoozeCount => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
}

@DriftDatabase(tables: [Medications, Schedules, DoseEvents])
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Medication
  Future<int> createMedication(MedicationsCompanion data) =>
      into(medications).insert(data);

  Future<List<Medication>> getAllMedications() =>
      (select(medications)..where((m) => m.isActive.equals(true))).get();

  Future<Medication?> getMedicationById(int id) {
    return (select(medications)..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  // Schedule
  Future<int> createSchedule(SchedulesCompanion data) =>
      into(schedules).insert(data);

  Future<List<Schedule>> getEnabledSchedules() =>
      (select(schedules)..where((s) => s.enabled.equals(true))).get();

  Future<Schedule?> getScheduleByMedicationId(int medicationId) {
    return (select(schedules)..where((s) => s.medicationId.equals(medicationId))).getSingleOrNull();
  }

  Future<void> updateSchedule({
    required int scheduleId,
    required String type,
    required String timesJson,
    String? daysOfWeekJson,
    String? startDateIso,
    String? endDateIso,
    bool? enabled,
  }) async {
    await (update(schedules)..where((s) => s.id.equals(scheduleId))).write(
      SchedulesCompanion(
        type: Value(type),
        timesJson: Value(timesJson),
        daysOfWeekJson: daysOfWeekJson == null ? const Value.absent() : Value(daysOfWeekJson),
        startDateIso: startDateIso == null ? const Value.absent() : Value(startDateIso),
        endDateIso: endDateIso == null ? const Value.absent() : Value(endDateIso),
        enabled: enabled == null ? const Value.absent() : Value(enabled),
      ),
    );
  }

  // Dose Events
  Future<int> createDoseEvent(DoseEventsCompanion data) =>
      into(doseEvents).insert(data);

  Future<List<DoseEvent>> getTodayDoseEvents(String dayStartIso, String dayEndIso) {
    return (select(doseEvents)
          ..where((d) => d.plannedAtIso.isBiggerOrEqualValue(dayStartIso))
          ..where((d) => d.plannedAtIso.isSmallerThanValue(dayEndIso))
          ..orderBy([(d) => OrderingTerm(expression: d.plannedAtIso)]))
        .get();
  }

  Future<DoseEvent?> getDoseEventById(int id) {
    return (select(doseEvents)..where((d) => d.id.equals(id))).getSingleOrNull();
  }

  Future<void> updateDoseEventStatus({
    required int id,
    required String status,
    String? takenAtIso,
    int? snoozeCount,
    String? plannedAtIso,
  }) async {
    await (update(doseEvents)..where((d) => d.id.equals(id))).write(
      DoseEventsCompanion(
        status: Value(status),
        takenAtIso: Value(takenAtIso),
        snoozeCount: snoozeCount == null ? const Value.absent() : Value(snoozeCount),
        plannedAtIso: plannedAtIso == null ? const Value.absent() : Value(plannedAtIso),
      ),
    );
  }

  Future<void> decrementStockIfAny(int medicationId, {int amount = 1}) async {
    final med = await (select(medications)..where((m) => m.id.equals(medicationId))).getSingleOrNull();
    if (med == null) return;
    if (med.stockCount == null) return;

    final newCount = (med.stockCount! - amount);
    await (update(medications)..where((m) => m.id.equals(medicationId))).write(
      MedicationsCompanion(stockCount: Value(newCount < 0 ? 0 : newCount)),
    );
  }

  Future<List<int>> getFutureDoseEventIdsBySchedule(int scheduleId, String nowIso) async {
    final rows = await (select(doseEvents)
          ..where((d) => d.scheduleId.equals(scheduleId))
          ..where((d) => d.plannedAtIso.isBiggerOrEqualValue(nowIso)))
        .get();
    return rows.map((e) => e.id).toList();
  }

  Future<void> deleteFutureDoseEventsBySchedule(int scheduleId, String nowIso) async {
    await (delete(doseEvents)
          ..where((d) => d.scheduleId.equals(scheduleId))
          ..where((d) => d.plannedAtIso.isBiggerOrEqualValue(nowIso)))
        .go();
  }

  static List<String> parseTimes(String timesJson) {
    final list = (jsonDecode(timesJson) as List).map((e) => e.toString()).toList();
    return list;
  }

  static List<int> parseDaysOfWeek(String? daysJson) {
    if (daysJson == null) return [];
    final list = (jsonDecode(daysJson) as List).map((e) => int.parse(e.toString())).toList();
    return list;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
