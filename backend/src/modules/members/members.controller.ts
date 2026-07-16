import { Router } from 'express';
import { MembersService } from './members.service';
import { authMiddleware, AuthenticatedRequest } from '../../middleware/auth.middleware';

const router = Router();
const membersService = new MembersService();

// Admin Guard Middleware
const adminGuard = (req: AuthenticatedRequest, res: any, next: any) => {
  if (req.user && req.user.role === 'admin') {
    next();
  } else {
    res.status(403).json({ error: 'Access denied. Admins only.', code: 'FORBIDDEN' });
  }
};

// Apply authMiddleware and adminGuard to all member management endpoints
router.use(authMiddleware);
router.use(adminGuard);

router.get('/', async (req, res) => {
  try {
    const list = await membersService.getAllMembers();
    res.json(list);
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Failed to list members' });
  }
});

router.post('/', async (req, res) => {
  try {
    const { email, password, name, phone, deviceName, photoUrl } = req.body;
    const member = await membersService.createMember({ email, password, name, phone, deviceName, photoUrl });
    res.status(201).json(member);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Failed to create member' });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const member = await membersService.getMemberById(req.params.id);
    res.json(member);
  } catch (error: any) {
    res.status(404).json({ error: error.message || 'Member not found' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { name, phone, deviceName, photoUrl, password } = req.body;
    const updated = await membersService.updateMember(req.params.id, { name, phone, deviceName, photoUrl, password });
    res.json(updated);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Failed to update member' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await membersService.deleteMember(req.params.id);
    res.json({ message: 'Member deleted successfully' });
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Failed to delete member' });
  }
});

export const membersRouter = router;
