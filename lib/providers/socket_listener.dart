import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import 'message_provider.dart';
import 'typing_provider.dart';
import 'online_provider.dart';
import 'unread_provider.dart';
import 'user_provider.dart';

/// Socket 事件统一监听器：将 Socket 事件分发给各 Provider
/// 在 app.dart 中初始化，登录成功后启动
class SocketListener {
  static bool _initialized = false;

  static void init({
    required MessageProvider messageProvider,
    required TypingProvider typingProvider,
    required OnlineProvider onlineProvider,
    required UnreadProvider unreadProvider,
    required UserProvider userProvider,
  }) {
    if (_initialized) return;
    _initialized = true;

    SocketService.onNewMessage.listen((msg) {
      messageProvider.onNewMessageReceived(msg);
      unreadProvider.incrementIfFromOther(msg.senderId);
      // 自动标记已读（如果正在聊天页面）
      if (msg.senderId == userProvider.otherUserId) {
        // 由页面层调用 markRead
      }
    });

    SocketService.onRead.listen((data) {
      final messageId = data['messageId'] as String?;
      final readAt = data['readAt'] as int?;
      if (messageId != null && readAt != null) {
        messageProvider.onMessageRead(messageId, readAt);
      }
    });

    SocketService.onTyping.listen((data) {
      final from = data['from'] as String?;
      final isStop = data['stop'] as bool? ?? false;
      if (from != null) {
        typingProvider.onTypingReceived(from, isStop);
      }
    });

    SocketService.onOnline.listen((data) {
      final userId = data['userId'] as String?;
      final online = data['online'] as bool? ?? false;
      if (userId != null) {
        onlineProvider.onOnlineStatusChanged(userId, online);
      }
    });

    SocketService.onRecall.listen((data) {
      final messageId = data['messageId'] as String?;
      if (messageId != null) {
        messageProvider.onMessageRecalled(messageId);
      }
    });
  }

  static void reset() {
    _initialized = false;
  }
}
