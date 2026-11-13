import { Test, TestingModule } from '@nestjs/testing';
import { ParkingGateway } from '../parking-lots/parking.gateway';
import { PrismaService } from '../prisma/prisma.service';
import { ParkingPassService } from './parking-pass.service';

describe('ParkingPassService', () => {
  let service: ParkingPassService;

  const mockPrisma = {
    user: { findFirst: jest.fn() },
    vehicle: { findFirst: jest.fn() },
    parkingLot: {
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
    parkingSession: {
      findFirst: jest.fn(),
      create: jest.fn(),
      count: jest.fn(),
      updateMany: jest.fn(),
    },
    notification: { create: jest.fn() },
  };

  const mockGateway = {
    notifyParkingUpdated: jest.fn(),
    sendSmartAlert: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ParkingPassService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: ParkingGateway, useValue: mockGateway },
      ],
    }).compile();

    service = module.get<ParkingPassService>(ParkingPassService);
  });

  it('toggleCheckIn() check-in đúng bãi chỉ định và phát cảnh báo khi trống <= 10%', async () => {
    mockPrisma.user.findFirst.mockResolvedValue({
      id: 'u1',
      fullName: 'Sinh viên A',
      studentId: '20210001',
      vehicles: [{ id: 'v1', plateNumber: '29-A1 123.45', model: 'Wave' }],
    });
    mockPrisma.parkingSession.findFirst.mockResolvedValue(null); // Đang ở ngoài (OUT)
    mockPrisma.vehicle.findFirst.mockResolvedValue({ id: 'v1', plateNumber: '29-A1 123.45' });

    // Chọn đúng Nhà xe C9 (50 chỗ)
    mockPrisma.parkingLot.findUnique.mockResolvedValue({
      id: 'lot-c9',
      name: 'Nhà xe C9',
      totalCapacity: 50,
    });
    mockPrisma.parkingSession.count.mockResolvedValue(46); // Còn 4/50 chỗ (8% <= 10%)
    mockPrisma.parkingLot.findMany.mockResolvedValue([
      { id: 'lot-b1', name: 'Nhà xe B1', totalCapacity: 500, _count: { sessions: 50 } },
    ]);
    mockPrisma.notification.create.mockResolvedValue({ id: 'notif-1', type: 'OVERLOAD' });

    const res = await service.toggleCheckIn('u1', 'lot-c9');

    expect(res.message).toContain('Nhà xe C9');
    expect(mockPrisma.parkingSession.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ parkingLotId: 'lot-c9', status: 'PARKED' }),
      }),
    );
    expect(mockGateway.notifyParkingUpdated).toHaveBeenCalledWith('lot-c9', expect.any(String));
    expect(mockGateway.sendSmartAlert).toHaveBeenCalled(); // Đã phát cảnh báo quá tải!
  });

  it('toggleCheckIn() khi đang PARKED sẽ check-out và cộng lại chỗ trống', async () => {
    mockPrisma.user.findFirst.mockResolvedValue({
      id: 'u1',
      fullName: 'Sinh viên A',
      studentId: '20210001',
      vehicles: [{ id: 'v1', plateNumber: '29-A1 123.45', model: 'Wave' }],
    });
    mockPrisma.parkingSession.findFirst.mockResolvedValue({
      id: 's1',
      parkingLotId: 'lot-b1',
      parkingLot: { name: 'Nhà xe B1' },
      checkInTime: new Date(),
    });
    mockPrisma.vehicle.findFirst.mockResolvedValue({ id: 'v1', plateNumber: '29-A1 123.45' });

    await service.toggleCheckIn('u1');

    expect(mockPrisma.parkingSession.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: 'COMPLETED' }),
      }),
    );
    expect(mockGateway.notifyParkingUpdated).toHaveBeenCalledWith('lot-b1', 'Xe đã rời bãi');
  });
});