require('dotenv').config();
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function test() {
  try {
    const user = await prisma.user.findFirst();
    console.log('✅ DB Connected OK.');
    console.log('First user:', user ? user.email : 'No users yet');
  } catch (e) {
    console.error('❌ DB Error:', e.message);
  } finally {
    await prisma.$disconnect();
  }
}

test();
