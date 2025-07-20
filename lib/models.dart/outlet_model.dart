class Outlet {
  final String outletId;
  final String name;
  final String location;
  final String image;
  final String price;

  Outlet({
    required this.outletId,
    required this.name,
    required this.location,
    required this.image,
    required this.price,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      outletId: json['outletId'] ?? '',
      name: json['Place_Available'] ?? '',
      location: json['Place_Location'] ?? '',
      image: json['Image'] ?? '',
      price: json['Price']?.toString() ?? '',
    );
  }

  /// 🔧 NEW METHOD: for Firebase usage with document ID
  factory Outlet.fromFirestore(Map<String, dynamic> data, String docId) {
    return Outlet(
      outletId: docId, // <-- from Firestore document ID
      name: data['Place_Available'] ?? '',
      location: data['Place_Location'] ?? '',
      image: data['Image'] ?? '',
      price: data['Price']?.toString() ?? '',
    );
  }
}
