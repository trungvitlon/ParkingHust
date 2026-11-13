import 'package:flutter/material.dart';
import '../models/parking_lot.dart';
import '../services/api_service.dart';

// -------------------------------------------------------------
// TAB 2: VÉ XE ĐIỆN TỬ & MÃ QR ĐỊNH DANH (DIGITAL PARKING PASS)
// -------------------------------------------------------------
class ParkingPassScreen extends StatefulWidget {
  const ParkingPassScreen({super.key});

  @override
  State<ParkingPassScreen> createState() => _ParkingPassScreenState();
}

class _ParkingPassScreenState extends State<ParkingPassScreen> {
  int _selectedSubTab = 0; // 0 = Vé xe của bạn, 1 = Lịch sử gửi xe
  late Future<Map<String, dynamic>> _passFuture;
  late Future<Map<String, dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadPass();
  }

  void _loadPass() {
    setState(() {
      _passFuture = ApiService.getParkingPass();
      _historyFuture = ApiService.getProfile(); // Lấy 5 phiên gửi xe gần nhất
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        title: const Text('Thẻ gửi xe điện tử', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPass,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Column(
        children: [
          // THANH 2 NÚT CHUYỂN ĐỔI: VÉ XE CỦA BẠN | LỊCH SỬ GỬI XE
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _buildSubTabButton(
                    index: 0,
                    icon: Icons.qr_code_2,
                    label: 'Vé xe của bạn',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSubTabButton(
                    index: 1,
                    icon: Icons.history,
                    label: 'Lịch sử gửi xe',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // NỘI DUNG TƯƠNG ỨNG VỚI NÚT ĐANG CHỌN
          Expanded(
            child: _selectedSubTab == 0
                ? _buildCurrentPassView()
                : _buildHistoryView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPassView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _passFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final pass = snapshot.data!;
        final bool isParked = pass['status'] == 'PARKED';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.red.shade100,
                            child: const Icon(Icons.two_wheeler, color: Color(0xFFB71C1C)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pass['studentName'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('MSSV: ${pass['studentId']} • ${pass['vehicleModel']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isParked ? Colors.green.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isParked ? Colors.green : Colors.blue),
                            ),
                            child: Text(
                              isParked ? 'ĐANG GỬI XE' : 'CHƯA GỬI',
                              style: TextStyle(
                                color: isParked ? Colors.green.shade800 : Colors.blue.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      // NẾU XE ĐANG TRONG BÃI: HIỂN THỊ CHI TIẾT LƯỢT GỬI
                      if (isParked) ...[
                        Builder(
                          builder: (context) {
                            // 1. Chuyển đổi giờ UTC từ server về Giờ địa phương Việt Nam (UTC+7)
                            final rawTime = pass['session']['checkInTime'];
                            final checkIn = rawTime != null
                                ? DateTime.parse(rawTime.toString()).toLocal()
                                : DateTime.now();

                            // Định dạng Giờ:Phút (HH:mm)
                            final timeStr =
                                '${checkIn.hour.toString().padLeft(2, '0')}:${checkIn.minute.toString().padLeft(2, '0')}';
                            // Định dạng Ngày/Tháng/Năm (dd/MM/yyyy)
                            final dateStr =
                                '${checkIn.day.toString().padLeft(2, '0')}/${checkIn.month.toString().padLeft(2, '0')}/${checkIn.year}';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  // DÒNG 1: VỊ TRÍ NHÀ XE
                                  Row(
                                    children: [
                                      const Text('Vị trí nhà xe:'),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          pass['session']['parkingLotName'],
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // DÒNG 2: THỜI GIAN VÀO (GIỜ : PHÚT)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Thời gian vào:'),
                                      Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // DÒNG 3: NGÀY GỬI XE (NGÀY / THÁNG / NĂM)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Ngày gửi xe:'),
                                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ]

                      // NẾU CHƯA GỬI XE: HIỂN THỊ MÃ QR ĐỘNG ĐỂ CHECK-IN
                      else ...[
                        const Text('MÃ QR CHECK-IN TẠI CỔNG', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.qr_code_2, size: 160, color: Colors.grey.shade800),
                              const SizedBox(height: 8),
                              Text(pass['qrToken'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Biển số xe:'),
                            Text(pass['plateNumber'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

                              // NÚT BẤM GIẢ LẬP VÀO / RA CỔNG
              if (isParked)
                // NẾU XE ĐANG TRONG BÃI -> LUÔN CHO PHÉP QUẸT THẺ RA VỀ
                OutlinedButton.icon(
                  onPressed: () async {
                    await ApiService.toggleCheckIn();
                    _loadPass();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã giả lập xe ra khỏi bãi!')),
                      );
                    }
                  },
                  icon: const Icon(Icons.sensors),
                  label: const Text('Giả lập quẹt thẻ RA về'),
                )
              else
                // NẾU XE ĐANG Ở NGOÀI -> PHẢI ĐẾN NHÀ XE & ẤN CHECK-IN MỚI ĐƯỢC QUẸT THẺ VÀO
                ValueListenableBuilder<ParkingLot?>(
                  valueListenable: ApiService.arrivedLotNotifier,
                  builder: (context, arrivedLot, _) {
                    final bool canCheckIn = arrivedLot != null;

                    return Column(
                      children: [
                        if (canCheckIn)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_on, color: Colors.green, size: 18),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Đã đến: ${arrivedLot.name}',
                                    style: TextStyle(
                                      color: Colors.green.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              '⚠️ Vui lòng dẫn đường đến nhà xe và ấn Check-in để mở khóa quẹt thẻ vào bãi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                            ),
                          ),

                        OutlinedButton.icon(
                          onPressed: canCheckIn
                              ? () async {
                                  await ApiService.toggleCheckIn(parkingLotId: arrivedLot.id);
                                  ApiService.arrivedLotNotifier.value = null; // Xóa trạng thái sau khi vào bãi
                                  _loadPass();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Colors.green,
                                        content: Text('Đã quẹt thẻ VÀO ${arrivedLot.name}!'),
                                      ),
                                    );
                                  }
                                }
                              : null, // <-- Khóa nút (disabled) nếu chưa đến nhà xe
                          icon: const Icon(Icons.sensors),
                          label: Text(
                            canCheckIn
                                ? 'Giả lập quẹt thẻ VÀO ${arrivedLot.name}'
                                : 'Giả lập quẹt thẻ VÀO bãi',
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // Widget tạo nút chuyển tab
  Widget _buildSubTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = _selectedSubTab == index;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        elevation: isSelected ? 2 : 0,
        backgroundColor: isSelected ? const Color(0xFFB71C1C) : Colors.grey.shade100,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () {
        setState(() => _selectedSubTab = index);
      },
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  // TRANG LỊCH SỬ GỬI XE (MẶC ĐỊNH 5 THẺ GẦN NHẤT + THỜI GIAN RA)
  Widget _buildHistoryView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)));
        } else if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final user = snapshot.data!;
        final vehicle = (user['vehicles'] != null && user['vehicles'].isNotEmpty)
            ? user['vehicles'][0]
            : null;
        final List sessions = (vehicle != null && vehicle['sessions'] != null)
            ? (vehicle['sessions'] as List).take(5).toList()
            : [];

        if (sessions.isEmpty) {
          return const Center(
            child: Text('Bạn chưa có lịch sử gửi xe nào.', style: TextStyle(color: Colors.grey)),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadPass(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final s = sessions[index];
              final bool isParked = s['status'] == 'PARKED';
              final String lotName = s['parkingLot'] != null ? s['parkingLot']['name'] : 'Nhà xe';

              final DateTime checkInDt = DateTime.parse(s['checkInTime'].toString()).toLocal();
              final String dateStr = _formatDate(checkInDt);
              final String timeInStr = _formatTime(checkInDt);

              String timeOutStr = 'Chưa ra (Đang gửi)';
              if (s['checkOutTime'] != null) {
                final DateTime checkOutDt = DateTime.parse(s['checkOutTime'].toString()).toLocal();
                timeOutStr = '${_formatTime(checkOutDt)} (${_formatDate(checkOutDt)})';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dòng tiêu đề: Tên nhà xe + Trạng thái
                      Row(
                        children: [
                          const Icon(Icons.local_parking, color: Color(0xFFB71C1C), size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lotName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isParked ? Colors.green.shade50 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isParked ? Colors.green : Colors.grey.shade400),
                            ),
                            child: Text(
                              isParked ? 'ĐANG GỬI XE' : 'ĐÃ RA BÃI',
                              style: TextStyle(
                                color: isParked ? Colors.green.shade800 : Colors.black54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Chi tiết thẻ gửi xe
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isParked ? Colors.green.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            _buildHistoryRow('Biển số xe:', vehicle['plateNumber'] ?? '---'),
                            const SizedBox(height: 6),
                            _buildHistoryRow('Ngày gửi:', dateStr),
                            const SizedBox(height: 6),
                            _buildHistoryRow('Thời gian vào:', timeInStr),
                            const SizedBox(height: 6),
                            _buildHistoryRow(
                              'Thời gian ra:',
                              timeOutStr,
                              valueColor: isParked ? Colors.green.shade700 : Colors.black87,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: valueColor ?? Colors.black87),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}