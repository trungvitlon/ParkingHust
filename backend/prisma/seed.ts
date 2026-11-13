import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🔄 Đang làm sạch dữ liệu cũ...');
  // Xóa theo thứ tự ràng buộc khóa ngoại
  await prisma.parkingSession.deleteMany();
  await prisma.reservation.deleteMany();
  await prisma.vehicle.deleteMany();
  await prisma.user.deleteMany();
  await prisma.parkingLot.deleteMany();
  await (prisma as any).notification.deleteMany();

  console.log('🏗️ Đang tạo 3 nhà xe Bách Khoa...');
  const lotB1 = await prisma.parkingLot.create({
    data: {
      name: 'Nhà xe B1 (Cổng Parabol)',
      totalCapacity: 500,
      reservedQuota: 0,
      availableSlots: 500, // Sẽ được tự động trừ sau khi nạp xe
      latitude: 21.0056,
      longitude: 105.8433,
      isOpen: true,
    },
  });

  const lotC2 = await prisma.parkingLot.create({
    data: {
      name: 'Nhà xe C2 (Khu Giảng đường C)',
      totalCapacity: 300,
      reservedQuota: 0,
      availableSlots: 300,
      latitude: 21.0041,
      longitude: 105.8425,
      isOpen: true,
    },
  });

  const lotD3 = await prisma.parkingLot.create({
    data: {
      name: 'Nhà xe D3-D5 (Khu Giảng đường D)',
      totalCapacity: 400,
      reservedQuota: 0,
      availableSlots: 400,
      latitude: 21.0035,
      longitude: 105.8458,
      isOpen: true,
    },
  });

  const lotC9 = await prisma.parkingLot.create({
    data: {
      name: 'Nhà xe C9 (Cổng Trần Đại Nghĩa)',
      totalCapacity: 50,
      reservedQuota: 0,
      availableSlots: 50,
      latitude: 21.0048,
      longitude: 105.8448,
      isOpen: true,
    },
  });

  // 1. TẠO USER CHÍNH CỦA BẠN (DÙNG ĐỂ TEST TAB 2)
  console.log('👤 Đang tạo tài khoản sinh viên chính...');
  const mainUser = await prisma.user.create({
    data: {
      email: 'student@sis.hust.edu.vn',
      fullName: 'Nguyễn Văn A',
      studentId: '20210001',
      karmaScore: 100,
      vehicles: {
        create: {
          plateNumber: '29-A1 123.45',
          model: 'Honda Wave Alpha',
          rfidCardId: 'RFID_20210001',
        },
      },
    },
  });

  const mainVehicle = await prisma.vehicle.findFirst({
    where: { userId: mainUser.id },
  });
  if (mainVehicle) {
    // Tạo 2 lượt gửi đã hoàn tất (hôm qua) cho tài khoản chính để demo Lịch sử
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    await prisma.parkingSession.createMany({
      data: [
        {
          vehicleId: mainVehicle.id,
          parkingLotId: lotB1.id,
          status: 'COMPLETED',
          checkInTime: new Date(yesterday.setHours(7, 15, 0)),
          checkOutTime: new Date(yesterday.setHours(11, 40, 0)),
        },
        {
          vehicleId: mainVehicle.id,
          parkingLotId: lotC2.id,
          status: 'COMPLETED',
          checkInTime: new Date(yesterday.setHours(13, 10, 0)),
          checkOutTime: new Date(yesterday.setHours(17, 25, 0)),
        },
      ],
    });
  }
  
  // 2. HÀM TẠO XE MẪU ĐANG GỬI TRONG NHÀ XE
  const vehicleModels = ['Honda Vision', 'Honda Wave Alpha', 'Honda Air Blade', 'Yamaha Sirius', 'Honda Lead', 'Yamaha Exciter'];
  const firstNames = ['Hoàng', 'Trần', 'Lê', 'Phạm', 'Đặng', 'Bùi', 'Đỗ', 'Hồ', 'Ngô', 'Dương'];
  const lastNames = ['Tuấn', 'Minh', 'Hải', 'Dũng', 'Anh', 'Khánh', 'Đức', 'Thắng', 'Linh', 'Quang'];

  async function populateParkingLot(lot: typeof lotB1, parkedCount: number, prefix: string) {
    console.log(`🚗 Đang nạp ${parkedCount} xe vào ${lot.name}...`);
    
    for (let i = 1; i <= parkedCount; i++) {
      const studentCode = `${prefix}${1000 + i}`;
      const randomModel = vehicleModels[i % vehicleModels.length];
      const randomName = `${firstNames[i % firstNames.length]} Văn ${lastNames[i % lastNames.length]}`;
      const randomPlate = `29-${String.fromCharCode(65 + (i % 26))}1 ${Math.floor(10000 + Math.random() * 90000)}`;

      // Tạo user và xe
      const user = await prisma.user.create({
        data: {
          email: `sv${studentCode}@sis.hust.edu.vn`,
          fullName: randomName,
          studentId: studentCode,
          vehicles: {
            create: {
              plateNumber: randomPlate,
              model: randomModel,
              rfidCardId: `RFID_${studentCode}`,
            },
          },
        },
        include: { vehicles: true },
      });

      // Tạo phiên gửi xe đang ở trong bãi (status: PARKED)
      await prisma.parkingSession.create({
        data: {
          vehicleId: user.vehicles[0].id,
          parkingLotId: lot.id,
          status: 'PARKED',
          checkInTime: new Date(Date.now() - Math.floor(Math.random() * 4 * 60 * 60 * 1000)), // Vào trước đó 0-4 tiếng
          checkInPlateImage: 'https://images.unsplash.com/photo-1558981806-ec527fa84c39?w=400',
        },
      });
    }

    // Cập nhật lại số chỗ trống chính xác trong bảng ParkingLot
    await prisma.parkingLot.update({
      where: { id: lot.id },
      data: {
        availableSlots: lot.totalCapacity - parkedCount,
      },
    });
  }

  // 3. NẠP DỮ LIỆU THỰC TẾ CHO CẢ 3 BÃI:
  // - Bãi B1: 50 xe đang gửi
  // - Bãi C2: 215 xe đang gửi (bãi đông)
  // - Bãi D3: 190 xe đang gửi
  await populateParkingLot(lotB1, 50, '2021');
  await populateParkingLot(lotC2, 215, '2022');
  await populateParkingLot(lotD3, 190, '2023');
  await populateParkingLot(lotC9, 45, '2024');

  // 4. NẠP LỊCH SỬ RA/VÀO TRONG NGÀY ĐỂ BIỂU ĐỒ LƯU LƯỢNG HIỂN THỊ TRỰC QUAN
  console.log('📊 Đang tạo dữ liệu lưu lượng vào/ra theo giờ...');
  const sampleVehicles = await prisma.vehicle.findMany({
    where: { userId: { not: mainUser.id } },
    take: 30,
  });

  const VN_OFFSET_MS = 7 * 60 * 60 * 1000;
  const nowVn = new Date(Date.now() + VN_OFFSET_MS);

  const makeVnTime = (hour: number, minute: number) => {
    const vnDate = Date.UTC(
      nowVn.getUTCFullYear(),
      nowVn.getUTCMonth(),
      nowVn.getUTCDate(),
      hour,
      minute,
      0,
    );
    return new Date(vnDate - VN_OFFSET_MS);
  };

  // Quy luật riêng cho từng nhà xe (khớp sức chứa & đặc thù giảng đường)
  const lotConfigs = [
    {
      lot: lotB1, // 500 chỗ - Cổng chính, đông đều cả sáng lẫn chiều
      patterns: [
        { inHour: 6, outHour: 11, count: 22 },
        { inHour: 7, outHour: 12, count: 45 },
        { inHour: 8, outHour: 11, count: 25 },
        { inHour: 12, outHour: 17, count: 38 },
        { inHour: 13, outHour: 17, count: 20 },
        { inHour: 15, outHour: 18, count: 14 },
      ],
    },
    {
      lot: lotC2, // 300 chỗ - Giảng đường C, cực đông ca sáng 07h-09h
      patterns: [
        { inHour: 6, outHour: 11, count: 18 },
        { inHour: 7, outHour: 12, count: 40 },
        { inHour: 8, outHour: 11, count: 30 },
        { inHour: 12, outHour: 17, count: 15 },
        { inHour: 13, outHour: 16, count: 12 },
      ],
    },
    {
      lot: lotD3, // 400 chỗ - Khu D3-D5, đông mạnh ca chiều 12h-14h
      patterns: [
        { inHour: 7, outHour: 12, count: 20 },
        { inHour: 9, outHour: 12, count: 14 },
        { inHour: 12, outHour: 17, count: 36 },
        { inHour: 13, outHour: 18, count: 28 },
        { inHour: 14, outHour: 18, count: 16 },
      ],
    },
    {
      lot: lotC9, // 50 chỗ - Bãi nhỏ, lưu lượng thấp
      patterns: [
        { inHour: 7, outHour: 11, count: 6 },
        { inHour: 8, outHour: 12, count: 8 },
        { inHour: 12, outHour: 17, count: 7 },
        { inHour: 14, outHour: 18, count: 5 },
      ],
    },
  ];

  for (const cfg of lotConfigs) {
    for (const p of cfg.patterns) {
      for (let i = 0; i < p.count; i++) {
        const v = sampleVehicles[(i + p.inHour) % sampleVehicles.length];
        await prisma.parkingSession.create({
          data: {
            vehicleId: v.id,
            parkingLotId: cfg.lot.id,
            status: 'COMPLETED',
            checkInTime: makeVnTime(p.inHour, (i * 4) % 55),
            checkOutTime: makeVnTime(p.outHour, (i * 5) % 55),
          },
        });
      }
    }
  }
  
  // 5. TẠO THÔNG BÁO MẪU CHO TRUNG TÂM THÔNG BÁO (QUẢ CHUÔNG)
  await (prisma as any).notification.createMany({
    data: [
      {
        title: '⚠️ Cảnh báo: Nhà xe C9 sắp đầy!',
        message: 'Nhà xe C9 hiện chỉ còn 5/50 chỗ trống (10%). Hệ thống gợi ý đổi hướng sang Nhà xe B1.',
        type: 'OVERLOAD',
        parkingLotId: lotC9.id,
        suggestLotId: lotB1.id,
      },
      {
        title: '⏰ Nhắc nhở giờ đóng cửa bãi xe',
        message: 'Các nhà xe khuôn viên ĐHBK Hà Nội sẽ đóng cửa lúc 22:00. Vui lòng lấy xe đúng giờ.',
        type: 'CLOSING',
      },
    ],
  });

  console.log('✅ HOÀN TẤT NẠP DỮ LIỆU! TẤT CẢ CON SỐ HIỆN TẠI KHỚP 100% VỚI XE ĐANG ĐỖ.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });