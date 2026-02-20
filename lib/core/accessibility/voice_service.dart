import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final FlutterTts _tts = FlutterTts();
  bool enabled = true;

  Future<void> init() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.45); // yavaş
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    if (!enabled) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
