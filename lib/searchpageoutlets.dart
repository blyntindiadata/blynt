import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/models.dart/outlet_model.dart';
import 'package:startup/outlets/outlet_details.dart';


// Search Page
class Searchpageoutlets extends StatefulWidget {
  const Searchpageoutlets({super.key});

  @override
  State<Searchpageoutlets> createState() => _SearchPageoutletsState();
}

class _SearchPageoutletsState extends State<Searchpageoutlets> {
  final TextEditingController _queryController = TextEditingController();
  final String apiBaseUrl = 'https://blyntfinal-201410726574.asia-south1.run.app';

  bool _isLoading = false;
  List<Outlet> _results = [];
  Timer? _debounce;
  String? username;
  bool _usernameLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedUsername = prefs.getString('username');

    if (savedUsername == null || savedUsername == 'guest') {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (doc.exists && doc.data()!.containsKey('username')) {
            savedUsername = doc.get('username');
            if (savedUsername != null) {
              await prefs.setString('username', savedUsername);
            }
          }
        }
      } catch (_) {
        savedUsername = 'guest';
      }
    }

    setState(() {
      username = savedUsername ?? 'guest';
      _usernameLoaded = true;
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = query.trim();
      if (trimmed.isNotEmpty) {
        _submitSearch(trimmed);
      } else {
        setState(() => _results = []);
      }
    });
  }

  Future<void> _submitSearch(String query) async {
    if (username == null || username!.isEmpty || username == 'guest') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please login to use search.", style: GoogleFonts.poppins()),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$apiBaseUrl/search"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"query": query, "username": username}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final matches = data is List ? data : data['matches'] ?? [];

        setState(() {
          _results = matches.map<Outlet>((item) => Outlet.fromJson(item)).toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed with code: ${response.statusCode}", style: GoogleFonts.poppins()),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e", style: GoogleFonts.poppins()),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToOutletDetails(Outlet outlet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutletDetailsScreen(outlet: outlet),
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_usernameLoaded) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFFF7B42C),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                "Loading...",
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            'search outlets',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF7B42C).withOpacity(0.08),
                    const Color(0xFFFF8C00).withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF7B42C).withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF7B42C).withOpacity(0.06),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _queryController,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                ),
                cursorColor: const Color(0xFFF7B42C),
                decoration: InputDecoration(
                  hintText: 'search...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 16,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFF7B42C),
                    size: 24,
                  ),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: Colors.white54,
                          ),
                          onPressed: () {
                            _queryController.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null,
                  filled: false,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                ),
                onChanged: (value) {
                  setState(() {}); // Trigger rebuild for suffix icon
                  _onSearchChanged(value);
                },
              ),
            ),
          ),

          // Results Section
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFFF7B42C),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Searching...",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFF7B42C).withOpacity(0.1),
                                      const Color(0xFFFF8C00).withOpacity(0.05),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.search_off_rounded,
                                  size: 40,
                                  color: Color(0xFFF7B42C),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _queryController.text.isEmpty
                                    ? "Start typing to search"
                                    : "No results found",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _queryController.text.isEmpty
                                    ? "Enter outlet name or location"
                                    : "Try different keywords",
                                style: GoogleFonts.poppins(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final outlet = _results[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFF7B42C).withOpacity(0.06),
                                    const Color(0xFFFF8C00).withOpacity(0.02),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFF7B42C).withOpacity(0.15),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF7B42C).withOpacity(0.04),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFF7B42C),
                                        Color(0xFFFFD700),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF7B42C).withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.store_rounded,
                                    color: Colors.black,
                                    size: 22,
                                  ),
                                ),
                                title: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    outlet.name.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          color: Color(0xFFF7B42C),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            outlet.location,
                                            style: GoogleFonts.poppins(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (outlet.price.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.currency_rupee_rounded,
                                            color: Color(0xFFF7B42C),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            outlet.price,
                                            style: GoogleFonts.poppins(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7B42C).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Color(0xFFF7B42C),
                                    size: 14,
                                  ),
                                ),
                                onTap: () => _navigateToOutletDetails(outlet),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

