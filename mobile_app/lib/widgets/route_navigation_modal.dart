import 'package:flutter/material.dart';
import '../models/parking_lot.dart';
import '../screens/search_screen.dart'; // Để lấy thông tin CampusBuilding
import '../screens/navigation_screen.dart';

class RouteNavigationModal extends StatelessWidget {
  final ParkingLot lot;
  final CampusBuilding building;
  final double distance;
  final int walkingMinutes;

  const RouteNavigationModal({
    super.key,
    required this.lot,
    required this.building,
    required this.distance,
    required this.walkingMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Thanh gạt modal
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),

          // TIÊU ĐỀ LỘ TRÌNH
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.route, color: Color(0xFFB71C1C), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lộ trình đến ${building.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Điểm gửi: ${lot.name}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const Divider(),

          // NỘI DUNG CHI TIẾT CÁC CHẶNG
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // THỐNG SỐ TỔNG QUAN
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRouteStat(Icons.timer_outlined, 'Tổng thời gian', '~${walkingMinutes + 4} phút'),
                      Container(height: 30, width: 1, color: Colors.red.shade200),
                      _buildRouteStat(Icons.directions_walk, 'Đi bộ nội khu', '${distance.toInt()}m (~$walkingMinutes ph)'),
                      Container(height: 30, width: 1, color: Colors.red.shade200),
                      _buildRouteStat(Icons.local_parking, 'Chỗ trống', '${lot.availableSlots} chỗ'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text('HƯỚNG DẪN TỪNG CHẶNG DI CHUYỂN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, letterSpacing: 1.1)),
                const SizedBox(height: 14),

                // CHẶNG 1: ĐI XE MÁY ĐẾN BÃI
                _buildStepItem(
                  icon: Icons.two_wheeler,
                  color: Colors.blue,
                  title: 'Chặng 1: Di chuyển xe máy đến ${lot.name}',
                  subtitle: 'Đi theo cổng chính khuôn viên (Đại Cồ Việt/Trần Đại Nghĩa) rẽ vào làn gửi xe.',
                  isLast: false,
                ),

                // CHẶNG 2: GỬI XE TẠI BÃI
                _buildStepItem(
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  title: 'Chặng 2: Check-in & Để xe tại bãi',
                  subtitle: 'Quẹt thẻ sinh viên tại cổng barrier (${lot.name} hiện còn ${lot.availableSlots} chỗ trống).',
                  isLast: false,
                ),

                // CHẶNG 3: ĐI BỘ VÀO GIẢNG ĐƯỜNG
                _buildStepItem(
                  icon: Icons.directions_walk,
                  color: const Color(0xFFB71C1C),
                  title: 'Chặng 3: Đi bộ vào ${building.name}',
                  subtitle: 'Khoảng cách ${distance.toInt()} mét. Đi theo hành lang nội bộ rẽ vào sảnh chính.',
                  isLast: true,
                ),
              ],
            ),
          ),

          // NÚT BẮT ĐẦU CHỈ ĐƯỜNG
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  // 1. Chờ kết quả trả về từ màn hình dẫn đường
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NavigationScreen(
                        lot: lot,
                        building: building,
                      ),
                    ),
                  );

                  // 2. Nếu người dùng bấm "MỞ CHECK-IN NGAY" (trả về 'open_ticket')
                  if (result == 'open_ticket' && context.mounted) {
                    Navigator.pop(context); // Đóng modal lộ trình lại
                    
                    // Tìm đến thanh điều hướng chính và chuyển thẳng sang Tab 1 (Tab Vé xe)
                    // (Lưu ý: Tab 1 tương ứng với Tab thứ hai - Vé xe)
                    final navState = context.findAncestorStateOfType<State<StatefulWidget>>();
                    // Hoặc dùng thông báo mở vé xe:
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('🎉 Bạn đã đến nhà xe! Vui lòng chọn Tab "Vé xe" để quét mã Check-in.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.navigation),
                label: const Text('Bắt đầu lộ trình', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFB71C1C)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildStepItem({required IconData icon, required Color color, required String title, required String subtitle, required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 18),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 44,
                color: Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.3)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}