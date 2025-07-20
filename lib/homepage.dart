import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RecommendationScreen extends StatefulWidget {
  final String userId; // e.g., 'usernumber'
  const RecommendationScreen({super.key, required this.userId});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String result = "";
  bool isLoading = false;
  String? username;

  @override
  void initState() {
    super.initState();
    fetchUsername(); // Load username on screen load
  }

  Future<void> fetchUsername() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    if (doc.exists && doc.data()?['username'] != null) {
      setState(() {
        username = doc.data()!['username'];
      });
    }
  }

  Future<void> storeToFirestore() async {
    final search = _searchController.text.trim();
    final location = _locationController.text.trim();

    if (username == null || search.isEmpty || location.isEmpty) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
    await userRef.update({
      "search_query": search,
      "user_location": location,
    });
  }

  Future<void> getRecommendations() async {
    if (username == null) return;

    setState(() => isLoading = true);

    final url = Uri.parse("https://flask-recommender-201410726574.asia-south1.run.app/recommend");

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );

    setState(() {
      isLoading = false;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        result = (data["recommendations"] ?? data["message"] ?? data["error"] ?? "Unknown").toString();
      } else {
        result = "Server error: ${response.statusCode}";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recommendation UI")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (username != null)
              Text("Welcome, $username", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
            else
              const CircularProgressIndicator(),

            TextField(controller: _searchController, decoration: const InputDecoration(labelText: "Search Query")),
            TextField(controller: _locationController, decoration: const InputDecoration(labelText: "User Location")),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await storeToFirestore();
                await getRecommendations();
              },
              child: const Text("Get Recommendations"),
            ),
            const SizedBox(height: 16),
            if (isLoading) const CircularProgressIndicator(),
            if (result.isNotEmpty) Text(result),
          ],
        ),
      ),
    );
  }
}
