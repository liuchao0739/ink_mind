import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService() : _tts = FlutterTts();

  final FlutterTts _tts;

  Future<void> init() async {
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.5);
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();

  Future<void> pause() => _tts.pause();

  Future<void> setRate(double rate) => _tts.setSpeechRate(rate);
}

