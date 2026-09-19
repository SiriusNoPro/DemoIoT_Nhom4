import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService extends ChangeNotifier {
  // Override with --dart-define=API_BASE_URL=http://<LAN-IP>:8080/api/v1 on a real phone.
  final String baseUrl = const String.fromEnvironment(
    'API_BASE_URL', defaultValue: 'http://10.0.2.2:8080/api/v1');
  String? _token;
  String? _role;

  bool get isAuthenticated => _token != null;
  String? get role => _role;

  ApiService() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _role = prefs.getString('role');
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['accessToken'];
        _role = data['role'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('role', _role!);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return false;
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    notifyListeners();
  }

  Future<void> _handleUnauthorized(http.Response response) async {
    if (response.statusCode == 401 || response.statusCode == 403) {
      await logout();
    }
  }

  Future<Map<String, dynamic>?> getDevice(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/devices/$deviceId'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      await _handleUnauthorized(response);
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }

  Future<Map<String, dynamic>?> getLatestTelemetry(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/devices/$deviceId/telemetry/latest'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      await _handleUnauthorized(response);
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }

  Future<bool> sendCommand(String deviceId, String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/devices/$deviceId/commands'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'action': action}),
      );
      await _handleUnauthorized(response);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint(e.toString());
    }
    return false;
  }
}
