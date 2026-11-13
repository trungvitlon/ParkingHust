class ParkingLot {
  final String id;
  final String name;
  final int totalCapacity;
  final int reservedQuota;
  final int availableSlots;
  final double latitude;
  final double longitude;
  final bool isOpen;

  ParkingLot({
    required this.id,
    required this.name,
    required this.totalCapacity,
    required this.reservedQuota,
    required this.availableSlots,
    required this.latitude,
    required this.longitude,
    required this.isOpen,
  });

  // Tỷ lệ còn trống (để hiển thị màu sắc Xanh / Vàng / Đỏ)
  double get occupancyRate => (totalCapacity - availableSlots) / totalCapacity;

  factory ParkingLot.fromJson(Map<String, dynamic> json) {
    return ParkingLot(
      id: json['id'],
      name: json['name'],
      totalCapacity: json['totalCapacity'],
      reservedQuota: json['reservedQuota'],
      availableSlots: json['availableSlots'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isOpen: json['isOpen'] ?? true,
    );
  }
}