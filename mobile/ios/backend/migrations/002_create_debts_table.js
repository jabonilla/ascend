/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.schema.createTable('debts', function(table) {
    // Primary key
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    
    // Foreign key to users
    table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    
    // Debt information
    table.string('name').notNullable();
    table.enum('type', ['creditCard', 'studentLoan', 'mortgage', 'autoLoan', 'personalLoan', 'medical', 'other']).notNullable();
    table.decimal('current_balance', 15, 2).notNullable();
    table.decimal('apr', 5, 2).notNullable();
    table.decimal('minimum_payment', 15, 2).defaultTo(0);
    table.date('due_date');
    table.string('creditor');
    table.string('account_number');
    
    // Status
    table.enum('status', ['active', 'paid', 'defaulted']).defaultTo('active');
    
    // Timestamps
    table.timestamp('created_at').defaultTo(knex.fn.now());
    table.timestamp('updated_at').defaultTo(knex.fn.now());
    
    // Indexes
    table.index('user_id');
    table.index('type');
    table.index('status');
    table.index('apr');
    table.index('created_at');
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema.dropTableIfExists('debts');
};
