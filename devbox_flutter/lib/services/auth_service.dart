import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const _keyToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyEmail = 'user_email';
  static const _keyRelayUrl = 'relay_url';
  static const _keyAppToken = 'app_token';
  static const _keyDeviceId = 'device_id';
  static const _keyDeviceHost = 'device_hostname';

  String? _token;
  String? _userId;
  String? _email;
  String _relayUrl = 'http://10.110.44.103:3000';
  String? _appToken;
  String? _deviceId;
  String? _deviceHostname;
  bool _ready = false;

  bool get isLoggedIn => _token != null;
  bool get hasDevice => _appToken != null && _deviceId != null;
  bool get ready => _ready;
  String? get token => _token;
  String? get userId => _userId;
  String? get email => _email;
  String get relayUrl => _relayUrl;
  String? get appToken => _appToken;
  String? get deviceId => _deviceId;
  String? get deviceHostname => _deviceHostname;

  /// Load saved state from SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken);
    _userId = prefs.getString(_keyUserId);
    _email = prefs.getString(_keyEmail);
    _relayUrl = prefs.getString(_keyRelayUrl) ?? 'http://10.110.44.103:3000';
    _appToken = prefs.getString(_keyAppToken);
    _deviceId = prefs.getString(_keyDeviceId);
    _deviceHostname = prefs.getString(_keyDeviceHost);
    _ready = true;
    notifyListeners();
  }

  Future<void> setRelayUrl(String url) async {
    _relayUrl = url.replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRelayUrl, _relayUrl);
    notifyListeners();
  }

  /// Register new user
  Future<String?> register(String email, String password, {String? name}) async {
    try {
      final resp = await http.post(
        Uri.parse('$_relayUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'name': name}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body);
      if (resp.statusCode == 201) {
        await _saveAuth(data['token'], data['userId'], email);
        return null; // success
      }
      return data['error'] ?? 'Registration failed';
    } catch (e) {
      return 'Connection failed: ${e.toString().split(':').last.trim()}';
    }
  }

  /// Login existing user
  Future<String?> login(String email, String password) async {
    try {
      final resp = await http.post(
        Uri.parse('$_relayUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        await _saveAuth(data['token'], data['userId'], email);
        // Check for existing devices
        await _loadDevices();
        return null; // success
      }
      return data['error'] ?? 'Login failed';
    } catch (e) {
      return 'Connection failed: ${e.toString().split(':').last.trim()}';
    }
  }

  /// Pair with a device using 6-digit code
  Future<String?> pairDevice(String code) async {
    try {
      final resp = await http.post(
        Uri.parse('$_relayUrl/api/pair'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'code': code, 'name': 'DevBox Mobile'}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        await _saveDevice(data['token'], data['deviceId'], data['hostname'] ?? '');
        return null; // success
      }
      return data['error'] ?? 'Pairing failed';
    } catch (e) {
      return 'Connection failed: ${e.toString().split(':').last.trim()}';
    }
  }

  /// Load user's devices from relay
  Future<void> _loadDevices() async {
    if (_token == null) return;
    try {
      final resp = await http.get(
        Uri.parse('$_relayUrl/api/auth/me'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final devices = data['devices'] as List? ?? [];
        if (devices.isNotEmpty) {
          final d = devices.first;
          await _saveDevice(d['app_token'], d['id'], d['hostname'] ?? '');
        }
      }
    } catch (_) {}
  }

  Future<void> _saveAuth(String token, String userId, String email) async {
    _token = token;
    _userId = userId;
    _email = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyEmail, email);
    notifyListeners();
  }

  Future<void> _saveDevice(String appToken, String deviceId, String hostname) async {
    _appToken = appToken;
    _deviceId = deviceId;
    _deviceHostname = hostname;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppToken, appToken);
    await prefs.setString(_keyDeviceId, deviceId);
    await prefs.setString(_keyDeviceHost, hostname);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _email = null;
    _appToken = null;
    _deviceId = null;
    _deviceHostname = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  Future<void> unpairDevice() async {
    _appToken = null;
    _deviceId = null;
    _deviceHostname = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAppToken);
    await prefs.remove(_keyDeviceId);
    await prefs.remove(_keyDeviceHost);
    notifyListeners();
  }
}
