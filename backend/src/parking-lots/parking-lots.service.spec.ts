import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service';
import { ParkingLotsService } from './parking-lots.service';

describe('ParkingLotsService', () => {
  let service: ParkingLotsService;

  // Giả lập PrismaService
  const mockPrisma = {
    parkingLot: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
    },
    parkingSession: {
      findMany: jest.fn(),
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ParkingLotsService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<ParkingLotsService>(ParkingLotsService);
  });

  it('findAll() phải tính đúng availableSlots từ số xe đang PARKED', async () => {
    mockPrisma.parkingLot.findMany.mockResolvedValue([
      {
        id: 'lot-b1',
        name: 'Nhà xe B1',
        totalCapacity: 500,
        _count: { sessions: 120 },
      },
    ]);

    const result = await service.findAll();

    expect(result).toHaveLength(1);
    expect(result[0].occupiedSlots).toBe(120);
    expect(result[0].availableSlots).toBe(380);
  });

  it('getTrafficStats() gom nhóm đúng theo giờ Việt Nam (UTC+7) từ 06h đến 22h', async () => {
    mockPrisma.parkingLot.findUnique.mockResolvedValue({
      id: 'lot-b1',
      name: 'Nhà xe B1',
    });

    // Tạo mốc giờ hôm nay theo VN để test (07:30 vào và 17:15 ra)
    const VN_OFFSET_MS = 7 * 60 * 60 * 1000;
    const nowVn = new Date(Date.now() + VN_OFFSET_MS);
    const makeVnDate = (h: number, m: number) =>
      new Date(
        Date.UTC(nowVn.getUTCFullYear(), nowVn.getUTCMonth(), nowVn.getUTCDate(), h, m) -
          VN_OFFSET_MS,
      );

    mockPrisma.parkingSession.findMany.mockResolvedValue([
      { checkInTime: makeVnDate(7, 30), checkOutTime: makeVnDate(17, 15) },
      { checkInTime: makeVnDate(7, 45), checkOutTime: null },
    ]);

    const stats = await service.getTrafficStats('lot-b1', 'today');

    expect(stats.hourly).toHaveLength(17); // 06h -> 22h
    expect(stats.totalIn).toBe(2);
    expect(stats.totalOut).toBe(1);
    expect(stats.peakInHour).toBe('07h - 08h');
    expect(stats.peakOutHour).toBe('17h - 18h');
  });

  it('getTrafficStats() báo lỗi NotFoundException (404) nếu sai ID nhà xe', async () => {
    mockPrisma.parkingLot.findUnique.mockResolvedValue(null);

    await expect(service.getTrafficStats('id-sai')).rejects.toThrow(NotFoundException);
  });
});