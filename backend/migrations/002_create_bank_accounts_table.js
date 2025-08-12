/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.schema.createTable('bank_accounts', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('user_id').references('id').inTable('users').onDelete('CASCADE');
    table.string('plaid_account_id').notNullable();
    table.string('plaid_item_id').notNullable();
    table.string('institution_name').notNullable();
    table.string('account_name').notNullable();
    table.string('account_type').notNullable(); // checking, savings, credit
    table.string('account_subtype');
    table.string('mask').notNullable(); // Last 4 digits
    table.boolean('is_primary').defaultTo(false);
    table.boolean('is_active').defaultTo(true);
    table.decimal('current_balance', 15, 2).defaultTo(0);
    table.decimal('available_balance', 15, 2).defaultTo(0);
    table.jsonb('plaid_metadata').defaultTo('{}');
    table.timestamp('last_sync_at');
    table.timestamp('created_at').defaultTo(knex.fn.now());
    table.timestamp('updated_at').defaultTo(knex.fn.now());
    
    // Indexes
    table.index('user_id');
    table.index('plaid_account_id');
    table.index('plaid_item_id');
    table.index('is_primary');
    table.index('is_active');
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema.dropTable('bank_accounts');
}; 