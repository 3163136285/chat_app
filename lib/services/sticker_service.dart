import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class StickerService {
  static final List<String> _stickers = [];
  static bool _initialized = false;

  static List<String> get stickers => List.unmodifiable(_stickers);

  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('stickers') ?? [];
    _stickers.addAll(list);
    _initialized = true;
  }

  // 从相册添加表情包
  static Future<String?> addFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
    );
    if (image == null) return null;

    // 复制到应用沙盒目录
    final appDir = await getApplicationDocumentsDirectory();
    final stickersDir = Directory('${appDir.path}/stickers');
    if (!await stickersDir.exists()) {
      await stickersDir.create(recursive: true);
    }

    final ext = image.path.split('.').last;
    final fileName = 'sticker_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final destPath = '${stickersDir.path}/$fileName';

    await File(image.path).copy(destPath);

    _stickers.add(destPath);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('stickers', _stickers);

    return destPath;
  }

  // 删除表情包
  static Future<void> removeSticker(String path) async {
    _stickers.remove(path);
    try {
      await File(path).delete();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('stickers', _stickers);
  }
}
