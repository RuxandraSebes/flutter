class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? cnpPacient;
  final int? hospitalId;
  final Map<String, dynamic>? hospital;
  final String? specialization;
  final String? licenseNumber;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.cnpPacient,
    this.hospitalId,
    this.hospital,
    this.specialization,
    this.licenseNumber,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        role: json['role'] ?? 'patient',
        cnpPacient: json['cnp_pacient'],
        hospitalId: json['hospital_id'],
        hospital: json['hospital'] != null
            ? Map<String, dynamic>.from(json['hospital'])
            : null,
        specialization: json['specialization'],
        licenseNumber: json['license_number'],
        isActive: json['is_active'] ?? true,
      );

  // ── Role checks ────────────────────────────────────────────────────────────

  bool get isGlobalAdmin => role == 'global_admin';
  bool get isHospitalAdmin => role == 'hospital_admin';
  bool get isDoctor => role == 'doctor';
  bool get isPatient => role == 'patient';
  bool get isCompanion => role == 'companion';

  bool get canManageUsers => isGlobalAdmin || isHospitalAdmin;
  bool get canViewAllPatients => isGlobalAdmin || isHospitalAdmin || isDoctor;
  bool get canUploadForPatient => isGlobalAdmin || isHospitalAdmin || isDoctor;

  String get roleLabel {
    switch (role) {
      case 'global_admin':
        return 'Administrator Global';
      case 'hospital_admin':
        return 'Administrator Spital';
      case 'doctor':
        return 'Medic';
      case 'patient':
        return 'Pacient';
      case 'companion':
        return 'Însoțitor';
      default:
        return role;
    }
  }

  String get hospitalName => hospital?['name'] ?? '—';
}
