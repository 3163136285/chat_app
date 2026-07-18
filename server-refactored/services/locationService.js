const Database = require('../config/database');

class LocationService {
  static async getHistory(userId) {
    const locations = await Database.read('locations');
    return locations.filter(l => l.userId === userId);
  }

  static async record(userId, lat, lng) {
    const location = {
      id: `loc_${Date.now()}`,
      userId,
      lat,
      lng,
      timestamp: Date.now(),
    };
    await Database.insert('locations', location);
    return location;
  }
}

module.exports = LocationService;
