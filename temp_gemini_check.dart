import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('NO_ENV_FILE');
    return;
  }
  final lines = envFile.readAsLinesSync();
  final apiKeyLine = lines.firstWhere((line) => line.startsWith('GEMINI_API_KEY='), orElse: () => '');
  final key = apiKeyLine.split('=');
  if (key.length < 2 || key[1].trim().isEmpty) {
    print('NO_KEY');
    return;
  }
  final apiKey = key.sublist(1).join('=');
  print('API_KEY_PRESENT:${apiKey.length}');
  try {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey.trim(),
    );
    final response = await model.generateContent([
      Content.text('Hello from Dart. Reply with short JSON: {"status":"ok"}.')
    ]);
    print('RESPONSE_TEXT:${response.text}');
  } catch (e, st) {
    print('ERROR:${e.runtimeType}:${e}');
    print(st);
  }
}
