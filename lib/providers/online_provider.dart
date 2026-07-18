import 'package:flutter/material.dart';
import '../services/socket_service.dart';

/// 在线状态 Provider：管理对方在线/离线状态
class OnlineProvider extends ChangeNotifier {
  bool _otherOnline = false;
  String? _otherUserId;

  bool get otherOnline => _otherOnline;

  void setOtherUserId(String? userId) {
    _otherUserId = userId;
  }

  void onOnlineStatusChanged(String userId, bool online) {
    if (_otherUserId != null && userId == _otherUserId) {
      _otherOnline = online;
      notifyListeners();
    }
  }

  void clear() {
    _otherOnline = false;
    notifyListeners();
  }
}
