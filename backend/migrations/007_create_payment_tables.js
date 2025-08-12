/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.schema
    // Add Stripe customer ID to users table
    .alterTable('users', (table) => {
      table.string('stripe_customer_id').unique();
    })
    
    // Payment methods table
    .createTable('payment_methods', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      table.uuid('user_id').references('id').inTable('users').onDelete('CASCADE');
      table.string('stripe_payment_method_id').unique().notNullable();
      table.string('type').notNullable(); // card, bank_account, etc.
      table.string('last4');
      table.string('brand'); // visa, mastercard, etc.
      table.integer('exp_month');
      table.integer('exp_year');
      table.boolean('is_default').defaultTo(false);
      table.boolean('is_active').defaultTo(true);
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('user_id');
      table.index('stripe_payment_method_id');
      table.index('is_default');
      table.index('is_active');
    })
    
    // Purchases table
    .createTable('purchases', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      table.uuid('user_id').references('id').inTable('users').onDelete('CASCADE');
      table.uuid('goal_id').references('id').inTable('goals').onDelete('CASCADE');
      table.string('stripe_payment_intent_id').unique().notNullable();
      table.decimal('amount', 15, 2).notNullable();
      table.string('currency').defaultTo('USD');
      table.string('status').notNullable(); // pending, succeeded, failed, canceled
      table.text('description');
      table.jsonb('metadata').defaultTo('{}');
      table.timestamp('purchased_at');
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('user_id');
      table.index('goal_id');
      table.index('stripe_payment_intent_id');
      table.index('status');
      table.index('created_at');
    })
    
    // Add purchase tracking to goals table
    .alterTable('goals', (table) => {
      table.boolean('purchase_completed').defaultTo(false);
      table.timestamp('purchase_completed_at');
    });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema
    .alterTable('goals', (table) => {
      table.dropColumn('purchase_completed');
      table.dropColumn('purchase_completed_at');
    })
    .dropTable('purchases')
    .dropTable('payment_methods')
    .alterTable('users', (table) => {
      table.dropColumn('stripe_customer_id');
    });
}; 