import 'dart:convert';
import 'package:attendzone_new/models/project_model.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Api.dart';

class GetEmail {
  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }
}

class ProjectApi {
  final String baseUrl = 'https://attendzone-backend.onrender.com/api/v1/chat';
  static final String devUrl = "http://192.168.137.1:5000";
  // Method to get chat messages for a given email (static)
static Future<List<Project_model>> getUserProjects(String email) async {
    final url = Uri.parse('$devUrl/api/v1/projects/my-projects');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Project_model.fromSimpleJson(e)).toList();
    }

    if (response.statusCode == 404) {
      return [];
    }

    throw Exception('Failed to fetch projects');
  }

  Future<List<Project_model>> getProjects() async {
    final url = Uri.parse('$devUrl/api/v1/chat/projects');
    final response = await http.get(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        //'Authorization': authToken!,
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      List<Project_model> projects = data
          .map((item) => Project_model.fromSimpleJson(item))
          .toList();
      return projects;
    } else if (response.statusCode == 404) {
      print('No chat messages found for this email');
      return [];
    } else {
      throw Exception('Failed to fetch chat messages: ${response.statusCode}');
    }
  }

  // Method to add a new chat message
  Future<void> addChatMessage(
    String projectName,
    String sender,
    String message,
  ) async {
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd').format(now);
    String formattedTime = DateFormat('HH:mm:ss').format(now);
    final url = Uri.parse('$devUrl/api/v1/chat/add');
    String? authToken = await Get().getToken();
    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': authToken!,
      },
      body: jsonEncode({
        'project_name': projectName,
        'sender': sender,
        'message': message,
        'date': formattedDate,
        'time': formattedTime,
      }),
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      print('Response: ${responseBody['message']}');
    } else {
      throw Exception('Failed to add chat message: ${response.statusCode}');
    }
  }

  // Method to add a new chat image
  Future<void> addChatImage(
    String projectName,
    String sender,
    String imageBase64,
  ) async {
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd').format(now);
    String formattedTime = DateFormat('HH:mm:ss').format(now);
    String? authToken = await Get().getToken();
    final url = Uri.parse('$baseUrl/add');
    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': authToken!,
      },
      body: jsonEncode({
        'project_name': projectName,
        'sender': sender,
        'message': 'image:$imageBase64',
        'date': formattedDate,
        'time': formattedTime,
      }),
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      print('Response: ${responseBody['message']}');
    } else {
      throw Exception('Failed to add chat message: ${response.statusCode}');
    }
  }

  // Private method to save messages to SharedPreferences (static)
  static Future<void> _saveMessagesToSharedPrefs(List<dynamic> messages) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('chatMessages', jsonEncode(messages));
  }

  // Method to get saved messages from SharedPreferences
  static Future<List<dynamic>?> getSavedMessages() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedMessagesJson = prefs.getString('chatMessages');

    if (savedMessagesJson != null) {
      return jsonDecode(savedMessagesJson);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getPreviousAnnouncements() async {
    try {
      String? authToken = await Get().getToken();
      final apiUrl = '$devUrl/api/v1/announcements';
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': authToken!,
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map(
              (item) => {
                'message': item['message'],
                'date': item['date'],
                'time': item['time'],
              },
            )
            .toList();
      } else {
        throw Exception('Failed to load previous announcements');
      }
    } catch (e) {
      throw Exception('Error fetching previous announcements: $e');
    }
  }
}
