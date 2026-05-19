import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  final envFile = File('.env');
  final lines = envFile.readAsLinesSync();
  final apiKeyLine = lines.firstWhere((line) => line.startsWith('GEMINI_API_KEY='), orElse: () => '');
  final apiKey = apiKeyLine.split('=').sublist(1).join('=');
  final modelName = 'gemini-flash-latest';
  print('TRY_MODEL:$modelName');
  try {
    final model = GenerativeModel(model: modelName, apiKey: apiKey.trim());
    final response = await model.generateContent([
      Content.text('Hello from Dart. Reply with JSON {"status":"ok"}.')
    ]);
    print('SUCCESS:${response.text}');
  } catch (e, st) {
    print('FAIL:${e.runtimeType}:${e}');
    print(st);
  }
}
