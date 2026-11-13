import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_hust/main.dart';
import 'package:parking_hust/models/parking_lot.dart';
import 'package:parking_hust/services/api_service.dart';

void main() {
  testWidgets('1. Khởi động app hiển thị Đăng nhập và chuyển sang Đăng ký mượt mà', (WidgetTester tester) async {
    await tester.pumpWidget(const ParkingHustApp());

    // Kiểm tra màn hình Đăng nhập hiển thị đúng nút & ô nhập
    expect(find.text('ĐĂNG NHẬP'), findsOneWidget);
    expect(find.text('Mã số sinh viên hoặc Email'), findsOneWidget);
    expect(find.text('HOÀN TẤT ĐĂNG KÝ'), findsNothing);

    // Bấm nút chuyển sang chế độ Đăng ký
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký ngay'));
    await tester.pumpAndSettle();

    // Kiểm tra giao diện Đăng ký xuất hiện
    expect(find.text('HOÀN TẤT ĐĂNG KÝ'), findsOneWidget);
    expect(find.text('Biển số xe máy (*)'), findsOneWidget);
  });

  testWidgets('2. Nút quẹt thẻ chỉ mở khóa sau khi arrivedLotNotifier có nhà xe đích', (WidgetTester tester) async {
    ApiService.arrivedLotNotifier.value = null;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<ParkingLot?>(
            valueListenable: ApiService.arrivedLotNotifier,
            builder: (context, arrivedLot, _) {
              final bool canCheckIn = arrivedLot != null;
              return OutlinedButton(
                onPressed: canCheckIn ? () {} : null,
                child: Text(
                  canCheckIn
                      ? 'Giả lập quẹt thẻ VÀO ${arrivedLot.name}'
                      : 'Giả lập quẹt thẻ VÀO bãi',
                ),
              );
            },
          ),
        ),
      ),
    );

    // Lúc đầu chưa đến nhà xe -> nút phải bị vô hiệu hóa (onPressed == null)
    final buttonBefore = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(buttonBefore.onPressed, isNull);
    expect(find.text('Giả lập quẹt thẻ VÀO bãi'), findsOneWidget);

    // Mô phỏng sự kiện đã tới Nhà xe C2 và bấm Check-in từ màn Dẫn đường
    ApiService.arrivedLotNotifier.value = ParkingLot(
      id: 'lot-c2',
      name: 'Nhà xe C2',
      totalCapacity: 300,
      reservedQuota: 0,
      availableSlots: 85,
      latitude: 21.0041,
      longitude: 105.8425,
      isOpen: true,
    );
    await tester.pump();

    // Sau khi có nhà xe đích -> nút tự động mở khóa và đổi tên theo bãi
    final buttonAfter = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(buttonAfter.onPressed, isNotNull);
    expect(find.text('Giả lập quẹt thẻ VÀO Nhà xe C2'), findsOneWidget);
  });
}