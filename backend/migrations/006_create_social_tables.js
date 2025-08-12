/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.schema
    // Friends table
    .createTable('friends', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      table.uuid('user_id').references('id').inTable('users').onDelete('CASCADE');
      table.uuid('friend_id').references('id').inTable('users').onDelete('CASCADE');
      table.boolean('is_active').defaultTo(true);
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Ensure unique friendship pairs
      table.unique(['user_id', 'friend_id']);
      
      // Indexes
      table.index('user_id');
      table.index('friend_id');
      table.index('is_active');
    })
    
    // Friend requests table
    .createTable('friend_requests', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      table.uuid('from_user_id').references('id').inTable('users').onDelete('CASCADE');
      table.uuid('to_user_id').references('id').inTable('users').onDelete('CASCADE');
      table.string('status').defaultTo('pending'); // pending, accepted, rejected
      table.text('message');
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('from_user_id');
      table.index('to_user_id');
      table.index('status');
    })
    
    // Group goals table
    .createTable('group_goals', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      table.uuid('creator_id').references('id').inTable('users').onDelete('CASCADE');
      table.string('name').notNullable();
      table.text('description');
      table.decimal('target_amount', 15, 2).notNullable();
      table.decimal('current_amount', 15, 2).defaultTo(0);
      table.string('category').notNullable();
      table.string('image_url');
      table.string('product_url');
      table.decimal('round_up_amount', 10, 2).defaultTo(1.00);
      table.boolean('is_active').defaultTo(true);
      table.boolean('is_completed').defaultTo(false);
      table.timestamp('target_date');
      table.timestamp('completed_at');
      table.integer('max_participants').defaultTo(10);
      table.boolean('is_public').defaultTo(false);
      table.string('invite_code').unique();
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('creator_id');
      table.index('category');
      table.index('is_active');
      table.index('is_completed');
      table.index('invite_code');
    })
    
    // Group goal participants table
    .createTable('group_goal_participants', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      table.uuid('group_goal_id').references('id').inTable('group_goals').onDelete('CASCADE');
      table.uuid('user_id').references('id').inTable('users').onDelete('CASCADE');
      table.string('role').defaultTo('member'); // creator, admin, member
      table.decimal('contributed_amount', 15, 2).defaultTo(0);
      table.boolean('is_active').defaultTo(true);
      table.timestamp('joined_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Ensure unique participant per group
      table.unique(['group_goal_id', 'user_id']);
      
      // Indexes
      table.index('group_goal_id');
      table.index('user_id');
      table.index('role');
      table.index('is_active');
    })
    
    // Group goal contributions table
    .createTable('group_goal_contributions', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      table.uuid('group_goal_id').references('id').inTable('group_goals').onDelete('CASCADE');
      table.uuid('user_id').references('id').inTable('users').onDelete('CASCADE');
      table.decimal('amount', 15, 2).notNullable();
      table.string('type').notNullable(); // manual, round_up, gift
      table.text('message');
      table.boolean('is_anonymous').defaultTo(false);
      table.timestamp('created_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('group_goal_id');
      table.index('user_id');
      table.index('type');
      table.index('created_at');
    })
    
    // Social activity table
    .createTable('social_activities', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      table.uuid('user_id').references('id').inTable('users').onDelete('CASCADE');
      table.string('activity_type').notNullable(); // goal_created, goal_completed, contribution_made, friend_added, etc.
      table.jsonb('activity_data').defaultTo('{}');
      table.boolean('is_public').defaultTo(true);
      table.timestamp('created_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('user_id');
      table.index('activity_type');
      table.index('created_at');
      table.index('is_public');
    });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema
    .dropTable('social_activities')
    .dropTable('group_goal_contributions')
    .dropTable('group_goal_participants')
    .dropTable('group_goals')
    .dropTable('friend_requests')
    .dropTable('friends');
}; 