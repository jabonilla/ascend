/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.schema.createTable('round_ups', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('user_id').references('id').inTable('users').onDelete('CASCADE');
    table.uuid('transaction_id').references('id').inTable('transactions').onDelete('CASCADE');
    table.uuid('goal_id').references('id').inTable('goals').onDelete('CASCADE');
    table.decimal('original_amount', 15, 2).notNullable();
    table.decimal('round_up_amount', 10, 2).notNullable();
    table.decimal('total_amount', 15, 2).notNullable(); // original + round_up
    table.string('status').defaultTo('pending'); // pending, processed, failed
    table.timestamp('processed_at');
    table.jsonb('metadata').defaultTo('{}');
    table.timestamp('created_at').defaultTo(knex.fn.now());
    table.timestamp('updated_at').defaultTo(knex.fn.now());
    
    // Indexes
    table.index('user_id');
    table.index('transaction_id');
    table.index('goal_id');
    table.index('status');
    table.index('created_at');
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema.dropTable('round_ups');
}; 