/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.schema.createTable('transactions', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('user_id').references('id').inTable('users').onDelete('CASCADE');
    table.uuid('bank_account_id').references('id').inTable('bank_accounts').onDelete('CASCADE');
    table.string('plaid_transaction_id').unique().notNullable();
    table.string('merchant_name');
    table.string('merchant_id');
    table.decimal('amount', 15, 2).notNullable();
    table.string('currency').defaultTo('USD');
    table.string('category').notNullable();
    table.jsonb('category_id');
    table.string('payment_channel'); // online, in store, other
    table.boolean('pending').defaultTo(false);
    table.string('account_owner');
    table.date('date').notNullable();
    table.timestamp('authorized_date');
    table.timestamp('created_at').defaultTo(knex.fn.now());
    table.timestamp('updated_at').defaultTo(knex.fn.now());
    
    // Indexes
    table.index('user_id');
    table.index('bank_account_id');
    table.index('plaid_transaction_id');
    table.index('merchant_name');
    table.index('category');
    table.index('date');
    table.index('pending');
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema.dropTable('transactions');
}; 