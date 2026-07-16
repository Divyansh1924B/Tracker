import { Router } from 'express';
import { LocationsService } from './locations.service';
import { authMiddleware, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { broadcastToAdmins } from '../../websocket/tracker.ws';
import { prisma } from '../../database/prisma';

const router = Router();
const locationsService = new LocationsService();

// Admin Guard Middleware
const adminGuard = (req: AuthenticatedRequest, res: any, next: any) => {
  if (req.user && req.user.role === 'admin') {
    next();
  } else {
    res.status(403).json({ error: 'Access denied. Admins only.', code: 'FORBIDDEN' });
  }
};

router.use(authMiddleware);

router.post('/sync', async (req, res) => {
  try {
    const userId = (req as AuthenticatedRequest).user!.id;
    const { points } = req.body;
    
    if (!points || !Array.isArray(points)) {
      return res.status(400).json({ error: 'Missing or invalid "points" array' });
    }

    const count = await locationsService.syncBatch(userId, points);
    
    if (count > 0) {
      const userRes = await prisma.user.findUnique({
        where: { id: userId },
        select: { name: true },
      });
      const name = userRes?.name || 'Member';
      
      const lastPoint = points[points.length - 1];
      broadcastToAdmins({
        type: 'location_update',
        payload: {
          userId,
          name,
          latitude: lastPoint.latitude,
          longitude: lastPoint.longitude,
          accuracy: lastPoint.accuracy,
          speed: lastPoint.speed,
          batteryPercentage: lastPoint.batteryPercentage,
          chargingStatus: lastPoint.chargingStatus,
          gpsEnabled: lastPoint.gpsEnabled,
          internetAvailable: lastPoint.internetAvailable,
          timestamp: lastPoint.timestamp,
        },
      });
    }

    res.json({ message: 'Batch synced successfully', count });
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Locations synchronization failed' });
  }
});

// Admin-only Route History API
router.get('/history', adminGuard, async (req, res) => {
  try {
    const { userId, startDate, endDate } = req.query;

    if (!userId || !startDate || !endDate) {
      return res.status(400).json({ error: 'Missing required query parameters: userId, startDate, endDate' });
    }

    const result = await locationsService.getHistory(
      userId as string,
      startDate as string,
      endDate as string
    );
    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Failed to fetch location history' });
  }
});

export const locationsRouter = router;
