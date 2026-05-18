import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import 'package:spendwisesyncapp/services/ai_advisor_service.dart';

class FinancialAdvisorScreen extends StatefulWidget {
  const FinancialAdvisorScreen({Key? key}) : super(key: key);

  @override
  State<FinancialAdvisorScreen> createState() => _FinancialAdvisorScreenState();
}

class _FinancialAdvisorScreenState extends State<FinancialAdvisorScreen> {
  // App Theme Constants - Premium Dark Mode
  static const Color backgroundDark = Color(0xFF0f1115);
  static const Color cardDark = Color(0xFF1a1d24);
  static const Color cardSurface = Color(0xFF23262e);
  static const Color borderDark = Color(0xFF2d3542);
  static const Color textGreyDark = Color(0xFF94a3b8);
  static const Color textLightDark = Color(0xFFd1d5db);

  static const Color primary = Color(0xFF00d4ff); // Glowing Neon Cyan
  static const Color secondary = Color(0xFF8b5cf6); // Indigo Violet
  static const Color greenSuccess = Color(0xFF10b981);
  static const Color accentPink = Color(0xFFec4899);

  final List<Map<String, dynamic>> _messages = [];
  final List<gemini.Content> _chatHistory = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message from advisor
    _messages.add({
      'text': "Hello! I am your **SpendWise Advisor**. I have reviewed your budget plans, liquid cash flow, and recent receipt items from Firestore.\n\nAsk me anything! For example: *'Can I afford a \$100 dinner?'* or *'How is my daily spend progress looking?'*",
      'isUser': false,
      'timestamp': DateTime.now(),
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _inputController.clear();

    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _isTyping = true;
    });
    
    _scrollToBottom();

    try {
      // Call Gemini using the context service
      final responseText = await AiAdvisorService.getFinancialAdvice(text, _chatHistory);

      setState(() {
        _isTyping = false;
        _messages.add({
          'text': responseText,
          'isUser': false,
          'timestamp': DateTime.now(),
        });
        
        // Update Gemini chat history
        _chatHistory.add(gemini.Content('user', [gemini.TextPart(text)]));
        _chatHistory.add(gemini.Content('model', [gemini.TextPart(responseText)]));
      });
    } catch (e) {
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': "Sorry, I ran into an issue analyzing your request: $e",
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      });
    }

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : const Color(0xFFf6f7f8);
    final cardColor = isDark ? cardDark : Colors.white;
    final cardSurfaceColor = isDark ? cardSurface : const Color(0xFFf1f5f9);
    final borderColor = isDark ? borderDark : const Color(0xFFe2e8f0);
    final textGrey = isDark ? textGreyDark : const Color(0xFF64748b);
    final textLight = isDark ? textLightDark : const Color(0xFF0f172a);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [primary, secondary]),
              ),
              child: const CircleAvatar(
                backgroundColor: backgroundDark,
                radius: 18,
                child: Icon(Icons.psychology, color: primary, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SpendWise Advisor',
                  style: TextStyle(
                    color: textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'AI Wealth Co-pilot',
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primary),
            tooltip: 'Clear Chat',
            onPressed: () {
              setState(() {
                _messages.clear();
                _chatHistory.clear();
                _messages.add({
                  'text': "Chat history refreshed. I am ready to advise you based on your updated Firestore budget limits and itemized spending!",
                  'isUser': false,
                  'timestamp': DateTime.now(),
                });
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Divider lines
          Container(height: 1, color: borderColor),
          
          // Conversation messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                return _buildMessageBubble(
                  text: msg['text'] as String,
                  isUser: isUser,
                  cardColor: cardColor,
                  cardSurfaceColor: cardSurfaceColor,
                  borderColor: borderColor,
                  textLight: textLight,
                  textGrey: textGrey,
                );
              },
            ),
          ),

          // Suggestion Chips (only show when not typing)
          if (!_isTyping && _messages.length <= 2) _buildSuggestionChips(textGrey, borderColor, cardSurfaceColor),

          // Typing status indicator
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Advisor is analyzing your profile...',
                    style: TextStyle(color: textGrey, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          // Input Form Box
          _buildInputArea(cardColor, borderColor, textLight, textGrey, cardSurfaceColor),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isUser,
    required Color cardColor,
    required Color cardSurfaceColor,
    required Color borderColor,
    required Color textLight,
    required Color textGrey,
  }) {
    final bubbleBg = isUser ? primary.withOpacity(0.15) : cardSurfaceColor;
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textStyle = TextStyle(
      color: textLight,
      fontSize: 14.5,
      height: 1.4,
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
          border: Border.all(
            color: isUser ? primary.withOpacity(0.4) : borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            // Simple markdown formatter helper
            _parseMarkdownText(text, textStyle),
          ],
        ),
      ),
    );
  }

  Widget _parseMarkdownText(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final pattern = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*');
    int start = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: baseStyle));
      }
      
      if (match.group(1) != null) {
        // Bold text **word**
        spans.add(TextSpan(
          text: match.group(1),
          style: baseStyle.copyWith(fontWeight: FontWeight.bold, color: primary),
        ));
      } else if (match.group(2) != null) {
        // Italic text *word*
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      }
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildSuggestionChips(Color textGrey, Color borderColor, Color cardSurfaceColor) {
    final chips = [
      {'label': '📊 How is my budget looking?', 'prompt': 'Review my daily, weekly, and monthly budget limits and show me how much I have remaining.'},
      {'label': '🧾 Analyze grocery scans', 'prompt': 'Search my scanned receipt items and analyze my spending habits. Give me tips to optimize.'},
      {'label': '💸 Can I buy a \$150 item?', 'prompt': 'Looking at my net monthly available balance, pay rate, bank account, and fixed deductions, is it safe to purchase a \$150 luxury item?'},
      {'label': '💡 3 tips to save money', 'prompt': 'Provide me with 3 highly customized, actionable money saving suggestions based on my profile details.'},
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final chip = chips[index];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: ActionChip(
              backgroundColor: cardSurfaceColor,
              side: BorderSide(color: borderColor),
              label: Text(
                chip['label']!,
                style: const TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: () => _sendMessage(chip['prompt']!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(Color cardColor, Color borderColor, Color textLight, Color textGrey, Color cardSurfaceColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardSurfaceColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _inputController,
                style: TextStyle(color: textLight),
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'Type your financial question...',
                  hintStyle: TextStyle(color: textGrey, fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [primary, secondary]),
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _sendMessage(_inputController.text),
            ),
          ),
        ],
      ),
    );
  }
}
