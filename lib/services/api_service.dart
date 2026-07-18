import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/message.dart';
import 'auth_service.dart';

class ApiService {
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${AuthService.token ?? ''}',
  };

  static Future<List<Message>> getMessages({int page = 1, int limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/messages?page=$page&limit=$limit'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['messages'] as List?) ?? [];
        return list.map((e) => Message.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Get messages error: $e');
      return [];
    }
  }

  static Future<List<Message>> getChatWith(String userId, {int page = 1, int limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/chat/$userId?page=$page&limit=$limit'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['messages'] as List?) ?? [];
        return list.map((e) => Message.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Get chat error: $e');
      return [];
    }
  }

  static Future<void> markRead(String messageId) async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/read'),
        headers: _headers,
        body: jsonEncode({'messageId': messageId}),
      );
    } catch (e) {
      print('Mark read error: $e');
    }
  }

  // 新增：上传文件到 OSS（后端中转）
  static Future<String?> uploadFile(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/upload'),
      );
      request.headers['Authorization'] = 'Bearer ${AuthService.token ?? ''}';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));

      final response = await request.send().timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        return data['url'] as String?;
      }
      return null;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  // 新增：搜索聊天记录
  static Future<List<Message>> searchMessages(String keyword) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/messages/search?q=${Uri.encodeComponent(keyword)}'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['messages'] as List?) ?? [];
        return list.map((e) => Message.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Search messages error: $e');
      return [];
    }
  }

  // 位置共享：切换开关
  static Future<bool> setLocationSharing(bool enabled) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/location-sharing'),
        headers: _headers,
        body: jsonEncode({'enabled': enabled}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['enabled'] ?? false;
      }
      return false;
    } catch (e) {
      print('Set location sharing error: $e');
      return false;
    }
  }

  // 位置共享：查询对方状态
  static Future<bool> getLocationSharing(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/location-sharing/$userId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['enabled'] ?? false;
      }
      return false;
    } catch (e) {
      print('Get location sharing error: $e');
      return false;
    }
  }

  // 位置共享：获取对方位置历史
  static Future<List<Map<String, dynamic>>> getLocationHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/location/$userId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['locations'] ?? []);
      }
      return [];
    } catch (e) {
      print('Get location history error: $e');
      return [];
    }
  }
}
