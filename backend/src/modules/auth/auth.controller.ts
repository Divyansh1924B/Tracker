import { Router } from 'express';
import { AuthService } from './auth.service';
import { authMiddleware, AuthenticatedRequest } from '../../middleware/auth.middleware';

const router = Router();
const authService = new AuthService();

router.post('/login', async (req, res, next) => {
  try {
    const { email, password, deviceName } = req.body;
    const result = await authService.login(email, password, deviceName);
    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Login failed' });
  }
});

router.post('/logout', authMiddleware, async (req, res) => {
  try {
    const userId = (req as AuthenticatedRequest).user!.id;
    await authService.logout(userId);
    res.json({ message: 'Logged out successfully' });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Logout failed' });
  }
});

router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const userId = (req as AuthenticatedRequest).user!.id;
    const profile = await authService.getProfile(userId);
    res.json(profile);
  } catch (error: any) {
    res.status(404).json({ error: error.message || 'Profile not found' });
  }
});

router.put('/profile', authMiddleware, async (req, res) => {
  try {
    const userId = (req as AuthenticatedRequest).user!.id;
    const { name, phone, deviceName, photoUrl } = req.body;
    const updated = await authService.updateProfile(userId, { name, phone, deviceName, photoUrl });
    res.json(updated);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Update profile failed' });
  }
});

router.post('/register', async (req, res, next) => {
  try {
    const { name, email, phone, password, deviceName, adminPassword } = req.body;
    const result = await authService.register({ name, email, phone, password, deviceName, adminPassword });
    res.status(201).json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Registration failed' });
  }
});

export const authRouter = router;
