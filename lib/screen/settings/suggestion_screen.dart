import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> suggestions = [];

  // Get user suggestions from Firebase Realtime Database or any other backend service
  Future<void> getSuggestions() async {
    // Replace with actual implementation to fetch suggestions from backend
    suggestions = ['Suggestion 1', 'Suggestion 2', 'Suggestion 3'];
  }

  @override
  void initState() {
    super.initState();
    getSuggestions().then((_) => setState(() {}));
  }

  final _textController = TextEditingController();

  Future<void> _submitSuggestions() async {
    if (_textController.text.isNotEmpty) {
      // Add new suggestion to backend service (e.g. Firebase Realtime Database)
      await getSuggestions(); // Refresh suggestions list
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Enter suggestion',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _submitSuggestions,
              child: Text('Submit Suggestion'),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(suggestions[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}