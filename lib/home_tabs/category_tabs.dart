import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:startup/helpers/users_utils.dart';

class CategoryTabContent extends StatefulWidget {
  final String category;
  const CategoryTabContent({required this.category, Key? key}) : super(key: key);

  @override
  State<CategoryTabContent> createState() => _CategoryTabContentState();
}

class _CategoryTabContentState extends State<CategoryTabContent> with AutomaticKeepAliveClientMixin {
  late Future<List<dynamic>> _futureData;
  String? _username;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUsernameAndFetch();
  }

  Future<void> _loadUsernameAndFetch() async {
    final storedUsername = await getOrFetchUsername();
    if (storedUsername != null && storedUsername.isNotEmpty) {
      setState(() {
        _username = storedUsername;
        _futureData = _loadDataWithCache();
      });
    } else {
      setState(() {
        _futureData = Future.error('Username not found. Please log in again.');
      });
    }
  }

  String get _cacheKey {
    final safeCategory = widget.category.toLowerCase().replaceAll(RegExp(r'[^\w]+'), '_');
    return 'category_${_username}_$safeCategory';
  }

  String normalizeCategory(String category) {
    return category
        .toLowerCase()
        .replaceAllMapped(RegExp(r'[^\u0000-\u007F]+'), (_) => '')
        .replaceAll(RegExp(r'[^\w]+'), ' ')
        .trim();
  }

  Future<List<dynamic>> _loadDataWithCache() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(_cacheKey)) {
      try {
        final cached = prefs.getString(_cacheKey)!;
        return json.decode(cached);
      } catch (_) {
        prefs.remove(_cacheKey);
      }
    }

    try {
      final response = await http.post(
        Uri.parse('https://blyntfinal-201410726574.asia-south1.run.app/search_category'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "query": normalizeCategory(widget.category),
          "username": _username,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final matches = jsonData["matches"] ?? [];
        prefs.setString(_cacheKey, json.encode(matches));
        return matches;
      } else {
        throw Exception("Failed to load data for ${widget.category}");
      }
    } catch (e) {
      throw Exception("Failed to fetch data for ${widget.category}");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<dynamic>>(
      future: _futureData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text("No results", style: TextStyle(color: Colors.white)),
          );
        }

        final results = snapshot.data!;
        return ListView.builder(
          itemCount: results.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final place = results[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D1C1A), Color(0xFF121212)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.amberAccent.withOpacity(0.8),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amberAccent.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedNetworkImage(
                      imageUrl: place["Image"] ?? "",
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(height: 200, color: Colors.grey[900]),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error, color: Colors.redAccent),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                place["Place_Available"] ?? "Unknown",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Poppins_Regular',
                                ),
                              ),
                            ),
                            const Icon(Icons.star, color: Colors.amberAccent, size: 18),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber.shade700,
                                    Colors.deepOrange.shade400,
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    place["Place_Location"]?.split(",").first ?? "Location",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins_Regular',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.amber,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                "starts from ₹${place["Price"] ?? "-"}",
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins_Regular',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
