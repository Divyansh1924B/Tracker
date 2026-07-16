import { server } from './app';
import { prisma } from './database/prisma';
import bcrypt from 'bcryptjs';

const PORT = 3001;
const BASE_URL = `http://localhost:${PORT}/api`;

async function runTests() {
  console.log('--- STARTING AUTHENTICATION & SESSION INTEGRATION TESTS ---');

  // 1. Reset database test accounts
  await prisma.user.deleteMany({
    where: {
      email: { in: ['test_admin@tracker.com', 'test_member@tracker.com'] },
    },
  });

  // Create a test admin
  const adminPasswordHash = await bcrypt.hash('admin123', 10);
  await prisma.user.create({
    data: {
      email: 'test_admin@tracker.com',
      passwordHash: adminPasswordHash,
      role: 'admin',
      name: 'Test Admin',
      phone: '1112223333',
    },
  });
  console.log('Created test admin: test_admin@tracker.com / admin123');

  // Start the server
  server.close();
  await new Promise<void>((resolve) => {
    server.listen(PORT, () => {
      console.log(`Test server listening on port ${PORT}`);
      resolve();
    });
  });

  try {
    // 2. Test Admin Login
    console.log('\nTesting Admin Login...');
    const loginRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'test_admin@tracker.com',
        password: 'admin123',
        deviceName: 'Admin Laptop',
      }),
    });

    if (!loginRes.ok) {
      throw new Error(`Admin login failed: ${await loginRes.text()}`);
    }

    const { token: adminToken, user: adminUser } = (await loginRes.json()) as any;
    console.log('Admin login successful. Token acquired.');
    if (adminUser.role !== 'admin') throw new Error('Role mismatch for Admin');

    // 3. Test Member Creation (by Admin)
    console.log('\nTesting Member Creation...');
    const createMemberRes = await fetch(`${BASE_URL}/members`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${adminToken}`,
      },
      body: JSON.stringify({
        email: 'test_member@tracker.com',
        password: 'memberpassword',
        name: 'Test Family Member',
        phone: '9998887777',
        deviceName: 'Member Phone A',
      }),
    });

    if (!createMemberRes.ok) {
      throw new Error(`Member creation failed: ${await createMemberRes.text()}`);
    }

    const createdMember = (await createMemberRes.json()) as any;
    console.log(`Created member account successfully. ID: ${createdMember.id}`);

    // 4. Test Duplicate Email Rejection
    console.log('\nTesting Duplicate Email Rejection...');
    const dupRes = await fetch(`${BASE_URL}/members`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${adminToken}`,
      },
      body: JSON.stringify({
        email: 'test_member@tracker.com',
        password: 'anotherpassword',
        name: 'Duplicate Member',
      }),
    });

    if (dupRes.ok) {
      throw new Error('Server accepted duplicate email! Test failed.');
    }
    console.log('Duplicate email correctly rejected with status:', dupRes.status);

    // 5. Test Member Login on Device A
    console.log('\nTesting Member Login (Device A)...');
    const loginARes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'test_member@tracker.com',
        password: 'memberpassword',
        deviceName: 'Member Phone A',
      }),
    });

    const { token: tokenA } = (await loginARes.json()) as any;
    console.log('Device A login successful.');

    // Verify Device A can access profile
    const profileARes = await fetch(`${BASE_URL}/auth/profile`, {
      headers: { 'Authorization': `Bearer ${tokenA}` },
    });
    if (!profileARes.ok) throw new Error('Device A profile access failed');
    console.log('Device A successfully fetched own profile.');

    // 6. Test Member Login on Device B (should invalidate Device A)
    console.log('\nTesting Member Login (Device B) - Enforcing Device Limits...');
    const loginBRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'test_member@tracker.com',
        password: 'memberpassword',
        deviceName: 'Member Phone B',
      }),
    });

    const { token: tokenB } = (await loginBRes.json()) as any;
    console.log('Device B login successful.');

    // Verify Device B can access profile
    const profileBRes = await fetch(`${BASE_URL}/auth/profile`, {
      headers: { 'Authorization': `Bearer ${tokenB}` },
    });
    if (!profileBRes.ok) throw new Error('Device B profile access failed');
    console.log('Device B successfully fetched profile.');

    // Verify Device A is now rejected (One account = One active device)
    console.log('\nVerifying Device A session has been invalidated...');
    const profileAInvalidRes = await fetch(`${BASE_URL}/auth/profile`, {
      headers: { 'Authorization': `Bearer ${tokenA}` },
    });

    if (profileAInvalidRes.status === 401) {
      const errBody = (await profileAInvalidRes.json()) as any;
      if (errBody.code === 'SESSION_INVALIDATED') {
        console.log('Device A session correctly invalidated with SESSION_INVALIDATED code.');
      } else {
        throw new Error(`Device A rejected but with wrong code: ${JSON.stringify(errBody)}`);
      }
    } else {
      throw new Error(`Device A was NOT invalidated! Status: ${profileAInvalidRes.status}`);
    }

    console.log('\n--- ALL INTEGRATION TESTS PASSED SUCCESSFULLY! ---');
  } catch (err) {
    console.error('\n--- TEST EXECUTION FAILED ---');
    console.error(err);
  } finally {
    // Cleanup
    await prisma.user.deleteMany({
      where: {
        email: { in: ['test_admin@tracker.com', 'test_member@tracker.com'] },
      },
    });
    server.close();
    await prisma.$disconnect();
  }
}

runTests();
