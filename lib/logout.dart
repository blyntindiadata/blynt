import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:startup/main.dart';
import 'package:startup/phone_mail.dart';

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TextEditingController dayController = TextEditingController();
  final TextEditingController monthController = TextEditingController();
  final TextEditingController yearController = TextEditingController();

  List<String> recommendations = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    fetchRecommendations();
  }

  @override
  void dispose() {
    dayController.dispose();
    monthController.dispose();
    yearController.dispose();
    super.dispose();
  }

  void logout(BuildContext context) async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => AuthGate()),
      (route) => false,
    );
  }

  Future<void> fetchApiData() async {
    final url = Uri.parse('https://flask-api-1048825451382.asia-south1.run.app/api/data');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('API Data: $data');
      } else {
        print('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  Future<void> fetchRecommendations() async {
    setState(() {
      loading = true;
    });

    final url = Uri.parse('https://flask-api-1048825451382.asia-south1.run.app/recommend');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': 'yashdave18'}), // Replace with dynamic user if needed
      );
      print('Request sent for: yashdave18');
    print('Response body: ${response.body}');
    print('Status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          recommendations = List<String>.from(data['recommendations']);
          loading = false;
        });
      } else {
        print('Failed: ${response.statusCode}');
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        loading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text("Enter Date Manually"),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => logout(context),
              ),
            ],
          ),

          // Date Input
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Flexible(
                    child: TextField(
                      controller: dayController,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'DD',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: TextField(
                      controller: monthController,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'MM',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: TextField(
                      controller: yearController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'YYYY',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading or Error
          if (loading)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
            )

          // Recommendations List
          else if (recommendations.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.place),
                      title: Text(recommendations[index]),
                    ),
                  );
                },
                childCount: recommendations.length,
              ),
            )

          // Empty State
          else
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text("No recommendations found."),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
