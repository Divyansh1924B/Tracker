import { LocationsRepository } from './locations.repository';

const locationsRepository = new LocationsRepository();

function toRadians(degrees: number): number {
  return degrees * (Math.PI / 180);
}

function getHaversineDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

export class LocationsService {
  async syncBatch(
    userId: string,
    points: Array<{
      latitude: number;
      longitude: number;
      accuracy: number;
      speed?: number;
      batteryPercentage?: number;
      chargingStatus?: boolean;
      gpsEnabled: boolean;
      internetAvailable: boolean;
      timestamp: string;
    }>
  ) {
    for (const point of points) {
      if (
        point.latitude === undefined || 
        point.latitude < -90 || 
        point.latitude > 90 ||
        point.longitude === undefined || 
        point.longitude < -180 || 
        point.longitude > 180 ||
        !point.timestamp
      ) {
        throw new Error('Invalid coordinate details in batch payload');
      }
    }
    return locationsRepository.createBatch(userId, points);
  }

  async getHistory(userId: string, startDate: string, endDate: string) {
    const points = await locationsRepository.findHistory(userId, startDate, endDate);

    let totalDistanceKm = 0;
    let movingTimeSeconds = 0;
    let stoppedTimeSeconds = 0;
    let maxSpeedMps = 0;
    let speedSumMps = 0;
    let speedPointsCount = 0;

    for (let i = 0; i < points.length; i++) {
      const p = points[i];
      const speed = p.speed || 0;
      
      if (speed > maxSpeedMps) {
        maxSpeedMps = speed;
      }
      if (speed > 0) {
        speedSumMps += speed;
        speedPointsCount++;
      }

      if (i > 0) {
        const prev = points[i - 1];
        
        // Accumulate distance
        const d = getHaversineDistanceKm(prev.latitude, prev.longitude, p.latitude, p.longitude);
        totalDistanceKm += d;

        // Accumulate time segment
        const timeDiffMs = new Date(p.timestamp).getTime() - new Date(prev.timestamp).getTime();
        const timeDiffSec = Math.max(0, timeDiffMs / 1000);

        // Threshold: 0.5 m/s (~1.8 km/h) determines moving vs stopped
        if (speed >= 0.5) {
          movingTimeSeconds += timeDiffSec;
        } else {
          stoppedTimeSeconds += timeDiffSec;
        }
      }
    }

    const averageSpeedKmh = speedPointsCount > 0 ? (speedSumMps / speedPointsCount) * 3.6 : 0;
    const maxSpeedKmh = maxSpeedMps * 3.6;

    const statistics = {
      totalDistanceKm: parseFloat(totalDistanceKm.toFixed(2)),
      movingTimeSeconds: Math.round(movingTimeSeconds),
      stoppedTimeSeconds: Math.round(stoppedTimeSeconds),
      averageSpeedKmh: parseFloat(averageSpeedKmh.toFixed(1)),
      maxSpeedKmh: parseFloat(maxSpeedKmh.toFixed(1)),
      pointsCount: points.length,
      firstLocationTime: points.length > 0 ? points[0].timestamp : null,
      lastLocationTime: points.length > 0 ? points[points.length - 1].timestamp : null,
    };

    return {
      statistics,
      points,
    };
  }
}
