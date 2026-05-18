import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spendwisesyncapp/services/calendar_service.dart';

class CalendarSyncScreen extends StatefulWidget {
  const CalendarSyncScreen({Key? key}) : super(key: key);

  @override
  State<CalendarSyncScreen> createState() => _CalendarSyncScreenState();
}

class _CalendarSyncScreenState extends State<CalendarSyncScreen> {
  final CalendarService _calendarService = CalendarService();
  bool _isSyncing = false;
  bool _isLoading = true;
  List<CalendarEvent> _events = [];

  // Theme Colors (Dark)
  static const Color _backgroundDark = Color(0xFF0f1115);
  static const Color _cardDark = Color(0xFF16181d);
  static const Color _cardSurfaceDark = Color(0xFF1e2128);
  static const Color _borderDark = Color(0xFF272a33);
  static const Color _textGreyDark = Color(0xFF94a3b8);
  static const Color _textLightDark = Color(0xFFd1d5db);

  // Theme Colors (Light)
  static const Color _backgroundLight = Color(0xFFf6f7f8);
  static const Color _cardLight = Colors.white;
  static const Color _cardSurfaceLight = Color(0xFFf1f5f9);
  static const Color _borderLight = Color(0xFFe2e8f0);
  static const Color _textGreyLight = Color(0xFF64748b);
  static const Color _textLightLight = Color(0xFF1e293b);

  static const Color primary = Color(0xFF00d4ff); // Neon Cyan
  static const Color secondary = Color(0xFF8b5cf6); // Purple
  static const Color warningGold = Color(0xFFf59e0b); // Orange/Gold
  static const Color successGreen = Color(0xFF10b981);

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final events = await _calendarService.getEvents(user.uid);
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurfaceColor = isDark ? _cardSurfaceDark : _cardSurfaceLight;
    final textLight = isDark ? _textLightDark : _textLightLight;

    setState(() => _isSyncing = true);

    // Breathtaking sync mock delay
    await Future.delayed(const Duration(milliseconds: 1800));

    try {
      await _calendarService.seedMockEvents(user.uid);
      final events = await _calendarService.getEvents(user.uid);
      setState(() {
        _events = events;
        _isSyncing = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: successGreen),
              const SizedBox(width: 12),
              Text(
                'Google Calendar Sync Successful!',
                style: TextStyle(fontWeight: FontWeight.bold, color: textLight),
              ),
            ],
          ),
          backgroundColor: cardSurfaceColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: successGreen, width: 1.5),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleClear() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurfaceColor = isDark ? _cardSurfaceDark : _cardSurfaceLight;
    final textLight = isDark ? _textLightDark : _textLightLight;

    try {
      await _calendarService.clearEvents(user.uid);
      setState(() {
        _events = [];
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calendar sync cleared.', style: TextStyle(color: textLight)),
          backgroundColor: cardSurfaceColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      // Handle error
    }
  }

  void _showAddEventDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _cardDark : _cardLight;
    final cardSurfaceColor = isDark ? _cardSurfaceDark : _cardSurfaceLight;
    final borderColor = isDark ? _borderDark : _borderLight;
    final textGrey = isDark ? _textGreyDark : _textGreyLight;
    final textLight = isDark ? _textLightDark : _textLightLight;

    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    double predictedCost = 0.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          titleController.addListener(() {
            final cost = _calendarService.predictCost(titleController.text);
            if (cost != predictedCost) {
              setDialogState(() {
                predictedCost = cost;
              });
            }
          });

          return AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: borderColor),
            ),
            title: Text(
              'Add Calendar Event',
              style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: textLight),
                    decoration: InputDecoration(
                      hintText: 'e.g., Friend\'s Wedding, Flight to Miami',
                      hintStyle: TextStyle(color: textGrey),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Date selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Event Date:', style: TextStyle(color: textLight)),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: isDark
                                      ? const ColorScheme.dark(
                                          primary: primary,
                                          onPrimary: Colors.black,
                                          surface: _cardDark,
                                          onSurface: Colors.white,
                                        )
                                      : const ColorScheme.light(
                                          primary: primary,
                                          onPrimary: Colors.black,
                                          surface: Colors.white,
                                          onSurface: Colors.black,
                                        ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            setDialogState(() {
                              selectedDate = date;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cardSurfaceColor,
                          foregroundColor: primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Predictive Cost Tag
                  if (predictedCost > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: warningGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: warningGold.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insights, color: warningGold, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '✨ Predicted Cost Impact: +\$${predictedCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: warningGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: textGrey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) return;
                  final newEvent = CalendarEvent(
                    id: '',
                    title: titleController.text.trim(),
                    date: selectedDate,
                    projectedCost: predictedCost,
                    isSimulated: true,
                  );
                  await _calendarService.saveEvent(user.uid, newEvent);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                  _loadEvents();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Save Event', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Standard Base weekend/week spending cap
    const double baseWeekendBudget = 100.00;

    // Calculate sum of events within the current week/weekend
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final currentWeekForecast = _calendarService.getWeeklyForecast(_events, weekStart);
    final totalRecommendedBudget = baseWeekendBudget + currentWeekForecast;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final backgroundColor = isDark ? _backgroundDark : _backgroundLight;
    final cardColor = isDark ? _cardDark : _cardLight;
    final cardSurfaceColor = isDark ? _cardSurfaceDark : _cardSurfaceLight;
    final borderColor = isDark ? _borderDark : _borderLight;
    final textGrey = isDark ? _textGreyDark : _textGreyLight;
    final textLight = isDark ? _textLightDark : _textLightLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textLight, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Smart Calendar Predictor',
          style: TextStyle(color: textLight, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Google Sync Header Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [secondary.withOpacity(0.15), warningGold.withOpacity(0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: warningGold.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.calendar_month, color: warningGold, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CALENDAR SYNC ACTIVE',
                                    style: TextStyle(
                                      color: textGrey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Predict Spend Events',
                                    style: TextStyle(
                                      color: textLight,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Scans Google Calendar descriptions for high-spending keywords to forecast changes in your weekly budget demand.',
                          style: TextStyle(color: textGrey, height: 1.4, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isSyncing ? null : _handleSync,
                                icon: _isSyncing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            color: Colors.black, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.sync, size: 18),
                                label: Text(
                                  _isSyncing ? 'Syncing...' : 'Sync Google Calendar',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            if (_events.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: _handleClear,
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                                  padding: const EdgeInsets.all(12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 2. Weekly Predictive Scale
                  if (_events.isNotEmpty) ...[
                    Text(
                      'PREDICTIVE BUDGET SCALING',
                      style: TextStyle(
                        color: textGrey.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Weekend Spend Predictor',
                                  style: TextStyle(
                                      color: textLight, fontWeight: FontWeight.bold, fontSize: 15)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: warningGold.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'SCALING OUT',
                                  style: TextStyle(
                                      color: warningGold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Breathtaking linear scale/progress visualizer
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Base Budget', style: TextStyle(color: textGrey, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text('\$${baseWeekendBudget.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          color: textLight,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(child: Divider(color: borderColor, thickness: 2)),
                                      const Icon(Icons.double_arrow_rounded, color: warningGold, size: 20),
                                      const Expanded(child: Divider(color: warningGold, thickness: 2)),
                                    ],
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Scaled Forecast',
                                      style: TextStyle(color: warningGold, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('\$${totalRecommendedBudget.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          color: warningGold,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(color: borderColor, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: textGrey, size: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Includes +\$${currentWeekForecast.toStringAsFixed(0)} forecasted spend for high-risk events matching this week.',
                                  style: TextStyle(color: textGrey, fontSize: 12, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // 3. Calendar Events List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CALENDAR LOGS',
                        style: TextStyle(
                          color: textGrey.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showAddEventDialog,
                        child: Row(
                          children: const [
                            Icon(Icons.add, color: primary, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'ADD EVENT',
                              style: TextStyle(
                                  color: primary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. Events Builder
                  if (_events.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 48,
                            color: textGrey.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No calendar events synced.',
                            style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sync Google Calendar above to populate mock data.',
                            style: TextStyle(color: textGrey, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        final hasSpend = event.projectedCost > 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: hasSpend ? warningGold.withOpacity(0.2) : borderColor,
                            ),
                            boxShadow: hasSpend
                                ? [
                                    BoxShadow(
                                      color: warningGold.withOpacity(0.03),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              // Date badge
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: hasSpend
                                      ? warningGold.withOpacity(0.1)
                                      : primary.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      DateFormat('dd').format(event.date),
                                      style: TextStyle(
                                        color: hasSpend ? warningGold : primary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM').format(event.date).toUpperCase(),
                                      style: TextStyle(
                                        color: hasSpend
                                            ? warningGold.withOpacity(0.8)
                                            : primary.withOpacity(0.8),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                      style: TextStyle(
                                        color: textLight,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      hasSpend
                                          ? 'High-Spend Predictor Match'
                                          : 'Standard Calendar Entry',
                                      style: TextStyle(
                                        color: hasSpend ? warningGold : textGrey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Cost tag
                              if (hasSpend)
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: warningGold.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: warningGold.withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    '+\$${event.projectedCost.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: warningGold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              else
                                Icon(Icons.check_circle_outline, color: textGrey, size: 18),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: textGrey, size: 18),
                                onPressed: () async {
                                  await _calendarService.deleteEvent(event.id);
                                  _loadEvents();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
