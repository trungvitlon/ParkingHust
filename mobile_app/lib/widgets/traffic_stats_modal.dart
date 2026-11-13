import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/parking_lot.dart';
import '../services/api_service.dart';

class TrafficStatsModal extends StatefulWidget {
  final ParkingLot lot;

  const TrafficStatsModal({super.key, required this.lot});

  @override
  State<TrafficStatsModal> createState() => _TrafficStatsModalState();
}

class _TrafficStatsModalState extends State<TrafficStatsModal> {
  String _range = 'today';
  late Future<Map<String, dynamic>> _trafficFuture;
  int? _selectedIndex;
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _loadTraffic();
    _connectSocket();
  }

  void _connectSocket() {
    _socket = io.io(
      ApiService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew() // <-- QUAN TRỌNG: Tạo kết nối riêng, không làm đứt socket của HomeScreen khi đóng modal
          .enableAutoConnect()
          .build(),
    );

    _socket!.on('parkingUpdated', (data) {
      // Đúng tên trường 'lotId' từ Backend và đúng nhà xe đang xem mới reload
      if (mounted && data is Map && data['lotId'] == widget.lot.id) {
        _loadTraffic();
      }
    });
  }

  @override
  void dispose() {
    _socket?.dispose(); // <-- Ngắt kết nối khi đóng modal
    super.dispose();
  }

  void _loadTraffic() {
    setState(() {
      _selectedIndex = null;
      _trafficFuture = ApiService.getParkingTraffic(widget.lot.id, range: _range);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          // Tiêu đề + Bộ chọn Hôm nay / 7 ngày
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded, color: Color(0xFFB71C1C), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lưu lượng xe theo giờ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(widget.lot.name, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                ChoiceChip(
                  label: const Text('Hôm nay', style: TextStyle(fontSize: 11)),
                  selected: _range == 'today',
                  onSelected: (_) {
                    _range = 'today';
                    _loadTraffic();
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('7 ngày', style: TextStyle(fontSize: 11)),
                  selected: _range == 'week',
                  onSelected: (_) {
                    _range = 'week';
                    _loadTraffic();
                  },
                ),
              ],
            ),
          ),
          const Divider(),

          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _trafficFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)));
                } else if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                final data = snapshot.data!;
                final List hourly = data['hourly'] ?? [];
                int maxVal = 1;
                for (final item in hourly) {
                  final inC = item['inCount'] as int;
                  final outC = item['outCount'] as int;
                  if (inC > maxVal) maxVal = inC;
                  if (outC > maxVal) maxVal = outC;
                }

                final selectedItem = _selectedIndex != null ? hourly[_selectedIndex!] : null;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 3 Thẻ tóm tắt KPI
                    Row(
                      children: [
                        _buildKpiCard('Tổng vào', '${data['totalIn']} xe', Colors.blue),
                        const SizedBox(width: 8),
                        _buildKpiCard('Tổng ra', '${data['totalOut']} xe', Colors.orange),
                        const SizedBox(width: 8),
                        _buildKpiCard('Cao điểm vào', '${data['peakInHour']}', const Color(0xFFB71C1C)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Chú thích màu sắc
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegend(Colors.blue.shade600, 'Xe vào (Check-in)'),
                        const SizedBox(width: 20),
                        _buildLegend(Colors.orange.shade600, 'Xe ra (Check-out)'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Biểu đồ cột đôi vuốt ngang (06h - 22h)
                    Container(
                      height: 220,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: hourly.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = hourly[index];
                          final int inCount = item['inCount'];
                          final int outCount = item['outCount'];
                          final bool isSelected = _selectedIndex == index;
                          const double maxBarHeight = 140.0;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedIndex = index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.red.shade50 : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _buildBar((inCount / maxVal) * maxBarHeight, Colors.blue.shade600),
                                      const SizedBox(width: 3),
                                      _buildBar((outCount / maxVal) * maxBarHeight, Colors.orange.shade600),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['label'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? const Color(0xFFB71C1C) : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Khung chi tiết khi chạm vào 1 cột giờ
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app, color: Colors.blue, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedItem != null
                                  ? 'Khung ${selectedItem['label']} - ${(selectedItem['hour'] + 1).toString().padLeft(2, '0')}h: '
                                    '${selectedItem['inCount']} xe vào • ${selectedItem['outCount']} xe ra'
                                  : 'Chạm vào một cột giờ bất kỳ trên biểu đồ để xem số xe chi tiết.',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double height, Color color) {
    return Container(
      width: 11,
      height: height < 4 ? 4 : height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }
}