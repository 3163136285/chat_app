const Database = require('../config/database');

class MessageService {
  static async getAll(page = 1, limit = 50) {
    const messages = await Database.read('messages');
    const start = (page - 1) * limit;
    return messages.slice(start, start + limit);
  }

  static async getChatBetween(userId, otherId, page = 1, limit = 50) {
    const messages = await Database.read('messages');
    const chat = messages.filter(
      m => (m.senderId === userId && m.receiverId === otherId) ||
           (m.senderId === otherId && m.receiverId === userId)
    );
    const start = (page - 1) * limit;
    return chat.slice(start, start + limit);
  }

  static async create(data) {
    const message = {
      id: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      ...data,
      timestamp: Date.now(),
      read: false,
    };
    await Database.insert('messages', message);
    return message;
  }

  static async markRead(messageId) {
    return Database.update(
      'messages',
      m => m.id === messageId,
      m => ({ ...m, read: true, readAt: Date.now() })
    );
  }

  static async recall(messageId) {
    return Database.update(
      'messages',
      m => m.id === messageId,
      m => ({ ...m, recalled: true, content: '已撤回', attachment: null })
    );
  }

  static async search(keyword) {
    const messages = await Database.read('messages');
    return messages.filter(m =>
      m.content.toLowerCase().includes(keyword.toLowerCase()) ||
      (m.attachment?.name && m.attachment.name.toLowerCase().includes(keyword.toLowerCase()))
    );
  }
}

module.exports = MessageService;
