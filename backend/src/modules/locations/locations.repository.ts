import { prisma } from '../../database/prisma';

export class LocationsRepository {
  async createBatch(
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
      provider?: string;
      deviceModel?: string;
    }>
  ) {
    if (points.length === 0) return 0;

    const result = await prisma.location.createMany({
      data: points.map((point) => ({
        userId,
        latitude: point.latitude,
        longitude: point.longitude,
        accuracy: point.accuracy,
        speed: point.speed ?? null,
        batteryPercentage: point.batteryPercentage ?? null,
        chargingStatus: point.chargingStatus ?? null,
        gpsEnabled: point.gpsEnabled,
        internetAvailable: point.internetAvailable,
        timestamp: new Date(point.timestamp),
        provider: point.provider ?? null,
        deviceModel: point.deviceModel ?? null,
      })),
    });

    return result.count;
  }

  async findHistory(userId: string, startDate: string, endDate: string) {
    return prisma.location.findMany({
      where: {
        userId,
        timestamp: {
          gte: new Date(startDate),
          lte: new Date(endDate),
        },
      },
      select: {
        latitude: true,
        longitude: true,
        accuracy: true,
        speed: true,
        batteryPercentage: true,
        chargingStatus: true,
        gpsEnabled: true,
        internetAvailable: true,
        timestamp: true,
        provider: true,
        deviceModel: true,
      },
      orderBy: {
        timestamp: 'asc',
      },
    });
  }
}
