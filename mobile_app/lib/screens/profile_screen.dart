import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const ProfileScreen({super.key, this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    setState(() {
      _profileFuture = ApiService.getProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        title: const Text('Tài khoản sinh viên', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          final user = snapshot.data!;
          final vehicle = (user['vehicles'] != null && user['vehicles'].isNotEmpty)
              ? user['vehicles'][0]
              : null;
          final List sessions = (vehicle != null && vehicle['sessions'] != null)
              ? vehicle['sessions']
              : [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. THẺ THÔNG TIN CÁ NHÂN (USER CARD)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.red.shade100,
                          child: const Icon(Icons.person, color: Color(0xFFB71C1C), size: 36),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user['fullName'] ?? 'Sinh viên Bách Khoa', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 4),
                              Text('MSSV: ${user['studentId'] ?? '---'}', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                              Text('${user['email']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. THẺ PHƯƠNG TIỆN ĐÃ ĐĂNG KÝ
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.two_wheeler, color: Color(0xFFB71C1C)),
                                SizedBox(width: 8),
                                Text('Phương tiện đăng ký', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                              child: Text('Đã xác thực', style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        if (vehicle != null) ...[
                          _buildVehicleRow('Biển số xe:', vehicle['plateNumber']),
                          const SizedBox(height: 8),
                          _buildVehicleRow('Dòng xe:', vehicle['model'] ?? 'Chưa rõ'),
                          const SizedBox(height: 8),
                          _buildVehicleRow('Mã thẻ cứng RFID:', vehicle['rfidCardId'] ?? 'Chưa gán thẻ'),
                        ] else
                          const Text('Chưa có phương tiện nào được liên kết'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. LỊCH SỬ GỬI XE GẦN NHẤT
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.history, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Lịch sử gửi xe gần đây', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const Divider(height: 24),
                        if (sessions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Chưa có lịch sử gửi xe', style: TextStyle(color: Colors.grey)),
                          )
                        else
                          Column(
                            children: sessions.map((s) {
                              final lotName = s['parkingLot'] != null ? s['parkingLot']['name'] : 'Bãi xe';

                              // 1. CHUYỂN ĐỔI GIỜ UTC SANG GIỜ ĐỊA PHƯƠNG VIỆT NAM (UTC+7):
                              final dt = DateTime.parse(s['checkInTime'].toString()).toLocal();
                              final timeStr =
                                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                              final dateStr =
                                  '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                                      child: const Icon(Icons.local_parking, size: 18, color: Colors.black54),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(lotName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          // 2. HIỂN THỊ ĐÚNG ĐỊNH DẠNG: Ngày/Tháng/Năm lúc Giờ:Phút
                                          Text('$dateStr lúc $timeStr', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      s['status'] == 'PARKED' ? 'Đang gửi' : 'Đã về',
                                      style: TextStyle(
                                        color: s['status'] == 'PARKED' ? Colors.green : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // NÚT ĐĂNG XUẤT
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (widget.onLogout != null) {
                        widget.onLogout!();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã đăng xuất tài khoản!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVehicleRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}