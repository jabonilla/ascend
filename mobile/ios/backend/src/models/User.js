const db = require('../config/database');
const { logger } = require('../utils/logger');

class User {
    constructor(data) {
        this.id = data.id;
        this.email = data.email;
        this.password = data.password;
        this.firstName = data.firstName;
        this.lastName = data.lastName;
        this.phone = data.phone;
        this.isActive = data.isActive;
        this.isPremium = data.isPremium;
        this.role = data.role;
        this.refreshToken = data.refreshToken;
        this.resetToken = data.resetToken;
        this.resetTokenExpiry = data.resetTokenExpiry;
        this.lastLoginAt = data.lastLoginAt;
        this.createdAt = data.createdAt;
        this.updatedAt = data.updatedAt;
    }

    static async create(userData) {
        try {
            const [user] = await db('users')
                .insert({
                    id: userData.id,
                    email: userData.email,
                    password: userData.password,
                    first_name: userData.firstName,
                    last_name: userData.lastName,
                    phone: userData.phone,
                    is_active: userData.isActive,
                    is_premium: userData.isPremium,
                    role: userData.role,
                    created_at: userData.createdAt,
                    updated_at: userData.updatedAt
                })
                .returning('*');

            return new User({
                ...user,
                firstName: user.first_name,
                lastName: user.last_name,
                isActive: user.is_active,
                isPremium: user.is_premium,
                createdAt: user.created_at,
                updatedAt: user.updated_at
            });
        } catch (error) {
            logger.error('Error creating user:', error);
            throw error;
        }
    }

    static async findById(id) {
        try {
            const user = await db('users')
                .where('id', id)
                .first();

            if (!user) return null;

            return new User({
                ...user,
                firstName: user.first_name,
                lastName: user.last_name,
                isActive: user.is_active,
                isPremium: user.is_premium,
                createdAt: user.created_at,
                updatedAt: user.updated_at
            });
        } catch (error) {
            logger.error('Error finding user by ID:', error);
            throw error;
        }
    }

    static async findByEmail(email) {
        try {
            const user = await db('users')
                .where('email', email.toLowerCase())
                .first();

            if (!user) return null;

            return new User({
                ...user,
                firstName: user.first_name,
                lastName: user.last_name,
                isActive: user.is_active,
                isPremium: user.is_premium,
                createdAt: user.created_at,
                updatedAt: user.updated_at
            });
        } catch (error) {
            logger.error('Error finding user by email:', error);
            throw error;
        }
    }

    static async findByResetToken(token) {
        try {
            const user = await db('users')
                .where('reset_token', token)
                .first();

            if (!user) return null;

            return new User({
                ...user,
                firstName: user.first_name,
                lastName: user.last_name,
                isActive: user.is_active,
                isPremium: user.is_premium,
                createdAt: user.created_at,
                updatedAt: user.updated_at
            });
        } catch (error) {
            logger.error('Error finding user by reset token:', error);
            throw error;
        }
    }

    static async updateRefreshToken(userId, refreshToken) {
        try {
            await db('users')
                .where('id', userId)
                .update({
                    refresh_token: refreshToken,
                    updated_at: new Date()
                });
        } catch (error) {
            logger.error('Error updating refresh token:', error);
            throw error;
        }
    }

    static async updateResetToken(userId, resetToken, resetTokenExpiry) {
        try {
            await db('users')
                .where('id', userId)
                .update({
                    reset_token: resetToken,
                    reset_token_expiry: resetTokenExpiry,
                    updated_at: new Date()
                });
        } catch (error) {
            logger.error('Error updating reset token:', error);
            throw error;
        }
    }

    static async updatePassword(userId, hashedPassword) {
        try {
            await db('users')
                .where('id', userId)
                .update({
                    password: hashedPassword,
                    updated_at: new Date()
                });
        } catch (error) {
            logger.error('Error updating password:', error);
            throw error;
        }
    }

    static async updateLastLogin(userId) {
        try {
            await db('users')
                .where('id', userId)
                .update({
                    last_login_at: new Date(),
                    updated_at: new Date()
                });
        } catch (error) {
            logger.error('Error updating last login:', error);
            throw error;
        }
    }

    static async updateProfile(userId, profileData) {
        try {
            const updateData = {
                first_name: profileData.firstName,
                last_name: profileData.lastName,
                phone: profileData.phone,
                updated_at: new Date()
            };

            const [user] = await db('users')
                .where('id', userId)
                .update(updateData)
                .returning('*');

            return new User({
                ...user,
                firstName: user.first_name,
                lastName: user.last_name,
                isActive: user.is_active,
                isPremium: user.is_premium,
                createdAt: user.created_at,
                updatedAt: user.updated_at
            });
        } catch (error) {
            logger.error('Error updating user profile:', error);
            throw error;
        }
    }

    static async deleteById(userId) {
        try {
            await db('users')
                .where('id', userId)
                .del();
        } catch (error) {
            logger.error('Error deleting user:', error);
            throw error;
        }
    }

    static async listUsers(page = 1, limit = 10, filters = {}) {
        try {
            let query = db('users').select('*');

            // Apply filters
            if (filters.isActive !== undefined) {
                query = query.where('is_active', filters.isActive);
            }

            if (filters.isPremium !== undefined) {
                query = query.where('is_premium', filters.isPremium);
            }

            if (filters.role) {
                query = query.where('role', filters.role);
            }

            if (filters.search) {
                query = query.where(function() {
                    this.where('email', 'ilike', `%${filters.search}%`)
                        .orWhere('first_name', 'ilike', `%${filters.search}%`)
                        .orWhere('last_name', 'ilike', `%${filters.search}%`);
                });
            }

            // Apply pagination
            const offset = (page - 1) * limit;
            query = query.offset(offset).limit(limit);

            // Get total count
            const countQuery = db('users').count('* as total');
            const [{ total }] = await countQuery;

            const users = await query;

            return {
                users: users.map(user => new User({
                    ...user,
                    firstName: user.first_name,
                    lastName: user.last_name,
                    isActive: user.is_active,
                    isPremium: user.is_premium,
                    createdAt: user.created_at,
                    updatedAt: user.updated_at
                })),
                pagination: {
                    page,
                    limit,
                    total: parseInt(total),
                    totalPages: Math.ceil(total / limit)
                }
            };
        } catch (error) {
            logger.error('Error listing users:', error);
            throw error;
        }
    }

    static async getStats() {
        try {
            const stats = await db('users')
                .select(
                    db.raw('COUNT(*) as total_users'),
                    db.raw('COUNT(CASE WHEN is_active = true THEN 1 END) as active_users'),
                    db.raw('COUNT(CASE WHEN is_premium = true THEN 1 END) as premium_users'),
                    db.raw('COUNT(CASE WHEN created_at >= NOW() - INTERVAL \'30 days\' THEN 1 END) as new_users_30_days'),
                    db.raw('COUNT(CASE WHEN last_login_at >= NOW() - INTERVAL \'7 days\' THEN 1 END) as active_users_7_days')
                )
                .first();

            return stats;
        } catch (error) {
            logger.error('Error getting user stats:', error);
            throw error;
        }
    }

    toJSON() {
        return {
            id: this.id,
            email: this.email,
            firstName: this.firstName,
            lastName: this.lastName,
            phone: this.phone,
            isActive: this.isActive,
            isPremium: this.isPremium,
            role: this.role,
            lastLoginAt: this.lastLoginAt,
            createdAt: this.createdAt,
            updatedAt: this.updatedAt
        };
    }
}

module.exports = { User };
