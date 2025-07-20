import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<List<String>> getRecommendations(String username) async {
    final url = Uri.parse('$baseUrl/recommend');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> recs = data['recommendations'];
      return recs.map((e) => e.toString()).toList();
    } else {
      throw Exception('Failed to load recommendations');
    }
  }
}
