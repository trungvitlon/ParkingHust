import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  constructor(private prisma: PrismaService) {}

  // 1. ĐĂNG KÝ TÀI KHOẢN VÀ PHƯƠNG TIỆN
  async register(data: { email: string; password: string; fullName: string; studentId: string; plateNumber: string; vehicleModel: string }) {
    const existing = await this.prisma.user.findFirst({
      where: { OR: [{ email: data.email }, { studentId: data.studentId }] },
    });
    if (existing) {
      throw new BadRequestException('Email hoặc MSSV này đã tồn tại trong hệ thống!');
    }

    const hashedPassword = await bcrypt.hash(data.password, 10);

    const user = await (this.prisma.user as any).create({
      data: {
        email: data.email,
        password: hashedPassword,
        fullName: data.fullName,
        studentId: data.studentId,
        vehicles: {
          create: {
            plateNumber: data.plateNumber,
            model: data.vehicleModel,
            rfidCardId: `RFID_${data.studentId}`,
          },
        },
      },
      include: { vehicles: true },
    });

    return { message: 'Đăng ký thành công!', user };
  }

  // 2. ĐĂNG NHẬP
  async login(emailOrStudentId: string, passwordPlain: string) {
    const user = await this.prisma.user.findFirst({
      where: {
        OR: [{ email: emailOrStudentId }, { studentId: emailOrStudentId }],
      },
      include: { vehicles: true },
    });

    if (!user) {
      throw new UnauthorizedException('Tài khoản hoặc MSSV không tồn tại');
    }

    // Nếu user có mật khẩu, kiểm tra mã hóa bcrypt
    const userPassword = (user as any).password;
    if (userPassword) {
      const isMatch = await bcrypt.compare(passwordPlain, userPassword);
      if (!isMatch) {
        throw new UnauthorizedException('Mật khẩu không chính xác');
      }
    }

    return {
      message: 'Đăng nhập thành công',
      user: {
        id: user.id,
        fullName: user.fullName,
        studentId: user.studentId,
        email: user.email,
        vehicles: user.vehicles,
      },
    };
  }

  // 3. LẤY THÔNG TIN CÁ NHÂN & LỊCH SỬ GỬI XE (CHO TAB 4)
  async getProfile(userId?: string) {
    const user = await this.prisma.user.findFirst({
      where: userId ? { OR: [{ id: userId }, { studentId: userId }] } : {},
      include: {
        vehicles: {
          include: {
            sessions: {
              include: { parkingLot: true },
              orderBy: { checkInTime: 'desc' },
              take: 5, // Lấy 5 lần gửi xe gần nhất
            },
          },
        },
      },
    });

    return user;
  }
}