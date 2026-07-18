import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../models/message.dart';
import '../providers/message_provider.dart';
import '../providers/online_provider.dart';
import '../providers/typing_provider.dart';
import '../providers/unread_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/webrtc_service.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import 'location_share_screen.dart';
import 'search_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _scrollCtrl = ScrollController();
  Timer? _typingTimer;
  final _audioRecorder = Record();
  bool _isRecording = false;
  String? _recordPath;
  DateTime? _recordStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UnreadProvider>().markAllRead();
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTyping() {
    final userProvider = context.read<UserProvider>();
    final typingProvider = context.read<TypingProvider>();
    final otherId = userProvider.otherUserId;
    if (otherId != null) {
      typingProvider.sendTyping(otherId);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (otherId != null) {
        typingProvider.sendStopTyping(otherId);
      }
    });
  }

  void _onSend(String text) {
    if (text.trim().isEmpty) return;
    final typingProvider = context.read<TypingProvider>();
    final otherId = context.read<UserProvider>().otherUserId;
    if (otherId != null) {
      typingProvider.sendStopTyping(otherId);
    }
    context.read<MessageProvider>().sendMessage(text.trim());
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _onPickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return;

    final msgProvider = context.read<MessageProvider>();
    msgProvider.setUploading(true);
    final url = await ApiService.uploadFile(image.path, image.name);
    msgProvider.setUploading(false);

    if (url != null) {
      msgProvider.sendMessage('[图片]', type: 'image', attachment: {'url': url});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片上传失败')),
      );
    }
  }

  Future<void> _onPickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    final msgProvider = context.read<MessageProvider>();
    msgProvider.setUploading(true);
    final url = await ApiService.uploadFile(video.path, video.name);
    msgProvider.setUploading(false);

    if (url != null) {
      msgProvider.sendMessage('[视频]', type: 'video', attachment: {'url': url});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('视频上传失败')),
      );
    }
  }

  Future<void> _onPickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    final msgProvider = context.read<MessageProvider>();
    msgProvider.setUploading(true);
    final url = await ApiService.uploadFile(file.path!, file.name);
    msgProvider.setUploading(false);

    if (url != null) {
      msgProvider.sendMessage('[文件]', type: 'file', attachment: {'url': url, 'name': file.name, 'size': file.size});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件上传失败')),
      );
    }
  }

  Future<void> _onPickSticker(String stickerPath) async {
    final msgProvider = context.read<MessageProvider>();
    msgProvider.setUploading(true);
    final fileName = stickerPath.split('/').last;
    final url = await ApiService.uploadFile(stickerPath, fileName);
    msgProvider.setUploading(false);

    if (url != null) {
      msgProvider.sendMessage('[表情包]', type: 'image', attachment: {'url': url});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('表情包发送失败')),
      );
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要麦克风权限')),
      );
      return;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _recordPath = '${appDir.path}/$fileName';
    _recordStartTime = DateTime.now();
    await _audioRecorder.start(path: _recordPath!, encoder: AudioEncoder.aacLc);
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (_recordPath == null || _recordStartTime == null) return;

    final duration = DateTime.now().difference(_recordStartTime!).inMilliseconds;
    if (duration < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('录音时间太短')),
      );
      return;
    }

    final msgProvider = context.read<MessageProvider>();
    msgProvider.setUploading(true);
    final fileName = _recordPath!.split('/').last;
    final url = await ApiService.uploadFile(_recordPath!, fileName);
    msgProvider.setUploading(false);

    if (url != null) {
      msgProvider.sendMessage('[语音]', type: 'voice', attachment: {'url': url, 'duration': duration});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音发送失败')),
      );
    }
  }

  void _showMessageMenu(Message msg) {
    final myId = AuthService.currentUser?.id;
    final canRecall = msg.canRecall(myId ?? '');

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canRecall)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('撤回', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _recallMessage(msg);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _recallMessage(Message msg) {
    context.read<MessageProvider>().recallMessage(msg.id);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final msgProvider = context.watch<MessageProvider>();
    final typingProvider = context.watch<TypingProvider>();
    final onlineProvider = context.watch<OnlineProvider>();

    final other = userProvider.otherUser;
    final messages = msgProvider.messages;
    final isTyping = typingProvider.isTyping;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(other?.displayName ?? '', style: const TextStyle(fontSize: 17)),
            if (onlineProvider.otherOnline)
              const Text('在线', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              final otherId = context.read<UserProvider>().otherUserId;
              if (otherId != null) {
                WebRTCService.startCall(otherId);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LocationShareScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
              ? const Center(child: Text('暂无消息', style: TextStyle(color: Color(0xFF888888))))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length + (isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (isTyping && index == messages.length) {
                      return _buildTypingIndicator();
                    }
                    final msg = messages[index];
                    final isMe = msg.senderId == AuthService.currentUser?.id;
                    return GestureDetector(
                      onLongPress: () => _showMessageMenu(msg),
                      child: MessageBubble(message: msg, isMe: isMe),
                    );
                  },
                ),
          ),
          ChatInput(
            onSend: _onSend,
            onTyping: _onTyping,
            onPickImage: _onPickImage,
            onPickVideo: _onPickVideo,
            onPickFile: _onPickFile,
            onPickSticker: _onPickSticker,
            onStartRecording: _startRecording,
            onStopRecording: _stopRecording,
            onLocationShare: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LocationShareScreen()),
              );
            },
            isUploading: msgProvider.isUploading,
            isRecording: _isRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFF888888).withOpacity(0.5 + (index * 0.2)),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
