import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/parking_lot.dart';
import '../services/api_service.dart';
import '../widgets/route_navigation_modal.dart';

// -------------------------------------------------------------
// TAB 3: TÌM KIẾM & ĐIỀU HƯỚNG THEO TÒA HỌC (SEARCH SCREEN)
// -------------------------------------------------------------
class CampusBuilding {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  CampusBuilding({required this.id, required this.name, required this.latitude, required this.longitude});
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Danh sách các tòa nhà tiêu biểu của ĐHBK Hà Nội
  final List<CampusBuilding> _buildings = [
    CampusBuilding(id: 'D9', name: 'Nhà D9 (Viện CNTT)', latitude: 21.0050, longitude: 105.8440),
    CampusBuilding(id: 'D3', name: 'Nhà D3 - D5', latitude: 21.0038, longitude: 105.8455),
    CampusBuilding(id: 'C1', name: 'Nhà C1 (Tòa nhà trung tâm)', latitude: 21.0048, longitude: 105.8420),
    CampusBuilding(id: 'C2', name: 'Nhà C2 (Khu Giảng đường)', latitude: 21.0042, longitude: 105.8428),
    CampusBuilding(id: 'B1', name: 'Nhà B1 (Cổng Đại Cồ Việt)', latitude: 21.0058, longitude: 105.8430),
    CampusBuilding(id: 'TQB', name: 'Thư viện Tạ Quang Bửu', latitude: 21.0040, longitude: 105.8442),
  ];

  late CampusBuilding _selectedBuilding;
  List<ParkingLot> _allLots = [];
  bool _isLoading = true;
  io.Socket? _socket;
  final MapController _mapController = MapController(); // Bộ điều khiển bản đồ

  @override
  void initState() {
    super.initState();
    _selectedBuilding = _buildings[0]; // Mặc định chọn Nhà D9
    _fetchLots();
    _connectSocket();
  }

  // 3. Hàm kết nối và lắng nghe sự kiện từ Backend
  void _connectSocket() {
    _socket = io.io(
      ApiService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );
    _socket!.on('parkingUpdated', (data) {
      if (mounted) {
        _fetchLots(); // Tự động tải lại số chỗ trống và sắp xếp lại danh sách!
      }
    });
  }
  @override
  void dispose() {
    _socket?.dispose(); // <-- 4. Ngắt kết nối khi đóng màn hình
    super.dispose();
  }

  void _fetchLots() async {
    try {
      final lots = await ApiService.getParkingLots();
      setState(() {
        _allLots = lots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 1. CÔNG THỨC TÍNH KHOẢNG CÁCH THỰC TẾ (ĐƠN VỊ: MÉT)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Bán kính trái đất (mét)
    double dLat = (lat2 - lat1) * (math.pi / 180.0);
    double dLon = (lon2 - lon1) * (math.pi / 180.0);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) * math.cos(lat2 * (math.pi / 180.0)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // 2. THUẬT TOÁN SẮP XẾP ĐA TIÊU CHÍ (Còn chỗ -> Gần nhất -> Nhiều chỗ nhất)
  List<Map<String, dynamic>> _getSortedLots() {
    List<Map<String, dynamic>> lotWithDistance = _allLots.map((lot) {
      double dist = _calculateDistance(_selectedBuilding.latitude, _selectedBuilding.longitude, lot.latitude, lot.longitude);
      int walkingMinutes = (dist / 70).ceil(); // Tốc độ đi bộ trung bình 70m/phút
      return {
        'lot': lot,
        'distance': dist,
        'walkingMinutes': walkingMinutes,
      };
    }).toList();

    lotWithDistance.sort((a, b) {
      ParkingLot lotA = a['lot'];
      ParkingLot lotB = b['lot'];
      double distA = a['distance'];
      double distB = b['distance'];

      // Tiêu chí 1: Còn chỗ (availableSlots > 0)
      bool aHasSlot = lotA.availableSlots > 0;
      bool bHasSlot = lotB.availableSlots > 0;
      if (aHasSlot && !bHasSlot) return -1;
      if (!aHasSlot && bHasSlot) return 1;

      // Tiêu chí 2: Gần hơn (nếu chênh lệch hơn 40 mét)
      if ((distA - distB).abs() > 40) {
        return distA.compareTo(distB);
      }

      // Tiêu chí 3: Bãi còn nhiều chỗ trống hơn được ưu tiên
      return lotB.availableSlots.compareTo(lotA.availableSlots);
    });

    return lotWithDistance;
  }

  @override
  Widget build(BuildContext context) {
    final sortedList = _getSortedLots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        title: const Text('Tìm nhà xe theo Tòa học', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // PHẦN 1: BỘ CHỌN TÒA HỌC
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Chọn địa điểm/giảng đường của bạn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CampusBuilding>(
                            isExpanded: true,
                            value: _selectedBuilding,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFB71C1C)),
                            items: _buildings.map((b) {
                              return DropdownMenuItem<CampusBuilding>(
                                value: b,
                                child: Row(
                                  children: [
                                    const Icon(Icons.school_outlined, size: 20, color: Color(0xFFB71C1C)),
                                    const SizedBox(width: 10),
                                    Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newBuilding) {
                              if (newBuilding != null) {
                                setState(() {
                                  _selectedBuilding = newBuilding;
                                });
                                // Di chuyển tâm bản đồ tới tọa độ thật của tòa học vừa chọn
                                _mapController.move(
                                  LatLng(newBuilding.latitude, newBuilding.longitude),
                                  16.5,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // PHẦN 2: BẢN ĐỒ KHUÔN VIÊN TRỰC QUAN (CAMPUS MAP RADAR)
                _buildCampusMap(sortedList),

                // PHẦN 3: DANH SÁCH NHÀ XE ĐÃ XẾP HẠNG
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gợi ý tối ưu cho ${_selectedBuilding.id}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const Text('Đã lọc theo khoảng cách', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: sortedList.length,
                    itemBuilder: (context, index) {
                      final item = sortedList[index];
                      final ParkingLot lot = item['lot'];
                      final double distance = item['distance'];
                      final int minutes = item['walkingMinutes'];
                      final bool isTopPick = index == 0 && lot.availableSlots > 0;

                      return _buildSmartLotCard(lot, distance, minutes, isTopPick);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  // WIDGET KHUNG BẢN ĐỒ THỰC TẾ KHUÔN VIÊN BÁCH KHOA
  Widget _buildCampusMap(List<Map<String, dynamic>> sortedList) {
    final buildingLatLng = LatLng(_selectedBuilding.latitude, _selectedBuilding.longitude);
    final ParkingLot? topLot = sortedList.isNotEmpty ? sortedList[0]['lot'] : null;

    return Container(
      height: 210,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: buildingLatLng,
            initialZoom: 16.5,
            minZoom: 14.0,
            maxZoom: 18.5,
          ),
          children: [
            // 1. Lớp bản đồ thực tế OpenStreetMap
            TileLayer(
              urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              userAgentPackageName: 'vn.edu.hust.parking',
            ),

            // 2. Đường nối đi bộ từ Nhà xe Gợi ý số 1 đến Tòa học đang chọn
            if (topLot != null && topLot.availableSlots > 0)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      LatLng(topLot.latitude, topLot.longitude),
                      buildingLatLng,
                    ],
                    strokeWidth: 4.0,
                    color: const Color(0xFFB71C1C),
                  ),
                ],
              ),

            // 3. Các điểm Ghim trên bản đồ (Tòa học + Các Nhà xe)
            MarkerLayer(
              markers: [
                // GHIM CÁC NHÀ XE XUNG QUANH
                ..._allLots.map((lot) {
                  final isFull = lot.availableSlots <= 0;
                  return Marker(
                    point: LatLng(lot.latitude, lot.longitude),
                    width: 65,
                    height: 50,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isFull ? Colors.red : Colors.green.shade700,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_parking, color: Colors.white, size: 11),
                              const SizedBox(width: 2),
                              Text(
                                '${lot.availableSlots}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: isFull ? Colors.red : Colors.green.shade700, size: 16),
                      ],
                    ),
                  );
                }),

                // GHIM TÒA HỌC ĐANG CHỌN (Nổi bật ở trung tâm)
                Marker(
                  point: buildingLatLng,
                  width: 80,
                  height: 60,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB71C1C),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.school, color: Colors.white, size: 18),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          _selectedBuilding.id,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET THẺ NHÀ XE THÔNG MINH
  Widget _buildSmartLotCard(ParkingLot lot, double distance, int minutes, bool isTopPick) {
    Color statusColor = lot.availableSlots > 100
        ? Colors.green
        : (lot.availableSlots > 20 ? Colors.orange : Colors.red);

    return Card(
      elevation: isTopPick ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isTopPick ? const Color(0xFFB71C1C) : Colors.transparent,
          width: isTopPick ? 1.5 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isTopPick)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFB71C1C), borderRadius: BorderRadius.circular(4)),
                          child: const Text('★ GỢI Ý SỐ 1 (GẦN NHẤT & CÒN CHỖ)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      Text(lot.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    lot.availableSlots > 0 ? 'Còn ${lot.availableSlots} chỗ' : 'Đã hết chỗ',
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.directions_walk, size: 18, color: Colors.blue),
                const SizedBox(width: 4),
                Text('${distance.toInt()}m (~$minutes phút đi bộ)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: isTopPick ? const Color(0xFFB71C1C) : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () {
                    // MỞ MODAL ĐÃ TÁCH FILE:
                    showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => RouteNavigationModal(
                        lot: lot,
                        building: _selectedBuilding,
                        distance: distance,
                        walkingMinutes: minutes,
                    ),
                    );
                },
                icon: const Icon(Icons.navigation, size: 14),
                label: const Text('Chỉ đường', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Lớp vẽ họa tiết bản đồ khuôn viên
class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.shade100
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}