/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.schema
    // Add notification preferences to users table
    .alterTable('users', (table) => {
      table.jsonb('notification_preferences').defaultTo('{}');
      table.string('push_token');
      table.boolean('push_notifications_enabled').defaultTo(true);
      table.boolean('email_notifications_enabled').defaultTo(true);
      table.boolean('sms_notifications_enabled').defaultTo(false);
    })
    
    // Notifications table
    .createTable('notifications', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      table.uuid('user_id').references('id').inTable('users').onDelete('CASCADE');
      table.string('type').notNullable(); // goal_completed, friend_request, round_up, etc.
      table.string('title').notNullable();
      table.text('message').notNullable();
      table.jsonb('data').defaultTo('{}'); // Additional data for the notification
      table.string('status').defaultTo('unread'); // unread, read, archived
      table.string('channel').notNullable(); // push, email, sms, in_app
      table.boolean('is_sent').defaultTo(false);
      table.timestamp('sent_at');
      table.timestamp('read_at');
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('user_id');
      table.index('type');
      table.index('status');
      table.index('channel');
      table.index('created_at');
    })
    
    // Notification templates table
    .createTable('notification_templates', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      table.string('type').unique().notNullable();
      table.string('name').notNullable();
      table.string('title_template').notNullable();
      table.text('message_template').notNullable();
      table.jsonb('variables').defaultTo('[]'); // Available variables for this template
      table.boolean('is_active').defaultTo(true);
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('type');
      table.index('is_active');
    })
    
    // Notification batches table (for bulk notifications)
    .createTable('notification_batches', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
      table.string('batch_type').notNullable(); // weekly_summary, goal_reminder, etc.
      table.jsonb('recipients').notNullable(); // Array of user IDs
      table.string('status').defaultTo('pending'); // pending, processing, completed, failed
      table.integer('total_count').defaultTo(0);
      table.integer('sent_count').defaultTo(0);
      table.integer('failed_count').defaultTo(0);
      table.timestamp('started_at');
      table.timestamp('completed_at');
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      
      // Indexes
      table.index('batch_type');
      table.index('status');
      table.index('created_at');
    });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema
    .dropTable('notification_batches')
    .dropTable('notification_templates')
    .dropTable('notifications')
    .alterTable('users', (table) => {
      table.dropColumn('notification_preferences');
      table.dropColumn('push_token');
      table.dropColumn('push_notifications_enabled');
      table.dropColumn('email_notifications_enabled');
      table.dropColumn('sms_notifications_enabled');
    });
}; 