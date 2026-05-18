import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEvent {
  final String id;
  final String title;
  final DateTime date;
  final double projectedCost;
  final bool isSimulated;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.projectedCost,
    this.isSimulated = true,
  });

  factory CalendarEvent.fromMap(Map<String, dynamic> map, String docId) {
    return CalendarEvent(
      id: docId,
      title: map['title'] ?? 'Event',
      date: (map['date'] as Timestamp).toDate(),
      projectedCost: (map['projectedCost'] ?? 0.0).toDouble(),
      isSimulated: map['isSimulated'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'projectedCost': projectedCost,
      'isSimulated': isSimulated,
    };
  }
}

class CalendarService {
  final CollectionReference _eventsRef =
      FirebaseFirestore.instance.collection('calendar_events');

  /// Detects high-spend keywords in the event title and predicts spending variance.
  double predictCost(String title) {
    final lowerTitle = title.toLowerCase();

    if (lowerTitle.contains('vacation') ||
        lowerTitle.contains('trip') ||
        lowerTitle.contains('holiday') ||
        lowerTitle.contains('travel') ||
        lowerTitle.contains('hawaii') ||
        lowerTitle.contains('paris') ||
        lowerTitle.contains('london') ||
        lowerTitle.contains('business trip')) {
      return 300.0;
    }
    if (lowerTitle.contains('flight') ||
        lowerTitle.contains('plane') ||
        lowerTitle.contains('ticket') ||
        lowerTitle.contains('airport') ||
        lowerTitle.contains('airline')) {
      return 200.0;
    }
    if (lowerTitle.contains('wedding') || lowerTitle.contains('marriage')) {
      return 150.0;
    }
    if (lowerTitle.contains('dentist') ||
        lowerTitle.contains('doctor') ||
        lowerTitle.contains('medical') ||
        lowerTitle.contains('clinic') ||
        lowerTitle.contains('hospital') ||
        lowerTitle.contains('physio')) {
      return 80.0;
    }
    if (lowerTitle.contains('concert') ||
        lowerTitle.contains('show') ||
        lowerTitle.contains('festival') ||
        lowerTitle.contains('gig')) {
      return 75.0;
    }
    if (lowerTitle.contains('gift') ||
        lowerTitle.contains('birthday') ||
        lowerTitle.contains('anniversary') ||
        lowerTitle.contains('party')) {
      return 60.0;
    }
    if (lowerTitle.contains('dinner') ||
        lowerTitle.contains('lunch') ||
        lowerTitle.contains('restaurant') ||
        lowerTitle.contains('mom') ||
        lowerTitle.contains('date night') ||
        lowerTitle.contains('brunch')) {
      return 50.0;
    }

    return 0.0;
  }

  /// Fetches all calendar events for the user.
  Future<List<CalendarEvent>> getEvents(String userId) async {
    final snapshot = await _eventsRef
        .where('userId', isEqualTo: userId)
        .orderBy('date')
        .get();

    return snapshot.docs
        .map((doc) => CalendarEvent.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  /// Stream of calendar events for real-time dashboard updates.
  Stream<List<CalendarEvent>> getEventsStream(String userId) {
    return _eventsRef
        .where('userId', isEqualTo: userId)
        .orderBy('date')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarEvent.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Adds or updates a calendar event in Firestore.
  Future<void> saveEvent(String userId, CalendarEvent event) async {
    final data = event.toMap();
    data['userId'] = userId;
    data['updatedAt'] = FieldValue.serverTimestamp();

    if (event.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _eventsRef.add(data);
    } else {
      await _eventsRef.doc(event.id).set(data, SetOptions(merge: true));
    }
  }

  /// Deletes a calendar event.
  Future<void> deleteEvent(String eventId) async {
    await _eventsRef.doc(eventId).delete();
  }

  /// Seeds standard mock high-spend events for first-time simulation testing.
  Future<void> seedMockEvents(String userId) async {
    // Check if events exist
    final snapshot = await _eventsRef.where('userId', isEqualTo: userId).limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    final now = DateTime.now();

    final List<CalendarEvent> mockEvents = [
      CalendarEvent(
        id: '',
        title: "Friend's Wedding Weekend",
        date: now.add(Duration(days: (5 - now.weekday + 7) % 7)), // Friday of this/next week
        projectedCost: 150.0,
      ),
      CalendarEvent(
        id: '',
        title: "Dentist Appointment",
        date: now.add(const Duration(days: 2)), // 2 days from now
        projectedCost: 80.0,
      ),
      CalendarEvent(
        id: '',
        title: "Business Trip Flights",
        date: now.add(const Duration(days: 8)), // 8 days from now
        projectedCost: 200.0,
      ),
      CalendarEvent(
        id: '',
        title: "Dinner with Mom",
        date: now.add(const Duration(days: 4)), // 4 days from now
        projectedCost: 50.0,
      ),
      CalendarEvent(
        id: '',
        title: "Summer Vacation Lodge",
        date: now.add(const Duration(days: 15)), // 15 days from now
        projectedCost: 300.0,
      ),
    ];

    for (var event in mockEvents) {
      await saveEvent(userId, event);
    }
  }

  /// Clears all simulated calendar events.
  Future<void> clearEvents(String userId) async {
    final snapshot = await _eventsRef.where('userId', isEqualTo: userId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Calculates total projected calendar spent for a given week.
  double getWeeklyForecast(List<CalendarEvent> events, DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    double sum = 0.0;
    for (var event in events) {
      if (event.date.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
          event.date.isBefore(weekEnd)) {
        sum += event.projectedCost;
      }
    }
    return sum;
  }
}
