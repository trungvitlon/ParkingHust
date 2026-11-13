import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ParkingGateway } from '../parking-lots/parking.gateway';

@Injectable()
export class ParkingPassService {
  constructor(
    private prisma: PrismaService,
    private parkingGateway: ParkingGateway,
  ) {}

  // 1. Nhận userId để lấy đúng vé xe của người đang đăng nhập
  async getStudentPass(userId?: string) {
    let user = await this.prisma.user.findFirst({
      where: userId ? { OR: [{ id: userId }, { studentId: userId }] } : {},
      include: { vehicles: true },
    });

    if (!user || !user.vehicles || user.vehicles.length === 0) {
      throw new Error('Người dùng chưa có phương tiện');
    }
    
    const vehicle = user.vehicles[0];
    
    // Kiểm tra xem xe này có đang ở trong bãi không
    const activeSession = await this.prisma.parkingSession.findFirst({
      where: { vehicleId: vehicle.id, status: 'PARKED' },
      include: { parkingLot: true },
    });
    
    return {
      studentName: user.fullName,
      studentId: user.studentId,
      plateNumber: vehicle.plateNumber,
      vehicleModel: vehicle.model,
      status: activeSession ? 'PARKED' : 'OUT',
      session: activeSession
        ? {
            parkingLotName: activeSession.parkingLot.name,
            checkInTime: activeSession.checkInTime,
            checkInPlateImage: activeSession.checkInPlateImage ?? 'https://images.unsplash.com/photo-1558981806-ec527fa84c39?w=400',
          }
        : null,
      qrToken: `HUST_PASS_${user.studentId}_${Math.floor(Date.now() / 30000)}`,
    };
  }

    // 2. Quẹt thẻ vào/ra bãi + Tự động kiểm tra Cảnh báo Quá tải Real-time
  async toggleCheckIn(userId?: string, parkingLotId?: string) {
    const pass = await this.getStudentPass(userId);
    const vehicle = await this.prisma.vehicle.findFirst({
      where: { plateNumber: pass.plateNumber },
    });

    if (pass.status === 'OUT') {
      // Chọn nhà xe được chỉ định (hoặc lấy nhà xe đầu tiên nếu không truyền)
      const lot = parkingLotId
        ? await this.prisma.parkingLot.findUnique({ where: { id: parkingLotId } })
        : await this.prisma.parkingLot.findFirst();

      await this.prisma.parkingSession.create({
        data: {
          vehicleId: vehicle!.id,
          parkingLotId: lot!.id,
          status: 'PARKED',
          checkInPlateImage: 'https://images.unsplash.com/photo-1558981806-ec527fa84c39?w=400',
        },
      });

      await this.prisma.parkingLot.update({
        where: { id: lot!.id },
        data: { availableSlots: { decrement: 1 } },
      });

      // Đếm số lượng xe thực tế đang gửi tại bãi này ngay lập tức
      const occupiedCount = await this.prisma.parkingSession.count({
        where: { parkingLotId: lot!.id, status: 'PARKED' },
      });
      const currentAvailable = lot!.totalCapacity - occupiedCount;
      const freeRatio = currentAvailable / lot!.totalCapacity;

      // Phát WebSocket cập nhật số chỗ trống
      this.parkingGateway.notifyParkingUpdated(lot!.id, 'Cập nhật số lượng chỗ đỗ');

      // KIỂM TRA REAL-TIME: Nếu tỷ lệ trống <= 10% -> PHÁT CẢNH BÁO QUÁ TẢI!
      if (freeRatio <= 0.1) {
        // Tìm nhà xe khác đang còn nhiều chỗ trống nhất để gợi ý đổi hướng
        const allLots = await this.prisma.parkingLot.findMany({
          where: { id: { not: lot!.id } },
          include: {
            _count: { select: { sessions: { where: { status: 'PARKED' } } } },
          },
        });

        const bestAlternative = allLots
          .map((l) => ({ ...l, realFree: l.totalCapacity - l._count.sessions }))
          .sort((a, b) => b.realFree - a.realFree)[0];

        const alertTitle = currentAvailable <= 0
          ? `🚫 ${lot!.name} ĐÃ HẾT CHỖ!`
          : `⚠️ Cảnh báo: ${lot!.name} sắp đầy!`;

        const alertMsg = `${lot!.name} hiện chỉ còn ${currentAvailable}/${lot!.totalCapacity} chỗ trống (${Math.round(freeRatio * 100)}%). Hệ thống gợi ý đổi hướng sang ${bestAlternative.name} (còn ${bestAlternative.realFree} chỗ).`;

        const savedAlert = await (this.prisma as any).notification.create({
          data: {
            title: alertTitle,
            message: alertMsg,
            type: 'OVERLOAD',
            parkingLotId: lot!.id,
            suggestLotId: bestAlternative.id,
          },
        });

        // Phát sóng cảnh báo kèm thông tin nhà xe thay thế xuống Mobile
        this.parkingGateway.sendSmartAlert({
          ...savedAlert,
          suggestLot: bestAlternative,
        });
      }

      return { message: `Đã check-in vào ${lot!.name}!` };
    } else {
      // Tìm phiên đang gửi để biết xe đang ở nhà xe nào
      const currentSession = await this.prisma.parkingSession.findFirst({
        where: { vehicleId: vehicle!.id, status: 'PARKED' },
      });

      await this.prisma.parkingSession.updateMany({
        where: { vehicleId: vehicle!.id, status: 'PARKED' },
        data: { status: 'COMPLETED', checkOutTime: new Date() },
      });

      if (currentSession) {
        await this.prisma.parkingLot.update({
          where: { id: currentSession.parkingLotId },
          data: { availableSlots: { increment: 1 } },
        });
        this.parkingGateway.notifyParkingUpdated(currentSession.parkingLotId, 'Xe đã rời bãi');
      }

      return { message: 'Đã check-out ra khỏi bãi xe!' };
    }
  }

  // 3. Lấy danh sách lịch sử cảnh báo
  async getNotifications() {
    return (this.prisma as any).notification.findMany({
      orderBy: { createdAt: 'desc' },
      take: 15,
    });
  }

  // 4. Giả lập Cảnh báo Giờ đóng cửa (21h30) hoặc Gửi xe qua đêm
  async triggerSystemAlert(type: 'CLOSING' | 'OVERNIGHT') {
    const title = type === 'CLOSING'
      ? '🕘 Nhắc nhở: Sắp đến giờ đóng cửa bãi xe!'
      : '🚨 CẢNH BÁO VI PHẠM: Gửi xe qua đêm!';

    const message = type === 'CLOSING'
      ? 'Các nhà xe khuôn viên ĐHBK sẽ đóng cửa lúc 21h30. Sinh viên còn xe trong bãi vui lòng di chuyển ra lấy xe.'
      : 'Hệ thống ghi nhận phương tiện của bạn lưu bãi quá 22h00 mà chưa đăng ký gửi qua đêm.';

    const savedAlert = await (this.prisma as any).notification.create({
      data: { title, message, type },
    });

    this.parkingGateway.sendSmartAlert(savedAlert);
    return savedAlert;
  }
}