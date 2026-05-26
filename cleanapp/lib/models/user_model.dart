class UserModel {
  final int id;
  final String name;
  final String role; // 'driver' or 'outsource'
  final String phone;
  final int? vehicleId;
  final String? vehicleName;

  UserModel({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    this.vehicleId,
    this.vehicleName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
      role: json['role'] ?? 'outsource',
      phone: json['phone'] ?? '',
      vehicleId: json['vehicleId'],
      vehicleName: json['vehicleName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'phone': phone,
      'vehicleId': vehicleId,
      'vehicleName': vehicleName,
    };
  }

  bool get isDriver => role.toLowerCase() == 'driver';
  bool get isOutsource => role.toLowerCase() == 'outsource';
}
