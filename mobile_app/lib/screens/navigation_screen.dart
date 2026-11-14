import '../main.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/parking_lot.dart';
import '../services/api_service.dart';
import '../utils/navigation_utils.dart';
import 'search_screen.dart';

class NavigationScreen extends StatefulWidget {
  final ParkingLot lot;
  final CampusBuilding building;

  const NavigationScreen({
    super.key,
    required this.lot,
    required this.building,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  late ParkingLot _activeLot;
  late LatLng _targetLotLocation;

  // Tọa độ & hiệu ứng chuyển động mượt
  LatLng? _currentLocation;
  LatLng? _previousLocation;
  double _vehicleHeading = 0.0; // Góc xoay mũi tên xe máy (độ)
  double _currentSpeedKmh = 25.0; // Tốc độ di chuyển (km/h)
  double _currentDistance = 0.0; // Khoảng cách còn lại (m)
  int _etaMinutes = 2; // Thời gian ước tính (phút)

  // Animation nội suy chuyển động 60 FPS
  AnimationController? _animController;
  Animation<double>? _animProgress;

  // Luồng GPS & WebSocket
  StreamSubscription<Position>? _positionStreamSubscription;
  io.Socket? _socket;
  bool _isLoadingGps = true;
  bool _hasArrived = false;
  bool _hasShownAlert = false;

  // Chế độ: false = GPS thật ngoài đường, true = Mô phỏng Demo xe tự chạy
  bool _isDemoMode = false;
  Timer? _demoTimer;
  List<LatLng> _routePoints = [];
  int _demoCurrentIndex = 0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _activeLot = widget.lot;
    _targetLotLocation = LatLng(widget.lot.latitude, widget.lot.longitude);

    _initAnimation();
    _initRealGpsTracking();
    _connectSocketForNavigation();

    // Kiểm tra cảnh báo quá tải sau 2 giây
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _checkOverloadAndSuggestReroute();
    });
  }

  void _initAnimation() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animProgress = Tween<double>(begin: 0.0, end: 1.0).animate(_animController!)
      ..addListener(() {
        if (_previousLocation != null && _currentLocation != null) {
          // Nội suy vị trí xe mượt mà giữa 2 điểm tọa độ (không bị giật)
          final lat = _previousLocation!.latitude +
              (_currentLocation!.latitude - _previousLocation!.latitude) * _animProgress!.value;
          final lng = _previousLocation!.longitude +
              (_currentLocation!.longitude - _previousLocation!.longitude) * _animProgress!.value;

          _mapController.move(LatLng(lat, lng), 17.5);
        }
      });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _demoTimer?.cancel();
    _animController?.dispose();
    _socket?.dispose();
    super.dispose();
  }

  // LẮNG NGHE WEBSOCKET CẬP NHẬT CHỖ TRỐNG VÀ CẢNH BÁO QUÁ TẢI
  void _connectSocketForNavigation() {
    _socket = io.io(
      ApiService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew() // <-- THÊM DÒNG NÀY
          .enableAutoConnect()
          .build(),
    );

    _socket!.on('parkingUpdated', (_) async {
      final lots = await ApiService.getParkingLots();
      final updated = lots.where((l) => l.id == _activeLot.id).firstOrNull;
      if (updated != null && mounted) {
        setState(() => _activeLot = updated);
        _checkOverloadAndSuggestReroute();
      }
    });
  }

  // TÍNH TOÁN KHOẢNG CÁCH, TỐC ĐỘ VÀ THỜI GIAN ĐẾN NƠI (ETA)
  void _onNewPosition(LatLng newPos, {double? speedMs}) {
    if (_hasArrived) return;

    final double distanceInMeters = Geolocator.distanceBetween(
      newPos.latitude,
      newPos.longitude,
      _targetLotLocation.latitude,
      _targetLotLocation.longitude,
    );

    // Tính tốc độ (km/h): Nếu đang đi bộ/xe chậm dùng mặc định 20-25 km/h
    double speedKmh = 22.0;
    if (speedMs != null && speedMs > 1.0) {
      speedKmh = speedMs * 3.6;
    }

    // Tính thời gian ETA: Thời gian = Khoảng cách / Vận tốc
    final double speedMeterPerSec = (speedKmh * 1000) / 3600;
    final int etaSec = (distanceInMeters / (speedMeterPerSec > 0 ? speedMeterPerSec : 5.5)).round();
    final int etaMin = (etaSec / 60).ceil();

    // Tính góc xoay đầu xe
    double heading = _vehicleHeading;
    if (_currentLocation != null) {
      heading = NavigationUtils.calculateBearing(_currentLocation!, newPos);
    }

    setState(() {
      _previousLocation = _currentLocation ?? newPos;
      _currentLocation = newPos;
      _vehicleHeading = heading;
      _currentDistance = distanceInMeters;
      _currentSpeedKmh = speedKmh;
      _etaMinutes = etaMin > 0 ? etaMin : 1;
      _hasArrived = distanceInMeters <= 20; // Dưới 20m là đã tới
    });

    _animController?.forward(from: 0.0);
  }

  // KHỞI ĐỘNG CẢM BIẾN ĐỊNH VỊ (TỐI ƯU CHO CẢ TRONG NHÀ & NGOÀI ĐƯỜNG)
  Future<void> _initRealGpsTracking() async {
    try {
      debugPrint('🔍 [GPS] Bắt đầu khởi động cảm biến định vị...');

      // 1. Kiểm tra dịch vụ định vị
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ [GPS] Dịch vụ định vị đang TẮT trên điện thoại!');
        _useFallbackLocation();
        return;
      }

      // 2. Kiểm tra & xin quyền định vị
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('⚠️ [GPS] Người dùng từ chối cấp quyền!');
          _useFallbackLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ [GPS] Quyền bị từ chối vĩnh viễn (deniedForever)!');
        _useFallbackLocation();
        return;
      }

      // 3. Ưu tiên 1: Lấy ngay vị trí gần nhất trong bộ nhớ đệm (Chỉ chạy trên Mobile, Web không hỗ trợ)
      if (!kIsWeb) {
        try {
          Position? lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null && mounted) {
            debugPrint('⚡ [ƯU TIÊN 1 - CACHE]: Lấy thành công -> Lat: ${lastKnown.latitude}, Lng: ${lastKnown.longitude}');
            _onNewPosition(LatLng(lastKnown.latitude, lastKnown.longitude));
            setState(() => _isLoadingGps = false);
          }
        } catch (e) {
          debugPrint('⚠️ [ƯU TIÊN 1 - CACHE]: Không lấy được cache ($e)');
        }
      }

      // 4. Ưu tiên 2: Mở ngay Stream lắng nghe (Google Fused Location tự chọn Wi-Fi/4G/Vệ tinh)
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, // Tự động phối hợp Wi-Fi + Vệ tinh
          distanceFilter: 2,               // Di chuyển 2 mét là cập nhật
        ),
      ).listen(
        (Position position) {
          if (!_isDemoMode && mounted) {
            debugPrint('🛰️ [ƯU TIÊN 2 - STREAM REALTIME]: Tọa độ mới -> Lat: ${position.latitude}, Lng: ${position.longitude} | Tốc độ: ${position.speed} m/s');
            _onNewPosition(
              LatLng(position.latitude, position.longitude),
              speedMs: position.speed,
            );
          }
        },
        onError: (err) {
          debugPrint('❌ [ƯU TIÊN 2 - STREAM LỖI]: $err');
        },
      );

      // 5. Thử lấy vị trí hiện tại với thời gian chờ 8s (đủ để quét Wi-Fi định vị trong nhà)
      debugPrint('📡 [ƯU TIÊN 3 - ACTIVE FETCH]: Đang yêu cầu quét vị trí tức thời (chờ tối đa 8s)...');
      Position currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (mounted) {
        debugPrint('🎯 [ƯU TIÊN 3 - ACTIVE FETCH THÀNH CÔNG]: Lat: ${currentPosition.latitude}, Lng: ${currentPosition.longitude}');
        _onNewPosition(
          LatLng(currentPosition.latitude, currentPosition.longitude),
          speedMs: currentPosition.speed,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [NGOẠI LỆ]: Không đo được vị trí tức thời ($e)');
      // Nếu hoàn toàn không có sóng mạng lẫn vệ tinh, mới dùng vị trí Cổng Parabol làm mốc
      if (_currentLocation == null) {
        debugPrint('🚨 [ƯU TIÊN 4 - DỰ PHÒNG]: Chưa có tọa độ nào -> Chuyển về Cổng Parabol!');
        _useFallbackLocation();
      }
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  // BẤM ĐỂ BAY VỀ VỊ TRÍ HIỆN TẠI VÀ HIỆN THÔNG TIN TỌA ĐỘ
  void _zoomToCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 18.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.black87,
          content: Text(
            '📍 Vị trí hiện tại của bạn:\n'
            'Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}\n'
            'Lng: ${_currentLocation!.longitude.toStringAsFixed(6)}\n'
            'Khoảng cách đến bãi: ${_currentDistance.toInt()}m',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang đợi tín hiệu định vị...')),
      );
    }
  }

  void _useFallbackLocation() {
    // Vị trí mặc định tại Cổng Parabol Bách Khoa (21.0065, 105.8430)
    final startPos = const LatLng(21.0065, 105.8430);
    _onNewPosition(startPos);
  }

  // KÍCH HOẠT CHẾ ĐỘ DEMO MÔ PHỎNG (XE TỰ ĐỘNG CHẠY MƯỢT MÀ VÀO BÃI ĐỂ BÁO CÁO ĐỒ ÁN)
  void _toggleDemoMode() {
    setState(() {
      _isDemoMode = !_isDemoMode;
    });

    _demoTimer?.cancel();

    if (_isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.blue,
          content: Text('🚀 Đã bật Chế độ Demo: Xe tự động di chuyển thời gian thực!'),
        ),
      );

      final start = _currentLocation ?? const LatLng(21.0065, 105.8430);
      _routePoints = NavigationUtils.generateRouteWaypoints(start, _targetLotLocation);
      _demoCurrentIndex = 0;

      // Đặt vị trí bắt đầu xe ngay tại mốc đầu tiên của lộ trình
      _onNewPosition(_routePoints[0], speedMs: 6.0);
      // CỨ MỖI 1 GIÂY TIẾN LÊN 1 ĐOẠN (~20 mét / giây -> Tốc độ ~22 km/h)
      _demoTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
        if (_demoCurrentIndex < _routePoints.length - 1) {
          _demoCurrentIndex++;
          final nextPoint = _routePoints[_demoCurrentIndex];
          _onNewPosition(nextPoint, speedMs: 6.2); // Tốc độ hiển thị ~22 km/h
        } else {
          timer.cancel();
          setState(() => _hasArrived = true);
        }
      });
    } else {
      _initRealGpsTracking();
    }
  }

  // KIỂM TRA QUÁ TẢI (<= 10%) VÀ GỢI Ý ĐỔI HƯỚNG
  Future<void> _checkOverloadAndSuggestReroute() async {
    if (_hasShownAlert) return;
    double freeRatio = _activeLot.availableSlots / _activeLot.totalCapacity;
    if (freeRatio <= 0.10) {
      _hasShownAlert = true;

      final allLots = await ApiService.getParkingLots();
      final alternatives = allLots
          .where((l) => l.id != _activeLot.id && l.availableSlots > 20)
          .toList();

      if (alternatives.isEmpty || !mounted) return;

      final ParkingLot bestLot = alternatives.first;

            showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          // 1. TIÊU ĐỀ
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cảnh báo quá tải!',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),

          // 2. NỘI DUNG (CHỈ GỒM 2 DÒNG NGẮN GỌN)
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DÒNG 1: THÔNG BÁO TÌNH TRẠNG NHÀ XE HIỆN TẠI
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️ ', style: TextStyle(fontSize: 15)),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: _activeLot.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: ' sắp hết chỗ (chỉ còn ${_activeLot.availableSlots}/${_activeLot.totalCapacity} chỗ trống).'),
                        ],
                      ),
                      style: const TextStyle(fontSize: 14, height: 1.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // DÒNG 2: GỢI Ý NHÀ XE KHÁC
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Text('💡 ', style: TextStyle(fontSize: 15)),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Gợi ý: Đổi sang ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            TextSpan(text: bestLot.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: ' (còn ${bestLot.availableSlots} chỗ trống).'),
                          ],
                        ),
                        style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 3. NÚT HÀNH ĐỘNG
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đi tiếp bãi cũ', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _activeLot = bestLot;
                  _targetLotLocation = LatLng(bestLot.latitude, bestLot.longitude);
                });
                if (_currentLocation != null) {
                  _onNewPosition(_currentLocation!);
                }
              },
              icon: const Icon(Icons.alt_route, size: 18),
              label: const Text('Đổi hướng ngay'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingGps) {
      return Scaffold(
        appBar: AppBar(backgroundColor: const Color(0xFFB71C1C), title: const Text('Đang kết nối GPS...')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFB71C1C)),
              SizedBox(height: 16),
              Text('Đang đồng bộ vệ tinh dẫn đường...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. LỚP BẢN ĐỒ THỰC TẾ
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? _targetLotLocation,
              initialZoom: 17.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'vn.edu.hust.parking',
              ),
              // Tuyến đường màu xanh phát sáng dẫn đến bãi đỗ
              if (_currentLocation != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_currentLocation!, _targetLotLocation],
                      strokeWidth: 6.0,
                      color: Colors.blue.shade700,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // ICON XE MÁY MÀU XANH: TỰ XOAY ĐẦU THEO HƯỚNG LÁI (BEARING)
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 50,
                      height: 50,
                      child: Transform.rotate(
                        angle: _vehicleHeading * (math.pi / 180.0), // Xoay theo góc lái
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade800,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: const Icon(Icons.navigation, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // GHIM NHÀ XE MỤC TIÊU (ĐÃ FIX TRÀN VIỀN & CĂN MŨI GHIM CHÍNH XÁC)
                  Marker(
                    point: _targetLotLocation,
                    width: 130, // Tăng độ rộng để chứa trọn vẹn tên nhà xe
                    height: 70, // Đủ chiều cao cho cả icon lẫn nhãn tên
                    alignment: Alignment.bottomCenter, // Mũi nhọn ghim cắm chuẩn tọa độ
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nhãn tên bãi xe nền đen chữ trắng bo tròn
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Text(
                            _activeLot.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Icon ghim đỏ Bách Khoa trỏ xuống
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFFB71C1C),
                          size: 38,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. HUD CHỈ DẪN TRÊN CÙNG (NEXT TURN BANNER)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB71C1C),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.turn_right, color: Colors.white, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _hasArrived ? 'Đã đến cổng bãi xe!' : 'Đi thẳng vào cổng ${_activeLot.name}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text('Đích đến: ${widget.building.name}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                          // Nút chuyển đổi nhanh Chế độ Demo
                          IconButton(
                            icon: Icon(_isDemoMode ? Icons.pause_circle : Icons.play_circle, color: Colors.yellowAccent),
                            tooltip: _isDemoMode ? 'Dừng Demo' : 'Chạy Demo',
                            onPressed: _toggleDemoMode,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // NÚT TRÒN ĐỊNH VỊ BÊN PHẢI MÀN HÌNH
          Positioned(
            right: 16,
            bottom: 230,
            child: FloatingActionButton.small(
              heroTag: 'my_location_btn',
              backgroundColor: Colors.white,
              onPressed: _zoomToCurrentLocation,
              child: const Icon(Icons.my_location, color: Color(0xFFB71C1C)),
            ),
          ),

          // 3. BẢNG ĐIỀU KHIỂN TELEMETRY Ở ĐÁY (HUD DASHBOARD)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // KHOẢNG CÁCH THỜI GIAN THỰC
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _currentDistance >= 1000
                                    ? '${(_currentDistance / 1000).toStringAsFixed(1)}'
                                    : '${_currentDistance.toInt()}',
                                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFFB71C1C)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _currentDistance >= 1000 ? 'km' : 'mét',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 16),
                              ),
                            ],
                          ),
                          Text('Khoảng cách thực tế đến bãi', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),

                      // ĐỒNG HỒ ETA & CÔNG-TƠ-MÉT
                      Row(
                        children: [
                          // TỐC ĐỘ DI CHUYỂN
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              children: [
                                const Text('TỐC ĐỘ', style: TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold)),
                                Text('${_currentSpeedKmh.toInt()} km/h', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // THỜI GIAN ĐẾN NƠI (ETA)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              children: [
                                const Text('DỰ KIẾN', style: TextStyle(fontSize: 9, color: Colors.brown, fontWeight: FontWeight.bold)),
                                Text('~$_etaMinutes ph', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown.shade900, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // NÚT HÀNH ĐỘNG
                  if (_hasArrived)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          // 1. Lưu lại nhà xe vừa đến (dùng _activeLot để đúng cả khi vừa đổi hướng)
                          ApiService.arrivedLotNotifier.value = _activeLot;
                          // 2. Chuyển tab sang Tab Vé xe (Index = 1)
                          switchMainTab(1);
                          // 3. Đóng toàn bộ màn hình dẫn đường & modal lộ trình
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('BẠN ĐÃ ĐẾN BÃI XE - MỞ CHECK-IN NGAY', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Colors.red),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Dừng dẫn đường', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}