const knex = require('knex');
const { logger } = require('../utils/logger');

const config = {
  development: {
    client: 'postgresql',
    connection: {
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || 5432,
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'password',
      database: process.env.DB_NAME || 'ascend_dev',
    },
    pool: {
      min: 2,
      max: 10,
    },
    migrations: {
      directory: '../migrations',
      tableName: 'knex_migrations',
    },
    seeds: {
      directory: '../seeds',
    },
    debug: process.env.NODE_ENV === 'development',
  },
  test: {
    client: 'postgresql',
    connection: {
      host: process.env.TEST_DB_HOST || 'localhost',
      port: process.env.TEST_DB_PORT || 5432,
      user: process.env.TEST_DB_USER || 'postgres',
      password: process.env.TEST_DB_PASSWORD || 'password',
      database: process.env.TEST_DB_NAME || 'ascend_test',
    },
    pool: {
      min: 1,
      max: 5,
    },
    migrations: {
      directory: '../migrations',
      tableName: 'knex_migrations',
    },
    seeds: {
      directory: '../seeds',
    },
  },
  production: {
    client: 'postgresql',
    connection: {
      host: process.env.DB_HOST,
      port: process.env.DB_PORT || 5432,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      ssl: { rejectUnauthorized: false },
    },
    pool: {
      min: 2,
      max: 20,
    },
    migrations: {
      directory: '../migrations',
      tableName: 'knex_migrations',
    },
    seeds: {
      directory: '../seeds',
    },
  },
};

const environment = process.env.NODE_ENV || 'development';
const dbConfig = config[environment];

const db = knex(dbConfig);

// Test database connection
db.raw('SELECT 1')
  .then(() => {
    logger.info(`✅ Database connected successfully (${environment})`);
  })
  .catch((error) => {
    logger.error('❌ Database connection failed:', error);
    process.exit(1);
  });

module.exports = db;
