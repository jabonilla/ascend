/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.schema.createTable('users', function(table) {
    // Primary key
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    
    // User information
    table.string('email').unique().notNullable();
    table.string('password').notNullable();
    table.string('first_name').notNullable();
    table.string('last_name').notNullable();
    table.string('phone');
    
    // Account status
    table.boolean('is_active').defaultTo(true);
    table.boolean('is_premium').defaultTo(false);
    table.enum('role', ['user', 'admin', 'moderator']).defaultTo('user');
    
    // Authentication
    table.string('refresh_token');
    table.string('reset_token');
    table.timestamp('reset_token_expiry');
    
    // Timestamps
    table.timestamp('last_login_at');
    table.timestamp('created_at').defaultTo(knex.fn.now());
    table.timestamp('updated_at').defaultTo(knex.fn.now());
    
    // Indexes
    table.index('email');
    table.index('is_active');
    table.index('is_premium');
    table.index('role');
    table.index('created_at');
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema.dropTableIfExists('users');
};
