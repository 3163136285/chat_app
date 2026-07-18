class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  String content; // 改为可变，支持撤回
  final String type; // text, image, video, file, voice
  Map<String, dynamic>? attachment; // 改为可变，支持撤回
  final int timestamp;
  bool read;
  int? readAt;
  bool recalled;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.content,
    this.type = 'text',
    this.attachment,
    required this.timestamp,
    this.read = false,
    this.readAt,
    this.recalled = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      receiverId: json['receiverId'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      attachment: json['attachment'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] ?? 0,
      read: json['read'] ?? false,
      readAt: json['readAt'],
      recalled: json['recalled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'content': content,
      'type': type,
      'attachment': attachment,
      'timestamp': timestamp,
      'read': read,
      'readAt': readAt,
      'recalled': recalled,
    };
  }

  // 是否可以撤回（2分钟内且自己发的）
  bool canRecall(String myUserId) {
    if (recalled) return false;
    if (senderId != myUserId) return false;
    return DateTime.now().millisecondsSinceEpoch - timestamp < 120000;
  }
}
