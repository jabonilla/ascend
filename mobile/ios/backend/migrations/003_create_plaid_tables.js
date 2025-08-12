/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.schema
    .createTable('plaid_items', function(table) {
      // Primary key
      table.string('id').primary(); // Plaid item ID
      
      // Foreign key to users
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
      
      // Plaid information
      table.string('access_token').notNullable();
      table.string('institution_id');
      table.string('webhook');
      table.jsonb('error');
      table.jsonb('available_products');
      table.jsonb('billed_products');
      
      // Timestamps
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('user_id');
      table.index('institution_id');
    })
    .createTable('plaid_accounts', function(table) {
      // Primary key
      table.string('id').primary(); // Plaid account ID
      
      // Foreign keys
      table.string('item_id').notNullable().references('id').inTable('plaid_items').onDelete('CASCADE');
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
      
      // Account information
      table.string('name').notNullable();
      table.string('mask');
      table.string('type').notNullable();
      table.string('subtype');
      table.string('institution_id');
      
      // Timestamps
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('item_id');
      table.index('user_id');
      table.index('type');
      table.index('institution_id');
    })
    .createTable('plaid_transactions', function(table) {
      // Primary key
      table.string('id').primary(); // Plaid transaction ID
      
      // Foreign keys
      table.string('account_id').notNullable().references('id').inTable('plaid_accounts').onDelete('CASCADE');
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
      
      // Transaction information
      table.decimal('amount', 15, 2).notNullable();
      table.date('date').notNullable();
      table.string('name').notNullable();
      table.string('merchant_name');
      table.jsonb('category');
      table.string('category_id');
      table.boolean('pending').defaultTo(false);
      table.string('payment_channel');
      table.string('transaction_type');
      
      // Timestamps
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('account_id');
      table.index('user_id');
      table.index('date');
      table.index('amount');
      table.index('pending');
      table.index('category_id');
    });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema
    .dropTableIfExists('plaid_transactions')
    .dropTableIfExists('plaid_accounts')
    .dropTableIfExists('plaid_items');
};
