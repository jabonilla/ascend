/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.schema.createTable('goals', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('user_id').references('id').inTable('users').onDelete('CASCADE');
    table.string('name').notNullable();
    table.text('description');
    table.decimal('target_amount', 15, 2).notNullable();
    table.decimal('current_amount', 15, 2).defaultTo(0);
    table.string('category').notNullable(); // fashion, electronics, travel, entertainment, food, custom
    table.string('image_url');
    table.string('product_url');
    table.decimal('round_up_amount', 10, 2).defaultTo(1.00); // Default $1 round-up
    table.boolean('is_active').defaultTo(true);
    table.boolean('is_completed').defaultTo(false);
    table.boolean('auto_purchase_enabled').defaultTo(false);
    table.timestamp('target_date');
    table.timestamp('completed_at');
    table.timestamp('created_at').defaultTo(knex.fn.now());
    table.timestamp('updated_at').defaultTo(knex.fn.now());
    
    // Indexes
    table.index('user_id');
    table.index('category');
    table.index('is_active');
    table.index('is_completed');
    table.index('created_at');
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema.dropTable('goals');
}; 