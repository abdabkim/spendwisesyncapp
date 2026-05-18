import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiAdvisorService {
  /// Fetches real-time budget, deduction, and receipt logs from Firestore,
  /// compiles them into a system instruction, and sends the conversation to Gemini.
  static Future<String> getFinancialAdvice(String userMessage, List<Content> chatHistory) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY is not set or empty in .env');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return "Please log in to receive personalized financial advice.";
      }
      final userId = user.uid;

      // 1. Fetch Budget Context
      double dailyLimit = 0;
      double dailySpent = 0;
      double weeklyLimit = 0;
      double weeklySpent = 0;
      double monthlyLimit = 0;
      double monthlySpent = 0;
      double payAmount = 0;
      double bankAmount = 0;
      double cashAmount = 0;
      double totalDeductions = 0;
      List<String> deductionsList = [];

      final dailyDoc = await FirebaseFirestore.instance.collection('budgets').doc('${userId}_daily').get();
      if (dailyDoc.exists) {
        dailyLimit = (dailyDoc.data()?['limitAmount'] ?? 0.0).toDouble();
        dailySpent = (dailyDoc.data()?['amountSpent'] ?? 0.0).toDouble();
      }

      final weeklyDoc = await FirebaseFirestore.instance.collection('budgets').doc('${userId}_weekly').get();
      if (weeklyDoc.exists) {
        weeklyLimit = (weeklyDoc.data()?['limitAmount'] ?? 0.0).toDouble();
        weeklySpent = (weeklyDoc.data()?['amountSpent'] ?? 0.0).toDouble();
      }

      final monthlyDoc = await FirebaseFirestore.instance.collection('budgets').doc('${userId}_monthly').get();
      if (monthlyDoc.exists) {
        monthlyLimit = (monthlyDoc.data()?['limitAmount'] ?? 0.0).toDouble();
        monthlySpent = (monthlyDoc.data()?['amountSpent'] ?? 0.0).toDouble();
        payAmount = (monthlyDoc.data()?['payAmount'] ?? 0.0).toDouble();
        bankAmount = (monthlyDoc.data()?['bankAmount'] ?? 0.0).toDouble();
        cashAmount = (monthlyDoc.data()?['cashAmount'] ?? 0.0).toDouble();
        totalDeductions = (monthlyDoc.data()?['totalDeductions'] ?? 0.0).toDouble();
        final deductions = monthlyDoc.data()?['monthlyDeductions'] as List?;
        if (deductions != null) {
          for (var item in deductions) {
            deductionsList.add("${item['name']}: \$${item['amount']}");
          }
        }
      }

      double netAvailable = bankAmount - totalDeductions - cashAmount;

      // 2. Fetch Recent Receipts Context (Query without orderBy to avoid index requirement, sort in-memory)
      final receiptsSnapshot = await FirebaseFirestore.instance
          .collection('receipts')
          .where('userId', isEqualTo: userId)
          .get();

      final docs = List<DocumentSnapshot>.from(receiptsSnapshot.docs);
      docs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>?;
        final bData = b.data() as Map<String, dynamic>?;
        final aTime = aData?['createdAt'] as Timestamp? ?? aData?['timestamp'] as Timestamp?;
        final bTime = bData?['createdAt'] as Timestamp? ?? bData?['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      final recentDocs = docs.take(5);

      StringBuffer receiptsSummary = StringBuffer();
      if (recentDocs.isEmpty) {
        receiptsSummary.writeln("No receipts scanned yet.");
      } else {
        for (var doc in recentDocs) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final merchant = data['merchantName'] ?? 'Unknown Merchant';
          final timestamp = data['timestamp'] as Timestamp?;
          final dateStr = timestamp != null
              ? "${timestamp.toDate().year}-${timestamp.toDate().month}-${timestamp.toDate().day}"
              : "Unknown Date";

          // Fetch items for this receipt
          final itemsSnapshot = await doc.reference.collection('receipt_items').get();
          double receiptTotal = 0;
          List<String> itemsList = [];
          for (var itemDoc in itemsSnapshot.docs) {
            final itemData = itemDoc.data();
            final name = itemData['name'] ?? 'Item';
            final qty = itemData['quantity'] ?? 1;
            final price = (itemData['totalPrice'] ?? 0.0).toDouble();
            final cat = itemData['category'] ?? 'Other';
            receiptTotal += price;
            itemsList.add("- $name ($qty) - \$${price.toStringAsFixed(2)} [$cat]");
          }

          receiptsSummary.writeln("🧾 Receipt from $merchant on $dateStr (Total: \$${receiptTotal.toStringAsFixed(2)}):");
          for (var itemLine in itemsList) {
            receiptsSummary.writeln("  $itemLine");
          }
        }
      }

      // 3. Fetch Synced Calendar Events Context (sort in-memory defensively)
      final calendarSnapshot = await FirebaseFirestore.instance
          .collection('calendar_events')
          .where('userId', isEqualTo: userId)
          .get();

      final calendarDocs = List<DocumentSnapshot>.from(calendarSnapshot.docs);
      calendarDocs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>?;
        final bData = b.data() as Map<String, dynamic>?;
        final aTime = aData?['date'] as Timestamp?;
        final bTime = bData?['date'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

      StringBuffer calendarSummary = StringBuffer();
      if (calendarDocs.isEmpty) {
        calendarSummary.writeln("No synced calendar events scheduled yet.");
      } else {
        for (var doc in calendarDocs) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final title = data['title'] ?? 'Event';
          final timestamp = data['date'] as Timestamp?;
          final dateStr = timestamp != null
              ? "${timestamp.toDate().year}-${timestamp.toDate().month}-${timestamp.toDate().day}"
              : "Unknown Date";
          final projectedCost = (data['projectedCost'] ?? 0.0).toDouble();
          
          if (projectedCost > 0) {
            calendarSummary.writeln("- 📅 $title on $dateStr (Projected spend: +\$${projectedCost.toStringAsFixed(2)})");
          } else {
            calendarSummary.writeln("- 📅 $title on $dateStr (Standard entry)");
          }
        }
      }

      // 4. Setup Gemini Model with contextual system prompt
      final systemPrompt = '''
You are "SpendWise Advisor", a friendly, certified financial planner chatbot integrated into the SpendWise Sync app.
Your job is to provide highly customized, actionable, and smart financial advice, budget reviews, and saving tips based on the user's actual financial data provided below:

USER FINANCIAL PROFILE:
- Monthly Income / Pay Amount: \$${payAmount.toStringAsFixed(2)}
- Bank Account Balance: \$${bankAmount.toStringAsFixed(2)}
- Cash on Hand: \$${cashAmount.toStringAsFixed(2)}
- Monthly Fixed Deductions: \$${totalDeductions.toStringAsFixed(2)} (${deductionsList.join(', ')})
- Net Monthly Available Balance: \$${netAvailable.toStringAsFixed(2)}
     
BUDGET LIMITS AND SPENDING PROGRESS:
- Daily Limit: \$${dailyLimit.toStringAsFixed(2)} | Spent: \$${dailySpent.toStringAsFixed(2)} | Remaining: \$${(dailyLimit - dailySpent).toStringAsFixed(2)}
- Weekly Limit: \$${weeklyLimit.toStringAsFixed(2)} | Spent: \$${weeklySpent.toStringAsFixed(2)} | Remaining: \$${(weeklyLimit - weeklySpent).toStringAsFixed(2)}
- Monthly Limit: \$${monthlyLimit.toStringAsFixed(2)} | Spent: \$${monthlySpent.toStringAsFixed(2)} | Remaining: \$${(monthlyLimit - monthlySpent).toStringAsFixed(2)}

UPCOMING CALENDAR EVENTS & PREDICTIVE FORECASTING:
${calendarSummary.toString()}

RECENT TRANSACTIONS & SCAN LOG:
${receiptsSummary.toString()}

Strict Guidelines for your response:
1. Be highly encouraging, empathetic, and professional.
2. Reference their actual data (e.g., if their monthly spent is close to limit, warn them gently; if they spend a lot on specific categories like Groceries, suggest meal planning).
3. Keep responses relatively concise, formatted beautifully in markdown, using bullet points and bolding for readability.
4. Never give dangerous investment or trading advice. Focus on budgeting, saving, and smart spending.
5. If the user asks general financial questions, relate them back to their current profile if helpful.
6. Actively analyze their upcoming calendar events. If they have high-spend events (like weddings, flights, or vacations), proactively warn them about scaling their budget limits (e.g. advise adjusting daily/weekly caps to save up for these events ahead of time).
''';

      print('Initializing Gemini chat...');
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(systemPrompt),
      );

      // We start a chat session with historical logs
      final chat = model.startChat(history: chatHistory);
      final response = await chat.sendMessage(Content.text(userMessage));
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from Google AI Advisor');
      }

      return responseText;
    } catch (e) {
      print('Error in financial advisor service: $e');
      return "Oops! I encountered an error retrieving your financial profile. Please make sure your budget goals are set up correctly, and let's try again! (Error: $e)";
    }
  }

  /// Provides support and app navigation guidance based on the app's features.
  static Future<String> getSupportAdvice(String userMessage, List<Content> chatHistory) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY is not set or empty in .env');
      }

      final user = FirebaseAuth.instance.currentUser;
      String userName = "User";
      if (user != null) {
        userName = user.displayName ?? "User";
      }

      final systemPrompt = '''
You are the "SpendWise Support Agent", a friendly, highly knowledgeable AI assistant embedded within the SpendWise Sync app.
Your job is to help users navigate the app, understand its features, and troubleshoot common issues.

SPENDWISE SYNC APP KNOWLEDGE BASE:
1. **Home / Dashboard**: Provides an overview of the user's daily, weekly, and monthly budget limits and current spending. It shows recent transactions and quick-access buttons.
2. **Budget / Expense Screen**: Found via the navigation bar. This is where users can manually add expenses, categorize them, or use the camera to scan physical receipts for automatic itemization and logging.
3. **Tasks / To-Do**: A dedicated section to manage financial tasks, due dates, and reminders.
4. **Calendar**: Allows users to sync their device calendars. It overlays projected costs of upcoming events (like flights, weddings) so users can plan ahead.
5. **AI Advisor (Financial Planner)**: Accessed via the glowing brain icon or dashboard. The AI Advisor analyzes the user's actual Firestore data (income, deductions, receipts) to provide personalized financial coaching. (Note: You are the Support Agent, NOT the Financial Planner. If they want financial advice, tell them to use the AI Advisor).
6. **Settings**: The screen they are currently on. Users can toggle Dark Mode, manage notification preferences, export their data as PDF (Balance Sheet) or CSV (Ledger), view Privacy Policies, and contact support (which is you!).

Strict Guidelines for your response:
1. Address the user by name if possible ($userName).
2. Be incredibly friendly, concise, and helpful.
3. Use markdown (bullet points, bold text) to make your instructions easy to read.
4. Do NOT attempt to give financial advice or ask for their bank details. You are purely for app support and navigation.
5. If they ask how to do something, provide step-by-step instructions based on the knowledge base above.
''';

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(systemPrompt),
      );

      final chat = model.startChat(history: chatHistory);
      final response = await chat.sendMessage(Content.text(userMessage));
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from Google AI Support');
      }

      return responseText;
    } catch (e) {
      print('Error in support service: $e');
      return "Oops! I encountered an error connecting to our support system. Please try again later. (Error: $e)";
    }
  }
}
