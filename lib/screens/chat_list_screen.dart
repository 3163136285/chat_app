import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../providers/message_provider.dart';
import '../providers/online_provider.dart';
import '../providers/socket_listener.dart';
import '../providers/typing_provider.dart';
import '../providers/unread_provider.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import 'chat_detail_screen.dart';
import 'login_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    SocketService.connect();
    final userProvider = context.read<UserProvider>();
    final msgProvider = context.read<MessageProvider>();
    final unreadProvider = context.read<UnreadProvider>();
    final typingProvider = context.read<TypingProvider>();
    final onlineProvider = context.read<OnlineProvider>();

    await userProvider.init();
    final otherId = userProvider.otherUserId;
    if (otherId != null) {
      typingProvider.setOtherUserId(otherId);
      onlineProvider.setOtherUserId(otherId);
    }
    await msgProvider.loadMessages();
    unreadProvider.calculateFromMessages(msgProvider.messages);

    SocketListener.init(
      messageProvider: msgProvider,
      typingProvider: typingProvider,
      onlineProvider: onlineProvider,
      unreadProvider: unreadProvider,
      userProvider: userProvider,
    );
  }

  @override
  void dispose() {
    SocketService.disconnect();
    super.dispose();
  }

  Future<void> _logout() async {
    context.read<MessageProvider>().clear();
    context.read<TypingProvider>().clear();
    context.read<OnlineProvider>().clear();
    context.read<UnreadProvider>().clear();
    context.read<UserProvider>().clear();
    SocketListener.reset();
    await AuthService.logout();
    SocketService.disconnect();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final msgProvider = context.watch<MessageProvider>();
    final onlineProvider = context.watch<OnlineProvider>();
    final unreadProvider = context.watch<UnreadProvider>();

    final other = userProvider.otherUser;
    final messages = msgProvider.messages;
    final lastMsg = messages.isNotEmpty ? messages.last : null;
    final unreadCount = unreadProvider.unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: _logout,
          ),
        ],
      ),
      body: other == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              _buildChatItem(other, lastMsg, onlineProvider.otherOnline, unreadCount),
            ],
          ),
    );
  }

  Widget _buildChatItem(user, Message? lastMsg, bool online, int unreadCount) {
    String preview = lastMsg?.content ?? '暂无消息';
    if (preview.length > 20) preview = '${preview.substring(0, 20)}...';

    String timeStr = '';
    if (lastMsg != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(lastMsg.timestamp);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else {
        timeStr = '${dt.month}/${dt.day}';
      }
    }

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChatDetailScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF07C160),
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName[0] : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (online && unreadCount == 0)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF07C160),
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF181818)),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(timeStr, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: TextStyle(
                      fontSize: 14,
                      color: unreadCount > 0 ? const Color(0xFF181818) : const Color(0xFF888888),
                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
