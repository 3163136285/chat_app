import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/message_bubble.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final List<Message> _results = [];
  bool _isLoading = false;
  String? _error;

  Future<void> _search() async {
    final keyword = _ctrl.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final msgs = await ApiService.searchMessages(keyword);
      setState(() {
        _results.clear();
        _results.addAll(msgs);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '搜索失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索聊天记录'),
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: '输入关键词搜索...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF07C160),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),
          // 结果列表
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_ctrl.text.trim().isEmpty) {
      return const Center(
        child: Text('输入关键词开始搜索', style: TextStyle(color: Color(0xFF888888))),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('未找到相关消息', style: TextStyle(color: Color(0xFF888888))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final msg = _results[index];
        final isMe = msg.senderId == AuthService.currentUser?.id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间戳
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                _formatTime(msg.timestamp),
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
            ),
            MessageBubble(message: msg, isMe: isMe),
          ],
        );
      },
    );
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
