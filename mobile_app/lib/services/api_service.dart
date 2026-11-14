import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/parking_lot.dart';

class ApiService {
  // Khi test trên Edge/Chrome Web hoặc Windows Desktop dùng localhost:3000
  // (Nếu sau này chạy trên máy ảo Android Emulator thì đổi thành http://10.0.2.2:3000)
  static const String baseUrl = 'https://parking-hust-api.onrender.com';
  //static const String baseUrl = 'http://192.168.2.103:3000'; // Địa chỉ IP của máy tính chạy backend (có thể thay đổi tùy mạng)
  
  // BIẾN LƯU ID CỦA NGƯỜI ĐANG ĐĂNG NHẬP:
  static String? currentUserId;

  // LƯU NHÀ XE VỪA ĐẾN TỪ MÀN HÌNH DẪN ĐƯỜNG (null = chưa đến bãi nào)
  static final ValueNotifier<ParkingLot?> arrivedLotNotifier = ValueNotifier<ParkingLot?>(null);

  static Future<List<ParkingLot>> getParkingLots() async {
    final response = await http.get(Uri.parse('$baseUrl/parking-lots'));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => ParkingLot.fromJson(item)).toList();
    } else {
      throw Exception('Không thể tải danh sách nhà xe từ server');
    }
  }

  // Lấy thông tin vé xe (gửi kèm ID người đang đăng nhập)
  static Future<Map<String, dynamic>> getParkingPass() async {
    final url = currentUserId != null
        ? '$baseUrl/parking-pass?userId=$currentUserId'
        : '$baseUrl/parking-pass';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Không thể tải thông tin vé xe');
    }
  }

  // Quẹt thẻ vào/ra bãi đúng chiếc xe & đúng nhà xe
  static Future<void> toggleCheckIn({String? parkingLotId}) async {
    await http.post(
      Uri.parse('$baseUrl/parking-pass/toggle'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': currentUserId,
        if (parkingLotId != null) 'parkingLotId': parkingLotId,
      }),
    );
  }

  // Đăng nhập
  static Future<Map<String, dynamic>> login(String account, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'account': account, 'password': password}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      
      // LƯU LẠI ID CỦA USER VỪA ĐĂNG NHẬP VÀO ĐÂY:
      currentUserId = data['user']['id'];
      
      return data;
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Đăng nhập thất bại');
    }
  }

  // Lấy thông tin cá nhân Profile cho Tab 4
  static Future<Map<String, dynamic>> getProfile() async {
    // Nếu đã đăng nhập, gửi kèm userId để lấy đúng thông tin của người đó
    final url = currentUserId != null
        ? '$baseUrl/auth/profile?userId=$currentUserId'
        : '$baseUrl/auth/profile';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Không thể tải thông tin cá nhân');
    }
  }

  // Đăng ký tài khoản & phương tiện mới
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String studentId,
    required String email,
    required String password,
    required String plateNumber,
    required String vehicleModel,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'studentId': studentId,
        'email': email,
        'password': password,
        'plateNumber': plateNumber,
        'vehicleModel': vehicleModel,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      // Tự động lưu ID của user vừa đăng ký để vào thẳng ứng dụng
      currentUserId = data['user']['id'];
      return data;
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Đăng ký thất bại');
    }
  }

  // Lấy danh sách cảnh báo & thông báo
  static Future<List<dynamic>> getNotifications() async {
    final response = await http.get(Uri.parse('$baseUrl/parking-pass/notifications'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Không thể tải danh sách thông báo');
    }
  }

  // Lấy thống kê lưu lượng vào/ra theo giờ của 1 nhà xe
  static Future<Map<String, dynamic>> getParkingTraffic(
    String lotId, {
    String range = 'today',
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/parking-lots/$lotId/traffic?range=$range'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Không thể tải thống kê lưu lượng');
    }
  }
}