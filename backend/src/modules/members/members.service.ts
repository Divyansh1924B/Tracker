import bcrypt from 'bcryptjs';
import { MembersRepository } from './members.repository';
import { AuthRepository } from '../auth/auth.repository';

const membersRepository = new MembersRepository();
const authRepository = new AuthRepository();

export class MembersService {
  async getAllMembers() {
    return membersRepository.findAll();
  }

  async getMemberById(id: string) {
    const member = await membersRepository.findById(id);
    if (!member) {
      throw new Error('Member not found');
    }
    return member;
  }

  async createMember(data: {
    email: string;
    password?: string;
    name: string;
    phone?: string;
    deviceName?: string;
    photoUrl?: string;
  }) {
    if (!data.email || !data.name) {
      throw new Error('Email and name are required fields');
    }

    const existingUser = await authRepository.findByEmail(data.email);
    if (existingUser) {
      throw new Error('Email is already registered');
    }

    const defaultPassword = data.password || 'member123'; // Safe fallback default
    const passwordHash = await bcrypt.hash(defaultPassword, 10);

    return membersRepository.create({
      email: data.email,
      passwordHash,
      name: data.name,
      phone: data.phone,
      deviceName: data.deviceName,
      photoUrl: data.photoUrl,
    });
  }

  async updateMember(
    id: string,
    data: {
      name: string;
      phone?: string;
      deviceName?: string;
      photoUrl?: string;
      password?: string;
    },
  ) {
    if (!data.name || data.name.trim() === '') {
      throw new Error('Name is required');
    }

    let passwordHash: string | undefined;
    if (data.password && data.password.trim() !== '') {
      passwordHash = await bcrypt.hash(data.password, 10);
    }

    const updated = await membersRepository.update(id, {
      name: data.name,
      phone: data.phone,
      deviceName: data.deviceName,
      photoUrl: data.photoUrl,
      passwordHash,
    });

    if (!updated) {
      throw new Error('Member not found or failed to update');
    }

    return updated;
  }

  async deleteMember(id: string) {
    const deleted = await membersRepository.delete(id);
    if (!deleted) {
      throw new Error('Member not found or deletion failed');
    }
    return true;
  }
}
