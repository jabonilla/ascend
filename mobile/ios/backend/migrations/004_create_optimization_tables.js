/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.schema
    .createTable('optimization_strategies', function(table) {
      // Primary key
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      
      // Foreign key to users
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
      
      // Strategy information
      table.string('strategy').notNullable(); // avalanche, snowball, hybrid, custom
      table.decimal('monthly_payment', 15, 2).notNullable();
      table.decimal('total_debt', 15, 2).notNullable();
      table.decimal('total_minimum_payments', 15, 2).notNullable();
      table.jsonb('preferences');
      table.jsonb('recommendations').notNullable();
      table.jsonb('projections');
      table.jsonb('insights');
      
      // Timestamps
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('user_id');
      table.index('strategy');
      table.index('created_at');
    })
    .createTable('saved_scenarios', function(table) {
      // Primary key
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      
      // Foreign key to users
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
      
      // Scenario information
      table.string('name').notNullable();
      table.text('description');
      table.jsonb('scenario_data').notNullable(); // Complete scenario configuration
      table.boolean('is_favorite').defaultTo(false);
      
      // Timestamps
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('user_id');
      table.index('is_favorite');
      table.index('created_at');
    })
    .createTable('debt_consolidation_options', function(table) {
      // Primary key
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      
      // Foreign key to users
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
      
      // Consolidation information
      table.string('lender_name').notNullable();
      table.decimal('loan_amount', 15, 2).notNullable();
      table.decimal('apr', 5, 2).notNullable();
      table.integer('term_months').notNullable();
      table.decimal('monthly_payment', 15, 2).notNullable();
      table.decimal('origination_fee', 15, 2).defaultTo(0);
      table.decimal('total_cost', 15, 2).notNullable();
      table.decimal('interest_savings', 15, 2).notNullable();
      table.jsonb('terms_and_conditions');
      table.string('application_url');
      table.boolean('is_recommended').defaultTo(false);
      
      // Timestamps
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('user_id');
      table.index('is_recommended');
      table.index('apr');
      table.index('created_at');
    });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema
    .dropTableIfExists('debt_consolidation_options')
    .dropTableIfExists('saved_scenarios')
    .dropTableIfExists('optimization_strategies');
};
