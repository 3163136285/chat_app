import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// 用户管理 Provider：管理当前用户和对方用户信息
class UserProvider extends ChangeNotifier {
  User? _currentUser;
  User? _otherUser;

  User? get currentUser => _currentUser;
  User? get otherUser => _otherUser;

  String? get otherUserId {
    if (_currentUser == null) return null;
    return _currentUser!.id == 'user1' ? 'user2' : 'user1';
  }

  Future<void> init() async {
    _currentUser = AuthService.currentUser;
    if (_currentUser == null) return;

    _otherUser = User(
      id: _currentUser!.id == 'user1' ? 'user2' : 'user1',
      username: _currentUser!.username == 'A' ? 'B' : 'A',
      displayName: _currentUser!.username == 'A' ? 'B' : 'A',
      avatar: '',
    );
    notifyListeners();
  }

  void clear() {
    _currentUser = null;
    _otherUser = null;
    notifyListeners();
  }
}
