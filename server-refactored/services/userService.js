const Database = require('../config/database');
const jwt = require('jsonwebtoken');
const { SECRET } = require('../middleware/auth');

class UserService {
  static async findByUsername(username) {
    return Database.readOne('users', u => u.username === username);
  }

  static async findById(id) {
    return Database.readOne('users', u => u.id === id);
  }

  static async validatePassword(user, password) {
    const bcrypt = require('bcryptjs');
    return user && bcrypt.compareSync(password, user.password);
  }

  static generateToken(user) {
    return jwt.sign(
      { id: user.id, username: user.username },
      SECRET,
      { expiresIn: '7d' }
    );
  }

  static async updateLocationSharing(userId, enabled) {
    const users = await Database.read('users');
    const user = users.find(u => u.id === userId);
    if (user) {
      user.locationSharingEnabled = enabled;
      await Database.write('users', users);
    }
    return enabled;
  }

  static async getLocationSharing(userId) {
    const user = await this.findById(userId);
    return user?.locationSharingEnabled ?? false;
  }
}

module.exports = UserService;
