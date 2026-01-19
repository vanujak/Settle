import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class FriendService {
  String get baseUrl => '${Config.apiUrl}/friends';

  Future<List<dynamic>> getFriends(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to load friends');
    }
  }

  Future<void> addFriend(String token, String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/add'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'username': username}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to add friend');
    }
  }

  Future<void> removeFriend(String token, String friendId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/remove'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'friendId': friendId}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to remove friend');
    }
  }
}
