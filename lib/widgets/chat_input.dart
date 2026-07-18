import 'package:flutter/material.dart';
import 'emoji_picker.dart';
import 'sticker_picker.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback onTyping;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onPickFile;
  final Function(String) onPickSticker;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onLocationShare;
  final bool isUploading;
  final bool isRecording;

  const ChatInput({
    super.key,
    required this.onSend,
    required this.onTyping,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onPickFile,
    required this.onPickSticker,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onLocationShare,
    this.isUploading = false,
    this.isRecording = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _ctrl = TextEditingController();
  bool _showVoiceHint = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 表情按钮
              IconButton(
                icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF888888)),
                onPressed: widget.isUploading || widget.isRecording ? null : _showEmojiAndStickerPicker,
              ),
              // + 按钮
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF07C160)),
                onPressed: widget.isUploading || widget.isRecording ? null : _showMediaPicker,
              ),
              // 输入框或语音提示
              Expanded(
                child: widget.isRecording
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE0E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic, color: Colors.red, size: 18),
                          SizedBox(width: 6),
                          Text('录音中...', style: TextStyle(color: Colors.red, fontSize: 14)),
                        ],
                      ),
                    )
                  : TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: widget.isUploading ? '上传中...' : '输入消息...',
                        filled: true,
                        fillColor: Colors.white,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (_) => widget.onTyping(),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (text) => _sendText(text),
                      enabled: !widget.isUploading,
                    ),
              ),
              // 麦克风按钮（长按录音）
              GestureDetector(
                onLongPress: widget.onStartRecording,
                onLongPressUp: widget.onStopRecording,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    widget.isRecording ? Icons.mic : Icons.mic_none,
                    color: widget.isRecording ? Colors.red : const Color(0xFF888888),
                    size: 24,
                  ),
                ),
              ),
              // 发送按钮
              IconButton(
                icon: widget.isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF07C160)),
                    )
                  : const Icon(Icons.send, color: Color(0xFF07C160)),
                onPressed: widget.isUploading || widget.isRecording ? null : () => _sendText(_ctrl.text),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Color(0xFF07C160)),
              title: const Text('图片'),
              onTap: () {
                Navigator.pop(context);
                widget.onPickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFF07C160)),
              title: const Text('视频'),
              onTap: () {
                Navigator.pop(context);
                widget.onPickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Color(0xFF07C160)),
              title: const Text('文件'),
              onTap: () {
                Navigator.pop(context);
                widget.onPickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xFF07C160)),
              title: const Text('位置共享'),
              onTap: () {
                Navigator.pop(context);
                widget.onLocationShare();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiAndStickerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DefaultTabController(
        length: 2,
        child: SizedBox(
          height: 320,
          child: Column(
            children: [
              Container(
                color: const Color(0xFFF7F7F7),
                child: const TabBar(
                  labelColor: Color(0xFF07C160),
                  unselectedLabelColor: Color(0xFF888888),
                  indicatorColor: Color(0xFF07C160),
                  tabs: [
                    Tab(text: '表情包'),
                    Tab(text: 'Emoji'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    StickerPicker(
                      onStickerSelected: (path) {
                        Navigator.pop(context);
                        widget.onPickSticker(path);
                      },
                    ),
                    EmojiPicker(
                      onEmojiSelected: (emoji) {
                        final text = _ctrl.text;
                        final selection = _ctrl.selection;
                        final newText = text.replaceRange(selection.start, selection.end, emoji);
                        _ctrl.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(offset: selection.start + emoji.length),
                        );
                        widget.onTyping();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    widget.onSend(trimmed);
    _ctrl.clear();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
