import 'package:flutter/material.dart';
import '../services/socket_service.dart';

/// 打字状态 Provider：管理双方正在输入的状态
class TypingProvider extends ChangeNotifier {
  bool _isTyping = false;      // 对方是否正在输入
  bool _isSending = false;     // 自己是否正在输入（发送中）

  bool get isTyping => _isTyping;
  bool get isSending => _isSending;

  String? _otherUserId;

  void setOtherUserId(String? userId) {
    _otherUserId = userId;
  }

  void onTypingReceived(String fromUserId, bool isStop) {
    if (_otherUserId != null && fromUserId == _otherUserId) {
      _isTyping = !isStop;
      notifyListeners();
    }
  }

  void sendTyping(String toUserId) {
    SocketService.sendTyping(toUserId);
    _isSending = true;
    notifyListeners();
  }

  void sendStopTyping(String toUserId) {
    SocketService.sendStopTyping(toUserId);
    _isSending = false;
    notifyListeners();
  }

  void clear() {
    _isTyping = false;
    _isSending = false;
    notifyListeners();
  }
}
