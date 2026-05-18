import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ReceiptScannerService {
  /// Scans receipt image or PDF bytes and returns a structured Map of extracted data.
  static Future<Map<String, dynamic>> scanReceipt(Uint8List fileBytes, String mimeType) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY is not set or empty in the .env file');
      }

      print('Initializing Gemini model for receipt scan...');
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
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
        Content.multi([
          DataPart(mimeType, fileBytes),
          TextPart(prompt),
        ])
      ];

      final response = await model.generateContent(content);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from Google AI');
      }

      print('Google AI Raw Response: $responseText');
      final Map<String, dynamic> parsedJson = jsonDecode(responseText.trim());

      // Ensure standard format of returned keys
      return {
        'merchantName': parsedJson['merchantName'] ?? '',
        'date': parsedJson['date'] ?? DateTime.now().toString().split(' ')[0],
        'taxAmount': (parsedJson['taxAmount'] ?? 0.0).toDouble(),
        'subtotal': (parsedJson['subtotal'] ?? 0.0).toDouble(),
        'totalAmount': (parsedJson['totalAmount'] ?? 0.0).toDouble(),
        'items': List<Map<String, dynamic>>.from(
          (parsedJson['items'] ?? []).map((item) => {
            'name': item['name'] ?? '',
            'quantity': item['quantity'] ?? 1,
            'unitPrice': (item['unitPrice'] ?? 0.0).toDouble(),
            'totalPrice': (item['totalPrice'] ?? 0.0).toDouble(),
            'category': item['category'] ?? 'Other',
          }),
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
}
