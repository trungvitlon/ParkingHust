import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/parking_lot.dart';
import '../services/api_service.dart';
import '../widgets/traffic_stats_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ParkingLot>> _parkingLotsFuture;
  io.Socket? _socket;
  int _unreadAlertsCount = 0; // Đếm số thông báo mới

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadAlertsCount(); // Đọc số thông báo ban đầu
    _connectSocket(); // Kết nối WebSocket ngay khi mở app
  }

  void _loadAlertsCount() async {
    try {
      final notifs = await ApiService.getNotifications();
      if (mounted) {
        setState(() {
          _unreadAlertsCount = notifs.length;
        });
      }
    } catch (_) {}
  }

  void _connectSocket() {
    _socket = io.io(
      ApiService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableAutoConnect()
          .build(),
    );

    // Lắng nghe tín hiệu từ Server mỗi khi có xe quẹt thẻ qua cổng
    _socket!.on('parkingUpdated', (data) {
      if (mounted) {
        _loadData(); // Tự động cập nhật lại số chỗ trống trên màn hình!
      }
    });

    // Lắng nghe sự kiện Cảnh báo thời gian thực từ Backend
    _socket!.on('smartAlert', (data) {
      if (mounted) {
        setState(() {
          _unreadAlertsCount++;
        });
        // Hiện thông báo nổi (Top Banner SnackBar) ngay trên màn hình
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: data['type'] == 'OVERLOAD' ? Colors.red.shade800 : Colors.amber.shade900,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(data['title'] ?? 'Có cảnh báo mới!')),
              ],
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _parkingLotsFuture = ApiService.getParkingLots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ParkingHUST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Đại học Bách Khoa Hà Nội', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          // NÚT QUẢ CHUÔNG THÔNG BÁO CÓ BADGE ĐỎ
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: _showNotificationsDialog,
                tooltip: 'Thông báo & Cảnh báo',
              ),
              if (_unreadAlertsCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle),
                    child: Text(
                      '$_unreadAlertsCount',
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Tải lại dữ liệu',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. THẺ GIỚI THIỆU TỔNG QUAN ỨNG DỤNG
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_parking_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ParkingHUST - Nhà xe thông minh',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Hệ thống hỗ trợ sinh viên Bách Khoa theo dõi chỗ trống thời gian thực, gợi ý bãi gửi gần giảng đường, dẫn đường nội khu và quản lý vé xe điện tử.',
                    style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      _OverviewChip(label: '⚡ Thời gian thực'),
                      SizedBox(width: 8),
                      _OverviewChip(label: '🗺️ Dẫn đường'),
                      SizedBox(width: 8),
                      _OverviewChip(label: '🎫 Vé điện tử'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. TIÊU ĐỀ + SỐ LƯỢNG NHÀ XE ĐANG MỞ & DANH SÁCH NHÀ XE TỪ API
            FutureBuilder<List<ParkingLot>>(
              future: _parkingLotsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 40),
                          const SizedBox(height: 8),
                          Text('Lỗi kết nối Backend: ${snapshot.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadData, child: const Text('Thử lại')),
                        ],
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Không có dữ liệu nhà xe'));
                }

                final lots = snapshot.data!;
                final int openCount = lots.where((lot) => lot.isOpen).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HÀNG TIÊU ĐỀ: BÊN TRÁI "Danh sách nhà xe" - BÊN PHẢI "Đang mở: X/Y"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Danh sách nhà xe',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.circle, color: Colors.green, size: 8),
                              const SizedBox(width: 6),
                              Text(
                                'Đang mở: $openCount/${lots.length}',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...lots.map((lot) => _buildParkingCard(lot)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkingCard(ParkingLot lot) {
    // Xác định màu trạng thái dựa trên đóng/mở và tỷ lệ còn trống
    Color statusColor;
    String statusText;
    double freeRatio = lot.availableSlots / lot.totalCapacity;

    if (!lot.isOpen) {
      statusColor = Colors.grey;
      statusText = 'Đã đóng cửa';
    } else if (freeRatio > 0.3) {
      statusColor = Colors.green;
      statusText = 'Còn nhiều chỗ';
    } else if (freeRatio > 0.1) {
      statusColor = Colors.orange;
      statusText = 'Đang đông';
    } else {
      statusColor = Colors.red;
      statusText = 'Sắp đầy';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lot.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      // Nhãn trạng thái đóng/mở cửa của nhà xe
                      Row(
                        children: [
                          Icon(
                            lot.isOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                            size: 13,
                            color: lot.isOpen ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lot.isOpen ? 'Đang mở cửa' : 'Đang đóng cửa',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: lot.isOpen ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
              Row(
              children: [
                const Icon(Icons.two_wheeler, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Đang gửi: ',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                Text(
                  '${lot.totalCapacity - lot.availableSlots}/${lot.totalCapacity} xe',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  'Còn trống: ${lot.availableSlots} chỗ',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Thanh tiến trình thể hiện lượng xe đang đỗ trong nhà xe
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ((lot.totalCapacity - lot.availableSlots) / lot.totalCapacity).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                color: statusColor,
                minHeight: 10, // Dày hơn, dễ nhìn hơn
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Tỷ lệ lấp đầy: ${(((lot.totalCapacity - lot.availableSlots) / lot.totalCapacity) * 100).clamp(0, 100).toInt()}%',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),

            // ĐÃ BỎ NÚT CHỈ ĐƯỜNG -> THAY BẰNG NÚT XEM LƯU LƯỢNG THEO GIỜ
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB71C1C),
                  side: const BorderSide(color: Color(0xFFB71C1C)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TrafficStatsModal(lot: lot),
                  );
                },
                icon: const Icon(Icons.bar_chart_rounded, size: 20),
                label: const Text(
                  'Xem lưu lượng vào/ra theo giờ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog() async {
    final notifs = await ApiService.getNotifications();
    if (!mounted) return;

    // 👉 CHỈ LẤY 5 THÔNG BÁO GẦN ĐÂY NHẤT (DÙNG .take(5)):
    final recentNotifs = notifs.take(5).toList();

    setState(() {
      _unreadAlertsCount = 0; // Đã bấm xem thì xóa số badge đỏ
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: Color(0xFFB71C1C)),
                  SizedBox(width: 10),
                  Text('Trung tâm Cảnh báo & Thông báo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: recentNotifs.isEmpty
                  ? const Center(child: Text('Chưa có cảnh báo nào', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: recentNotifs.length, // <-- DÙNG recentNotifs.length
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = recentNotifs[index]; // <-- DÙNG recentNotifs
                        final isOverload = item['type'] == 'OVERLOAD';
                        final color = isOverload ? Colors.red : (item['type'] == 'CLOSING' ? Colors.amber.shade900 : Colors.blue);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(isOverload ? Icons.error_outline : Icons.info_outline, color: color, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(item['title'], style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(item['message'], style: const TextStyle(fontSize: 12, height: 1.3)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  final String label;
  const _OverviewChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}