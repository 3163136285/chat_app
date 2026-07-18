import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';

class LocationShareScreen extends StatefulWidget {
  const LocationShareScreen({super.key});

  @override
  State<LocationShareScreen> createState() => _LocationShareScreenState();
}

class _LocationShareScreenState extends State<LocationShareScreen> {
  final MapController _mapController = MapController();
  bool _mySharingEnabled = false;
  bool _otherSharingEnabled = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _myLocations = [];
  List<Map<String, dynamic>> _otherLocations = [];
  Map<String, dynamic>? _myLatest;
  Map<String, dynamic>? _otherLatest;
  StreamSubscription? _locationSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final userProvider = context.read<UserProvider>();
    final myId = AuthService.currentUser?.id ?? '';
    final otherId = userProvider.otherUser?.id ?? '';

    // 查询双方的位置共享状态
    final myEnabled = await ApiService.getLocationSharing(myId);
    final otherEnabled = await ApiService.getLocationSharing(otherId);

    setState(() {
      _mySharingEnabled = myEnabled;
      _otherSharingEnabled = otherEnabled;
    });

    // 加载位置数据
    await _loadLocations();

    // 监听实时位置更新
    _locationSub = SocketService.onLocationUpdate.listen((data) {
      if (data['userId'] == otherId) {
        setState(() {
          _otherLatest = data;
          _otherLocations.add(data);
        });
      }
    });

    setState(() => _isLoading = false);
  }

  Future<void> _loadLocations() async {
    final userProvider = context.read<UserProvider>();
    final myId = AuthService.currentUser?.id ?? '';
    final otherId = userProvider.otherUser?.id ?? '';

    if (_mySharingEnabled) {
      _myLocations = await ApiService.getLocationHistory(myId);
      if (_myLocations.isNotEmpty) _myLatest = _myLocations.last;
    }
    if (_otherSharingEnabled) {
      _otherLocations = await ApiService.getLocationHistory(otherId);
      if (_otherLocations.isNotEmpty) _otherLatest = _otherLocations.last;
    }
  }

  Future<void> _toggleSharing() async {
    final newValue = !_mySharingEnabled;
    final result = await ApiService.setLocationSharing(newValue);
    setState(() => _mySharingEnabled = result);
    if (result) {
      await _loadLocations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final otherName = userProvider.otherUser?.displayName ?? '对方';

    return Scaffold(
      appBar: AppBar(
        title: const Text('位置共享'),
        actions: [
          // 我的位置共享开关
          Row(
            children: [
              Text(
                _mySharingEnabled ? '共享中' : '已关闭',
                style: TextStyle(
                  fontSize: 14,
                  color: _mySharingEnabled ? const Color(0xFF07C160) : Colors.grey,
                ),
              ),
              Switch(
                value: _mySharingEnabled,
                onChanged: (_) => _toggleSharing(),
                activeColor: const Color(0xFF07C160),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildMap(otherName),
    );
  }

  Widget _buildMap(String otherName) {
    // 计算地图中心
    LatLng center = const LatLng(39.9, 116.4); // 默认北京
    final allPoints = <LatLng>[];

    for (final loc in _myLocations) {
      allPoints.add(LatLng(loc['lat'], loc['lng']));
    }
    for (final loc in _otherLocations) {
      allPoints.add(LatLng(loc['lat'], loc['lng']));
    }
    if (allPoints.isNotEmpty) {
      center = allPoints.first;
    }

    final markers = <Marker>[];
    final polylines = <Polyline>[];

    // 我的轨迹和标记
    if (_myLocations.isNotEmpty && _mySharingEnabled) {
      final myPoints = _myLocations.map((l) => LatLng(l['lat'], l['lng'])).toList();
      polylines.add(Polyline(
        points: myPoints,
        color: Colors.blue,
        strokeWidth: 3,
      ));
      // 我的最新位置标记
      if (_myLatest != null) {
        markers.add(_buildMarker(
          LatLng(_myLatest!['lat'], _myLatest!['lng']),
          Colors.blue,
          '我',
        ));
      }
      // 历史点标记
      for (final loc in _myLocations) {
        markers.add(_buildDotMarker(LatLng(loc['lat'], loc['lng']), Colors.blue));
      }
    }

    // 对方的轨迹和标记
    if (_otherLocations.isNotEmpty && _otherSharingEnabled) {
      final otherPoints = _otherLocations.map((l) => LatLng(l['lat'], l['lng'])).toList();
      polylines.add(Polyline(
        points: otherPoints,
        color: Colors.red,
        strokeWidth: 3,
      ));
      // 对方最新位置标记
      if (_otherLatest != null) {
        markers.add(_buildMarker(
          LatLng(_otherLatest!['lat'], _otherLatest!['lng']),
          Colors.red,
          otherName,
        ));
      }
      // 历史点标记
      for (final loc in _otherLocations) {
        markers.add(_buildDotMarker(LatLng(loc['lat'], loc['lng']), Colors.red));
      }
    }

    if (!_otherSharingEnabled && _otherLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 64, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 16),
            Text(
              '$otherName 未开启位置共享',
              style: const TextStyle(fontSize: 16, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 8),
            const Text(
              '开启后可以看到对方的实时位置和轨迹',
              style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
            ),
          ],
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
          subdomains: const ['1', '2', '3', '4'],
          userAgentPackageName: 'com.example.chat_app',
        ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Marker _buildMarker(LatLng point, Color color, String label) {
    return Marker(
      point: point,
      width: 80,
      height: 50,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 2),
          Icon(Icons.location_on, color: color, size: 28),
        ],
      ),
    );
  }

  Marker _buildDotMarker(LatLng point, Color color) {
    return Marker(
      point: point,
      width: 12,
      height: 12,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.7),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}
