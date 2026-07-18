const fs = require('fs').promises;
const path = require('path');

const DATA_DIR = path.join(__dirname, '..');

class Database {
  static async read(fileName) {
    const filePath = path.join(DATA_DIR, `${fileName}.json`);
    try {
      const data = await fs.readFile(filePath, 'utf8');
      return JSON.parse(data);
    } catch (e) {
      return [];
    }
  }

  static async write(fileName, data) {
    const filePath = path.join(DATA_DIR, `${fileName}.json`);
    await fs.writeFile(filePath, JSON.stringify(data, null, 2));
  }

  static async readOne(fileName, predicate) {
    const items = await this.read(fileName);
    return items.find(predicate) || null;
  }

  static async insert(fileName, item) {
    const items = await this.read(fileName);
    items.push(item);
    await this.write(fileName, items);
    return item;
  }

  static async update(fileName, predicate, updater) {
    const items = await this.read(fileName);
    const index = items.findIndex(predicate);
    if (index >= 0) {
      items[index] = updater(items[index]);
      await this.write(fileName, items);
      return items[index];
    }
    return null;
  }
}

module.exports = Database;
