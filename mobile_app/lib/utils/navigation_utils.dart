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

    // 2. SINH 20 ĐIỂM MỐC (WAYPOINTS) GIÚP XE CHẠY MƯỢT MÀ TỪ VỊ TRÍ HIỆN TẠI
  static List<LatLng> generateRouteWaypoints(LatLng start, LatLng destination) {
    List<LatLng> waypoints = [];

    // Xuất phát trực tiếp từ vị trí hiện tại (không ép về Cổng Parabol nữa)
    LatLng actualStart = start;

    // Tạo 2 khúc cua hướng về bãi xe
    LatLng corner1 = LatLng(
      actualStart.latitude + (destination.latitude - actualStart.latitude) * 0.45,
      actualStart.longitude,
    );
    LatLng corner2 = LatLng(
      actualStart.latitude + (destination.latitude - actualStart.latitude) * 0.8,
      destination.longitude,
    );

    // Chặng 1: Từ vị trí hiện tại đến ngã rẽ thứ nhất (15 mốc)
    for (int i = 0; i < 15; i++) {
      waypoints.add(_interpolate(actualStart, corner1, i / 15.0));
    }

    // Chặng 2: Rẽ ngang hướng về bãi xe (15 mốc)
    for (int i = 0; i < 15; i++) {
      waypoints.add(_interpolate(corner1, corner2, i / 15.0));
    }

    // Chặng 3: Tiến vào cổng barrier nhà xe (15 mốc)
    for (int i = 0; i <= 15; i++) {
      waypoints.add(_interpolate(corner2, destination, i / 15.0));
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