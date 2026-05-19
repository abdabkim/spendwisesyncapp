import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  final envFile = File('.env');
  final lines = envFile.readAsLinesSync();
  final apiKeyLine = lines.firstWhere((line) => line.startsWith('GEMINI_API_KEY='), orElse: () => '');
  final apiKey = apiKeyLine.split('=').sublist(1).join('=');
  final models = [
    'gemini-1.5-flash-latest',
    'gemini-1.5-flash',
    'gemini-1.5',
    'gemini-1.0',
    'gemini-1.0-mini',
    'gemini-1.5-realtime-preview',
  ];
  for (final modelName in models) {
    print('TRY_MODEL:$modelName');
    try {
      final model = GenerativeModel(model: modelName, apiKey: apiKey.trim());
      final response = await model.generateContent([
        Content.text('Hello from Dart. Reply with JSON {"status":"ok"}.')
      ]);
      print('SUCCESS:$modelName => ${response.text}');
      break;
    } catch (e, st) {
      print('FAIL:$modelName => ${e.runtimeType}:${e}');
    }
  }
}
