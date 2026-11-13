import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parking_hust/models/parking_lot.dart';
import 'package:parking_hust/utils/navigation_utils.dart';

void main() {
  group('1. Kiểm thử Model ParkingLot', () {
    test('Parse JSON chính xác và tính đúng tỷ lệ lấp đầy', () {
      final json = {
        'id': 'lot-b1',
        'name': 'Nhà xe B1 (Cổng Parabol)',
        'totalCapacity': 500,
        'reservedQuota': 0,
        'availableSlots': 100,
        'latitude': 21.0056,
        'longitude': 105.8433,
        'isOpen': true,
      };

      final lot = ParkingLot.fromJson(json);

      expect(lot.id, 'lot-b1');
      expect(lot.name, 'Nhà xe B1 (Cổng Parabol)');
      expect(lot.availableSlots, 100);
      expect(lot.isOpen, true);
      expect(lot.occupancyRate, closeTo(0.8, 0.001)); // 400/500 = 80%
    });

    test('Mặc định isOpen = true nếu JSON bị thiếu trường isOpen', () {
      final lot = ParkingLot.fromJson({
        'id': 'lot-c2',
        'name': 'Nhà xe C2',
        'totalCapacity': 300,
        'reservedQuota': 0,
        'availableSlots': 50,
        'latitude': 21.0041,
        'longitude': 105.8425,
      });

      expect(lot.isOpen, true);
    });
  });

  group('2. Kiểm thử thuật toán Dẫn đường (NavigationUtils)', () {
    test('calculateBearing tính đúng góc hướng Bắc (~0 độ) và Đông (~90 độ)', () {
      const pStart = LatLng(21.0000, 105.8400);
      const pNorth = LatLng(21.0100, 105.8400);
      const pEast = LatLng(21.0000, 105.8500);

      expect(NavigationUtils.calculateBearing(pStart, pNorth), closeTo(0.0, 1.0));
      expect(NavigationUtils.calculateBearing(pStart, pEast), closeTo(90.0, 1.0));
    });

    test('generateRouteWaypoints sinh đủ 21 điểm và tự xuất phát từ Cổng Parabol khi ở xa > 800m', () {
      const farHome = LatLng(21.0500, 105.8000); // Cách Bách Khoa nhiều km
      const targetLot = LatLng(21.0056, 105.8433);

      final points = NavigationUtils.generateRouteWaypoints(farHome, targetLot);

      expect(points.length, 21);
      // Điểm đầu tiên tự động đặt về Cổng Parabol (21.0065, 105.8425)
      expect(points.first.latitude, closeTo(21.0065, 0.0001));
      expect(points.first.longitude, closeTo(105.8425, 0.0001));
      // Điểm cuối cùng trùng đích đến
      expect(points.last.latitude, closeTo(targetLot.latitude, 0.0001));
      expect(points.last.longitude, closeTo(targetLot.longitude, 0.0001));
    });

    test('generateRouteWaypoints giữ nguyên điểm xuất phát nếu đang ở gần (< 800m)', () {
      const nearCampus = LatLng(21.0050, 105.8430);
      const targetLot = LatLng(21.0056, 105.8433);

      final points = NavigationUtils.generateRouteWaypoints(nearCampus, targetLot);

      expect(points.length, 21);
      expect(points.first.latitude, closeTo(nearCampus.latitude, 0.0001));
      expect(points.first.longitude, closeTo(nearCampus.longitude, 0.0001));
    });
  });
}