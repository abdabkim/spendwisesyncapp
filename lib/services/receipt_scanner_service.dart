import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ReceiptScannerService {
  /// Scans receipt image or PDF bytes and returns a structured Map of extracted data.
  static Future<Map<String, dynamic>> scanReceipt(
    Uint8List fileBytes,
    String mimeType,
  ) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY is not set or empty in the .env file');
      }

      print('Initializing Gemini model for receipt scan...');
      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final prompt = '''
You are an expert receipt parser. Analyze the provided receipt image or PDF document and extract the receipt details.
Ensure you calculate and extract:
1. The Merchant/Store Name (clean, e.g., "Walmart" instead of "WALMART STORE #1234").
2. The Receipt Date (in YYYY-MM-DD format). If not found, default to today's date.
3. Tax Amount (or 0.0 if not found/applicable).
4. Subtotal (or 0.0 if not found).
5. Total Amount (or 0.0 if not found).
6. A detailed, clean, itemized list of all purchased items. For each item, extract:
   - Item Name (clean, readable title, e.g., "Whole Milk" instead of "1 WHL MLK 4.99")
   - Quantity (integer, default to 1 if not specified)
   - Unit Price (double)
   - Total Price (double, which is unitPrice * quantity)
   - Category (Categorize into one of these: "Groceries", "Dining Out", "Coffee & Snacks", "Transport", "Electronics", "Health", "Personal", "Home", "Finance", "Errands", "Work", or "Other")

Output the extracted details STRICTLY as a raw JSON object matching the following schema:
{
  "merchantName": "Store Name",
  "date": "YYYY-MM-DD",
  "taxAmount": 0.00,
  "subtotal": 0.00,
  "totalAmount": 0.00,
  "items": [
    {
      "name": "Item Name",
      "quantity": 1,
      "unitPrice": 4.99,
      "totalPrice": 4.99,
      "category": "Groceries"
    }
  ]
}
''';

      print('Sending file bytes to Gemini model with MIME type: $mimeType');
      final content = [
        Content.multi([DataPart(mimeType, fileBytes), TextPart(prompt)]),
      ];

      final response = await model.generateContent(content);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from Google AI');
      }

      print('Google AI Raw Response: $responseText');
      final String jsonResponse = _extractJsonFromResponse(responseText);
      final Map<String, dynamic> parsedJson = jsonDecode(jsonResponse.trim());

      // Ensure standard format of returned keys
      return {
        'merchantName': parsedJson['merchantName'] ?? '',
        'date': parsedJson['date'] ?? DateTime.now().toString().split(' ')[0],
        'taxAmount': _toDouble(parsedJson['taxAmount']),
        'subtotal': _toDouble(parsedJson['subtotal']),
        'totalAmount': _toDouble(parsedJson['totalAmount']),
        'items': List<Map<String, dynamic>>.from(
          (parsedJson['items'] ?? []).map(
            (item) => {
              'name': item['name'] ?? '',
              'quantity': _toInt(item['quantity'] ?? 1),
              'unitPrice': _toDouble(item['unitPrice']),
              'totalPrice': _toDouble(item['totalPrice']),
              'category': item['category'] ?? 'Other',
            },
          ),
        ),
        'rawText': responseText,
      };
    } catch (e) {
      print('Error scanning receipt with Google AI: $e');
      // Fallback response
      return {
        'merchantName': 'Scanned Store',
        'date': DateTime.now().toString().split(' ')[0],
        'taxAmount': 0.0,
        'subtotal': 0.0,
        'totalAmount': 0.0,
        'items': [],
        'rawText': 'Failed to parse: $e',
      };
    }
  }

  static String _extractJsonFromResponse(String responseText) {
    final trimmed = responseText.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return trimmed.substring(start, end + 1);
    }

    throw FormatException('Unable to locate a JSON object in the AI response.');
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '').trim()) ?? 0.0;
    }
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value.split('.').first.replaceAll(',', '').trim()) ??
          0;
    }
    return 0;
  }
}
