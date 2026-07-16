import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { AuthRepository } from './auth.repository';
import { config } from '../../config';

const authRepository = new AuthRepository();

export class AuthService {
  async login(email: string, password: string, deviceName: string) {
    if (!email || !password) {
      throw new Error('Email and password are required');
    }

    const user = await authRepository.findByEmail(email);
    if (!user) {
      throw new Error('Invalid email or password');
    }

    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      throw new Error('Invalid email or password');
    }

    // Generate a fresh session ID
    const sessionId = uuidv4();
    await authRepository.updateSessionId(user.id, sessionId);

    // Create JWT
    const token = jwt.sign(
      { userId: user.id, sessionId },
      config.jwtSecret,
      { expiresIn: '30d' }, // Token valid for 30 days
    );

    // Update device name on login if provided
    if (deviceName) {
      await authRepository.updateProfile(user.id, {
        name: user.name,
        phone: user.phone || undefined,
        photoUrl: user.photo_url || undefined,
        deviceName: deviceName,
      });
    }

    return {
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        name: user.name,
        phone: user.phone,
        deviceName: deviceName || user.device_name,
        photoUrl: user.photo_url,
      },
    };
  }

  async logout(userId: string) {
    await authRepository.updateSessionId(userId, null);
  }

  async getProfile(userId: string) {
    const user = await authRepository.findById(userId);
    if (!user) {
      throw new Error('User not found');
    }
    return user;
  }

  async updateProfile(
    userId: string,
    data: { name: string; phone?: string; deviceName?: string; photoUrl?: string },
  ) {
    if (!data.name || data.name.trim() === '') {
      throw new Error('Name is required');
    }
    return authRepository.updateProfile(userId, data);
  }

  async register(data: {
    name: string;
    email: string;
    phone?: string;
    password: string;
    deviceName?: string;
    adminPassword?: string;
  }) {
    if (!data.name || !data.email || !data.password || !data.adminPassword) {
      throw new Error('Name, email, password, and admin password are required');
    }

    // 1. Find the admin user to verify their password
    const admin = await authRepository.findAdmin();
    if (!admin) {
      throw new Error('No admin user exists in the system');
    }

    const isAdminMatch = await bcrypt.compare(data.adminPassword, admin.password_hash);
    if (!isAdminMatch) {
      throw new Error('Invalid admin password');
    }

    // 2. Check if email is already taken
    const existingUser = await authRepository.findByEmail(data.email);
    if (existingUser) {
      throw new Error('Email is already registered');
    }

    // 3. Hash the new member password
    const passwordHash = await bcrypt.hash(data.password, 10);

    // 4. Create the member account
    const user = await authRepository.createUser({
      email: data.email,
      passwordHash,
      role: 'member',
      name: data.name,
      phone: data.phone,
      deviceName: data.deviceName,
    });

    // 5. Create a session for them directly
    const sessionId = uuidv4();
    await authRepository.updateSessionId(user.id, sessionId);

    // Create JWT
    const token = jwt.sign(
      { userId: user.id, sessionId },
      config.jwtSecret,
      { expiresIn: '30d' },
    );

    return {
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        name: user.name,
        phone: user.phone,
        deviceName: user.device_name,
        photoUrl: user.photo_url,
      },
    };
  }
}
export { uuidv4 }; // Export uuid generator
