import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_model.dart';

String devUrl = 'http://192.168.137.1:5000';

class tasksApi {
  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  Future<List<Task_model>> fetchTasks() async {
    final prefs = await _getPrefs();
    final url = Uri.parse('$devUrl/api/v1/tasks/getTasks');
    String? email = prefs.getString('email');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email!}),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      // Assuming response is a list of tasks in MongoDB format
      return data.map((taskJson) {
        return Task_model.fromJson(taskJson);
      }).toList();
    } else {
      throw Exception('Failed to fetch tasks: ${response.body}');
    }
  }
}
