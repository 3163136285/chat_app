import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import '../models/message.dart';
import '../services/auth_service.dart';

/// 未读消息 Provider：管理未读计数和应用图标红点
class UnreadProvider extends ChangeNotifier {
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  String? _getOtherUserId() {
    final current = AuthService.currentUser;
    if (current == null) return null;
    return current.id == 'user1' ? 'user2' : 'user1';
  }

  void calculateFromMessages(List<Message> messages) {
    final otherId = _getOtherUserId();
    if (otherId == null) return;
    _unreadCount = messages.where((m) => m.senderId == otherId && !m.read).length;
    _updateBadge();
    notifyListeners();
  }

  void incrementIfFromOther(String senderId) {
    final otherId = _getOtherUserId();
    if (otherId != null && senderId == otherId) {
      _unreadCount++;
      _updateBadge();
      notifyListeners();
    }
  }

  void markAllRead() {
    if (_unreadCount > 0) {
      _unreadCount = 0;
      _updateBadge();
      notifyListeners();
    }
  }

  void _updateBadge() {
    if (_unreadCount > 0) {
      FlutterAppBadger.updateBadgeCount(_unreadCount);
    } else {
      FlutterAppBadger.removeBadge();
    }
  }

  void clear() {
    _unreadCount = 0;
    FlutterAppBadger.removeBadge();
    notifyListeners();
  }
}
