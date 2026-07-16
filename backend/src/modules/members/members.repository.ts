import { prisma } from '../../database/prisma';

export class MembersRepository {
  async findAll() {
    const users = await prisma.user.findMany({
      where: {
        role: 'member',
        deletedAt: null,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
    return users.map(user => ({
      id: user.id,
      email: user.email,
      role: user.role,
      name: user.name,
      phone: user.phone,
      device_name: user.deviceName,
      photo_url: user.photoUrl,
      created_at: user.createdAt,
      updated_at: user.updatedAt,
    }));
  }

  async findById(id: string) {
    const user = await prisma.user.findFirst({
      where: {
        id,
        role: 'member',
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

  async create(data: {
    email: string;
    passwordHash: string;
    name: string;
    phone?: string;
    deviceName?: string;
    photoUrl?: string;
  }) {
    const user = await prisma.user.create({
      data: {
        email: data.email,
        passwordHash: data.passwordHash,
        role: 'member',
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
      created_at: user.createdAt,
    };
  }

  async update(
    id: string,
    data: {
      name: string;
      phone?: string;
      deviceName?: string;
      photoUrl?: string;
      passwordHash?: string;
    },
  ) {
    try {
      const user = await prisma.user.update({
        where: { id },
        data: {
          name: data.name,
          phone: data.phone ?? null,
          deviceName: data.deviceName ?? null,
          photoUrl: data.photoUrl ?? null,
          ...(data.passwordHash ? { passwordHash: data.passwordHash } : {}),
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
    } catch (_) {
      return null;
    }
  }

  async delete(id: string) {
    try {
      await prisma.user.update({
        where: { id },
        data: { deletedAt: new Date() },
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
