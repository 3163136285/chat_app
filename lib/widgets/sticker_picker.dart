import 'dart:io';
import 'package:flutter/material.dart';
import '../services/sticker_service.dart';

class StickerPicker extends StatefulWidget {
  final Function(String) onStickerSelected;

  const StickerPicker({super.key, required this.onStickerSelected});

  @override
  State<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<StickerPicker> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await StickerService.init();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stickers = StickerService.stickers;

    return Container(
      height: 280,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '表情包',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF888888)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 添加表情包按钮
                    GestureDetector(
                      onTap: _addSticker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF07C160),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 16),
                            SizedBox(width: 2),
                            Text('添加', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, size: 20, color: Color(0xFF888888)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 表情包网格
          Expanded(
            child: stickers.isEmpty
              ? const Center(
                  child: Text(
                    '点击右上角"添加"导入表情包',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: stickers.length,
                  itemBuilder: (context, index) {
                    final path = stickers[index];
                    return GestureDetector(
                      onTap: () => widget.onStickerSelected(path),
                      onLongPress: () => _deleteSticker(path),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _addSticker() async {
    final path = await StickerService.addFromGallery();
    if (path != null) {
      setState(() {});
    }
  }

  Future<void> _deleteSticker(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除表情包'),
        content: const Text('确定要删除这个表情包吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await StickerService.removeSticker(path);
      setState(() {});
    }
  }
}
