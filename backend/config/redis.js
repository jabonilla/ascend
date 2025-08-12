const redis = require('redis');
const logger = require('../utils/logger');

// Redis client configuration
const redisConfig = {
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379,
  password: process.env.REDIS_PASSWORD || undefined,
  db: process.env.REDIS_DB || 0,
  retry_strategy: (options) => {
    if (options.error && options.error.code === 'ECONNREFUSED') {
      // End reconnecting on a specific error and flush all commands with a individual error
      logger.error('Redis server refused connection');
      return new Error('Redis server refused connection');
    }
    if (options.total_retry_time > 1000 * 60 * 60) {
      // End reconnecting after a specific timeout and flush all commands with a individual error
      logger.error('Redis retry time exhausted');
      return new Error('Retry time exhausted');
    }
    if (options.attempt > 10) {
      // End reconnecting with built in error
      logger.error('Redis max retry attempts reached');
      return undefined;
    }
    // Reconnect after
    return Math.min(options.attempt * 100, 3000);
  }
};

// Create Redis client
const client = redis.createClient(redisConfig);

// Connect to Redis
const connectRedis = async () => {
  return new Promise((resolve, reject) => {
    client.on('connect', () => {
      logger.info('Redis connected successfully');
      resolve(client);
    });

    client.on('error', (err) => {
      logger.error('Redis connection error:', err);
      reject(err);
    });

    client.on('ready', () => {
      logger.info('Redis client ready');
    });

    client.on('end', () => {
      logger.info('Redis connection ended');
    });

    client.connect().catch(reject);
  });
};

// Close Redis connection
const closeRedis = async () => {
  try {
    await client.quit();
    logger.info('Redis connection closed');
  } catch (error) {
    logger.error('Error closing Redis connection:', error);
  }
};

// Redis utility functions
const redisUtils = {
  // Set key with expiration
  async set(key, value, expireSeconds = null) {
    try {
      if (expireSeconds) {
        await client.setEx(key, expireSeconds, JSON.stringify(value));
      } else {
        await client.set(key, JSON.stringify(value));
      }
      return true;
    } catch (error) {
      logger.error('Redis SET error:', error);
      return false;
    }
  },

  // Get value by key
  async get(key) {
    try {
      const value = await client.get(key);
      return value ? JSON.parse(value) : null;
    } catch (error) {
      logger.error('Redis GET error:', error);
      return null;
    }
  },

  // Delete key
  async del(key) {
    try {
      await client.del(key);
      return true;
    } catch (error) {
      logger.error('Redis DEL error:', error);
      return false;
    }
  },

  // Check if key exists
  async exists(key) {
    try {
      const result = await client.exists(key);
      return result === 1;
    } catch (error) {
      logger.error('Redis EXISTS error:', error);
      return false;
    }
  },

  // Set key with expiration in seconds
  async setEx(key, seconds, value) {
    try {
      await client.setEx(key, seconds, JSON.stringify(value));
      return true;
    } catch (error) {
      logger.error('Redis SETEX error:', error);
      return false;
    }
  },

  // Increment counter
  async incr(key) {
    try {
      return await client.incr(key);
    } catch (error) {
      logger.error('Redis INCR error:', error);
      return null;
    }
  },

  // Add to set
  async sadd(key, ...members) {
    try {
      return await client.sAdd(key, members);
    } catch (error) {
      logger.error('Redis SADD error:', error);
      return 0;
    }
  },

  // Get set members
  async smembers(key) {
    try {
      return await client.sMembers(key);
    } catch (error) {
      logger.error('Redis SMEMBERS error:', error);
      return [];
    }
  }
};

module.exports = {
  client,
  connectRedis,
  closeRedis,
  redisUtils
}; 