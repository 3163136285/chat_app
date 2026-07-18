import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';
import '../screens/video_player_screen.dart';
import 'image_viewer.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 已撤回的消息显示为灰色居中
    if (widget.message.recalled) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.message.content,
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
        ),
      );
    }

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _buildContent(context),
            const SizedBox(height: 2),
            _buildStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final bgColor = widget.isMe ? const Color(0xFF95EC69) : Colors.white;

    switch (widget.message.type) {
      case 'image':
        final url = widget.message.attachment?['url'] as String?;
        if (url == null || url.isEmpty) {
          return _buildTextContainer('【图片】', bgColor);
        }
        return GestureDetector(
          onTap: () => _openImageViewer(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
              errorBuilder: (ctx, err, stack) => Container(
                width: 200,
                height: 200,
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
              ),
            ),
          ),
        );
      case 'video':
        final url = widget.message.attachment?['url'] as String?;
        if (url == null || url.isEmpty) {
          return _buildTextContainer('【视频】', bgColor);
        }
        return GestureDetector(
          onTap: () => _openVideoPlayer(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 200,
              height: 150,
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '视频',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case 'voice':
        return _buildVoiceContainer(bgColor);
      case 'file':
        final name = widget.message.attachment?['name'] as String? ?? '文件';
        final url = widget.message.attachment?['url'] as String?;
        return GestureDetector(
          onTap: () {
            if (url != null && url.isNotEmpty) {
              _openFile(url);
            }
          },
          child: _buildFileContainer(name, bgColor),
        );
      default:
        return _buildTextContainer(widget.message.content, bgColor);
    }
  }

  Widget _buildTextContainer(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, color: Color(0xFF181818)),
      ),
    );
  }

  Widget _buildVoiceContainer(Color bgColor) {
    final url = widget.message.attachment?['url'] as String?;
    final duration = widget.message.attachment?['duration'] as int? ?? 0;
    final seconds = duration ~/ 1000;

    return GestureDetector(
      onTap: () => _playVoice(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlaying ? Icons.volume_up : Icons.play_arrow,
              color: const Color(0xFF181818),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '${seconds}s',
              style: const TextStyle(fontSize: 14, color: Color(0xFF181818)),
            ),
            const SizedBox(width: 8),
            // 波形动画（简单模拟）
            Row(
              children: List.generate(4, (i) => Container(
                width: 3,
                height: 6 + (i % 2) * 6,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playVoice(String? url) async {
    if (url == null || url.isEmpty) return;
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(UrlSource(url));
      setState(() => _isPlaying = true);
      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() => _isPlaying = false);
      });
    }
  }

  Widget _buildFileContainer(String name, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, color: Color(0xFF07C160), size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              style: const TextStyle(fontSize: 14, color: Color(0xFF181818)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    if (!widget.isMe) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.message.read ? '已读' : '未读',
          style: TextStyle(fontSize: 10, color: widget.message.read ? const Color(0xFF07C160) : Colors.grey),
        ),
        const SizedBox(width: 4),
        Icon(
          widget.message.read ? Icons.done_all : Icons.done,
          size: 12,
          color: widget.message.read ? const Color(0xFF07C160) : Colors.grey,
        ),
      ],
    );
  }

  void _openImageViewer(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewer(imageUrl: url),
      ),
    );
  }

  void _openVideoPlayer(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoUrl: url),
      ),
    );
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
