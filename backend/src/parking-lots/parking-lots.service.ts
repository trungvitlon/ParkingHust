import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ParkingLotsService {
  constructor(private prisma: PrismaService) {}

  // Lấy danh sách toàn bộ các nhà xe kèm số xe đang gửi thực tế
  async findAll() {
    const lots = await this.prisma.parkingLot.findMany({
      orderBy: { name: 'asc' },
      include: {
        _count: {
          select: {
            sessions: {
              where: { status: 'PARKED' }, // Đếm chính xác số xe đang ở trong bãi
            },
          },
        },
      },
    });

    // Trả về dữ liệu kèm số lượng xe đang gửi thực tế
    return lots.map((lot) => ({
      ...lot,
      occupiedSlots: lot._count.sessions, // Số xe thực tế trong bãi
      availableSlots: lot.totalCapacity - lot._count.sessions, // Số chỗ trống thực tế
    }));
  }

  async findOne(id: string) {
    const lot = await this.prisma.parkingLot.findUnique({
      where: { id },
      include: {
        _count: {
          select: {
            sessions: { where: { status: 'PARKED' } },
          },
        },
      },
    });

    if (!lot) {
      throw new NotFoundException(`Không tìm thấy nhà xe với ID: ${id}`);
    }

    return {
      ...lot,
      occupiedSlots: lot._count.sessions,
      availableSlots: lot.totalCapacity - lot._count.sessions,
    };
  }

  // Thống kê lưu lượng xe vào/ra theo từng giờ (06h - 22h, giờ Việt Nam UTC+7)
  async getTrafficStats(id: string, range: string = 'today') {
    const lot = await this.prisma.parkingLot.findUnique({ where: { id } });
    if (!lot) {
      throw new NotFoundException(`Không tìm thấy nhà xe với ID: ${id}`);
    }

    const VN_OFFSET_MS = 7 * 60 * 60 * 1000;
    const nowVn = new Date(Date.now() + VN_OFFSET_MS);
    const startOfDayVn = new Date(
      Date.UTC(nowVn.getUTCFullYear(), nowVn.getUTCMonth(), nowVn.getUTCDate(), 0, 0, 0),
    );

    if (range === 'week') {
      startOfDayVn.setUTCDate(startOfDayVn.getUTCDate() - 6); // 7 ngày gần nhất
    }
    const startUtc = new Date(startOfDayVn.getTime() - VN_OFFSET_MS);

    const sessions = await this.prisma.parkingSession.findMany({
      where: {
        parkingLotId: id,
        OR: [
          { checkInTime: { gte: startUtc } },
          { checkOutTime: { gte: startUtc } },
        ],
      },
      select: { checkInTime: true, checkOutTime: true },
    });

    // Khởi tạo 17 khung giờ hoạt động: 06h -> 22h
    const hourly = Array.from({ length: 17 }, (_, idx) => {
      const hour = idx + 6;
      return {
        hour,
        label: `${hour.toString().padStart(2, '0')}h`,
        inCount: 0,
        outCount: 0,
      };
    });

    const getVnHour = (d: Date) => new Date(d.getTime() + VN_OFFSET_MS).getUTCHours();

    let totalIn = 0;
    let totalOut = 0;

    for (const s of sessions) {
      if (s.checkInTime >= startUtc) {
        const hIn = getVnHour(s.checkInTime);
        if (hIn >= 6 && hIn <= 22) {
          hourly[hIn - 6].inCount++;
          totalIn++;
        }
      }
      if (s.checkOutTime && s.checkOutTime >= startUtc) {
        const hOut = getVnHour(s.checkOutTime);
        if (hOut >= 6 && hOut <= 22) {
          hourly[hOut - 6].outCount++;
          totalOut++;
        }
      }
    }

    const peakIn = [...hourly].sort((a, b) => b.inCount - a.inCount)[0];
    const peakOut = [...hourly].sort((a, b) => b.outCount - a.outCount)[0];

    return {
      parkingLotId: lot.id,
      parkingLotName: lot.name,
      range,
      totalIn,
      totalOut,
      peakInHour: peakIn.inCount > 0 ? `${peakIn.label} - ${(peakIn.hour + 1).toString().padStart(2, '0')}h` : 'Chưa có',
      peakOutHour: peakOut.outCount > 0 ? `${peakOut.label} - ${(peakOut.hour + 1).toString().padStart(2, '0')}h` : 'Chưa có',
      hourly,
    };
  }
}