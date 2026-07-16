import { prisma } from '../../database/prisma';

export class AuthRepository {
  async findByEmail(email: string) {
    const user = await prisma.user.findFirst({
      where: {
        email,
        deletedAt: null,
      },
    });
    if (!user) return null;
    return {
      ...user,
      password_hash: user.passwordHash,
      device_name: user.deviceName,
      photo_url: user.photoUrl,
      current_session_id: user.currentSessionId,
      created_at: user.createdAt,
      updated_at: user.updatedAt,
    };
  }

  async findById(id: string) {
    const user = await prisma.user.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    });
    if (!user) return null;
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      name: user.name,
      phone: user.phone,
      device_name: user.deviceName,
      photo_url: user.photoUrl,
      created_at: user.createdAt,
      updated_at: user.updatedAt,
    };
  }

  async updateSessionId(userId: string, sessionId: string | null) {
    await prisma.user.update({
      where: { id: userId },
      data: { currentSessionId: sessionId },
    });
  }

  async updateProfile(
    userId: string,
    data: { name: string; phone?: string; deviceName?: string; photoUrl?: string },
  ) {
    const user = await prisma.user.update({
      where: { id: userId },
      data: {
        name: data.name,
        phone: data.phone ?? null,
        deviceName: data.deviceName ?? null,
        photoUrl: data.photoUrl ?? null,
      },
    });
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      name: user.name,
      phone: user.phone,
      device_name: user.deviceName,
      photo_url: user.photoUrl,
    };
  }

  async findAdmin() {
    const user = await prisma.user.findFirst({
      where: {
        role: 'admin',
        deletedAt: null,
      },
    });
    if (!user) return null;
    return {
      ...user,
      password_hash: user.passwordHash,
      device_name: user.deviceName,
      photo_url: user.photoUrl,
      current_session_id: user.currentSessionId,
      created_at: user.createdAt,
      updated_at: user.updatedAt,
    };
  }

  async createUser(data: {
    email: string;
    passwordHash: string;
    role: 'member';
    name: string;
    phone?: string;
    deviceName?: string;
  }) {
    const user = await prisma.user.create({
      data: {
        email: data.email,
        passwordHash: data.passwordHash,
        role: data.role,
        name: data.name,
        phone: data.phone ?? null,
        deviceName: data.deviceName ?? null,
      },
    });
    return {
      ...user,
      password_hash: user.passwordHash,
      device_name: user.deviceName,
      photo_url: user.photoUrl,
      current_session_id: user.currentSessionId,
      created_at: user.createdAt,
      updated_at: user.updatedAt,
    };
  }
}
