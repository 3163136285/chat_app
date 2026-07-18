import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';

/// 消息管理 Provider：负责消息列表、发送、接收、撤回
class MessageProvider extends ChangeNotifier {
  final List<Message> _messages = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;

  String? _getOtherUserId() {
    final current = AuthService.currentUser;
    if (current == null) return null;
    return current.id == 'user1' ? 'user2' : 'user1';
  }

  Future<void> loadMessages() async {
    final otherId = _getOtherUserId();
    if (otherId == null) return;
    _isLoading = true;
    notifyListeners();

    final msgs = await ApiService.getChatWith(otherId);
    _messages.clear();
    _messages.addAll(msgs);
    _isLoading = false;
    notifyListeners();
  }

  void sendMessage(String content, {String type = 'text', Map<String, dynamic>? attachment}) {
    final otherId = _getOtherUserId();
    final current = AuthService.currentUser;
    if (otherId == null || current == null) return;

    final tempMsg = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      senderId: current.id,
      senderName: current.username,
      receiverId: otherId,
      content: content,
      type: type,
      attachment: attachment,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      read: false,
    );
    _messages.add(tempMsg);
    notifyListeners();

    SocketService.sendMessage(otherId, content, type: type, attachment: attachment);
  }

  Future<bool> sendImage(String imageUrl) async {
    sendMessage('[图片]', type: 'image', attachment: {'url': imageUrl});
    return true;
  }

  void recallMessage(String messageId) {
    final msg = _messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => Message(id: '', senderId: '', senderName: '', receiverId: '', content: '', timestamp: 0),
    );
    if (msg.id.isNotEmpty) {
      msg.recalled = true;
      msg.content = '已撤回';
      msg.attachment = null;
      notifyListeners();
      SocketService.recallMessage(messageId);
    }
  }

  void setUploading(bool value) {
    _isUploading = value;
    notifyListeners();
  }

  void onNewMessageReceived(Message msg) {
    final otherId = _getOtherUserId();
    if (otherId == null) return;
    if (msg.senderId != otherId && msg.receiverId != otherId) return;

    final existingIndex = _messages.indexWhere((m) => m.id == msg.id);
    if (existingIndex >= 0) {
      _messages[existingIndex] = msg;
    } else {
      _messages.add(msg);
    }
    notifyListeners();
  }

  void onMessageRead(String messageId, int readAt) {
    final msg = _messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => Message(id: '', senderId: '', senderName: '', receiverId: '', content: '', timestamp: 0),
    );
    if (msg.id.isNotEmpty) {
      msg.read = true;
      msg.readAt = readAt;
      notifyListeners();
    }
  }

  void onMessageRecalled(String messageId) {
    final msg = _messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => Message(id: '', senderId: '', senderName: '', receiverId: '', content: '', timestamp: 0),
    );
    if (msg.id.isNotEmpty) {
      msg.recalled = true;
      msg.content = '已撤回';
      msg.attachment = null;
      notifyListeners();
    }
  }

  void clear() {
    _messages.clear();
    _isLoading = false;
    _isUploading = false;
    _error = null;
    notifyListeners();
  }
}
