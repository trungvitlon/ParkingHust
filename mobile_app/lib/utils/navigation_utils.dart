import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class NavigationUtils {
  // 1. TÍNH GÓC XOAY ĐẦU XE (BEARING) THEO HƯỚNG DI CHUYỂN (0 - 360 ĐỘ)
  static double calculateBearing(LatLng start, LatLng end) {
    double startLat = start.latitude * (math.pi / 180.0);
    double startLng = start.longitude * (math.pi / 180.0);
    double endLat = end.latitude * (math.pi / 180.0);
    double endLng = end.longitude * (math.pi / 180.0);

    double dLng = endLng - startLng;

    double y = math.sin(dLng) * math.cos(endLat);
    double x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    double bearing = math.atan2(y, x);
    return (bearing * (180.0 / math.pi) + 360.0) % 360.0;
  }

  // 2. SINH 20 ĐIỂM MỐC (WAYPOINTS) GIÚP XE CHẠY MƯỢT MÀ, GIẢM KHOẢNG CÁCH TỪ TỪ
  static List<LatLng> generateRouteWaypoints(LatLng start, LatLng destination) {
    List<LatLng> waypoints = [];

    // Kiểm tra khoảng cách từ vị trí hiện tại đến nhà xe
    double dist = Geolocator.distanceBetween(
      start.latitude, start.longitude,
      destination.latitude, destination.longitude,
    );

    // NẾU ĐANG Ở XA TRƯỜNG (> 800m), TỰ ĐỘNG XUẤT PHÁT TỪ CỔNG PARABOL (GIẢI PHÓNG)
    LatLng actualStart = start;
    if (dist > 800) {
      actualStart = const LatLng(21.0065, 105.8425); // Cổng Parabol Bách Khoa
    }

    // Tạo 2 khúc cua nội bộ trong trường
    LatLng corner1 = LatLng(
      actualStart.latitude + (destination.latitude - actualStart.latitude) * 0.45,
      actualStart.longitude,
    );
    LatLng corner2 = LatLng(
      actualStart.latitude + (destination.latitude - actualStart.latitude) * 0.8,
      destination.longitude,
    );

    // Chặng 1: Từ cổng đến ngã tư thứ nhất (7 mốc)
    for (int i = 0; i < 7; i++) {
      waypoints.add(_interpolate(actualStart, corner1, i / 7.0));
    }

    // Chặng 2: Rẽ ngang hướng về bãi xe (7 mốc)
    for (int i = 0; i < 7; i++) {
      waypoints.add(_interpolate(corner1, corner2, i / 7.0));
    }

    // Chặng 3: Tiến vào cổng barrier nhà xe (6 mốc)
    for (int i = 0; i <= 6; i++) {
      waypoints.add(_interpolate(corner2, destination, i / 6.0));
    }

    return waypoints;
  }

  // Hàm nội suy tọa độ giữa 2 điểm
  static LatLng _interpolate(LatLng p1, LatLng p2, double t) {
    return LatLng(
      p1.latitude + (p2.latitude - p1.latitude) * t,
      p1.longitude + (p2.longitude - p1.longitude) * t,
    );
  }
}