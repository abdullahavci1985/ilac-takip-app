import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class TimeService {
  static Future<void> init() async {
    tz.initializeTimeZones();
    final name = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
  }

  static tz.TZDateTime now() => tz.TZDateTime.now(tz.local);

  static tz.TZDateTime startOfDay(tz.TZDateTime dt) =>
      tz.TZDateTime(tz.local, dt.year, dt.month, dt.day);

  static tz.TZDateTime endOfDayExclusive(tz.TZDateTime dt) =>
      startOfDay(dt).add(const Duration(days: 1));
}
