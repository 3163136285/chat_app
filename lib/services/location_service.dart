import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'socket_service.dart';

class LocationService {
  static Timer? _timer;
  static bool _isSharing = false;

  static bool get isSharing => _isSharing;

  // 开始位置共享（每10分钟上传一次）
  static Future<void> startSharing() async {
    if (_isSharing) return;

    // 请求权限
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _isSharing = true;

    // 立即上传一次
    await _uploadLocation();

    // 每10分钟上传一次
    _timer = Timer.periodic(const Duration(minutes: 10), (_) async {
      await _uploadLocation();
    });
  }

  // 停止位置共享
  static void stopSharing() {
    _timer?.cancel();
    _timer = null;
    _isSharing = false;
  }

  // 获取当前位置并上传
  static Future<void> _uploadLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 通过 Socket 实时推送
      SocketService.emitLocationUpdate({
        'lat': position.latitude,
        'lng': position.longitude,
      });

      // 同时通过 HTTP 备份
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthService.token ?? ''}',
        },
        body: jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
        }),
      );
    } catch (e) {
      print('Location upload error: $e');
    }
  }

  // 获取某用户的位置历史
  static Future<List<Map<String, dynamic>>> getLocationHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/location/$userId'),
        headers: {'Authorization': 'Bearer ${AuthService.token ?? ''}'},
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
