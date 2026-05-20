class UserModel {
  final String id;
  final String email;
  final String role;
  final String? orgId;
  final String? orgName;
  final String? orgLogo;
  final String? employeeId;
  final String? empCode;
  final String? name;
  final String? photo;
  final String? department;
  final String? designation;

  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.orgId,
    this.orgName,
    this.orgLogo,
    this.employeeId,
    this.empCode,
    this.name,
    this.photo,
    this.department,
    this.designation,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'] as Map<String, dynamic>?;
    return UserModel(
      id: json['id'],
      email: json['email'],
      role: json['role'],
      orgId: json['orgId'],
      orgName: json['orgName'],
      orgLogo: json['orgLogo'],
      employeeId: emp?['id'] ?? json['employeeId'],
      empCode: emp?['empCode'] ?? json['empCode'],
      name: emp?['name'] ?? json['name'],
      photo: emp?['photo'] ?? json['photo'],
      department: emp?['department'] ?? json['department'],
      designation: emp?['designation'] ?? json['designation'],
    );
  }

  bool get isSuperAdmin => role == 'super_admin';
  bool get isHR => role == 'hr';
  bool get isManager => role == 'manager';
  bool get isEmployee => role == 'employee';
  bool get canManagePayroll => isSuperAdmin || isHR;
  bool get canApproveLeave => isSuperAdmin || isHR || isManager;
  bool get canViewAllEmployees => isSuperAdmin || isHR;
}
