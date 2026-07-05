import 'package:flutter_riverpod/flutter_riverpod.dart';

class RegistrationFormData {
  // Step 1 — Personal
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String phone;
  final String? email;
  final String? ghanaCardId;

  // Step 2 — Location
  final int? regionId;
  final String? regionName;
  final int? districtId;
  final String? districtName;
  final int? constituencyId;
  final String? constituencyName;
  final int? pollingStationId;
  final String? pollingStationName;
  final String? ward;
  final String? branch;
  final String? residentialAddress;
  final String? residenceTown;

  // Step 3 — Membership
  final String? membershipType;
  final String? preferredRole;
  final String? profession;
  final String? partyPosition;
  final String? otherParty;
  final String? employmentStatus;
  final String? highestQualification;
  final List<String> skills;

  // Step 4 — Photo
  final String? photoLocalPath;
  final String? photoStoragePath;

  const RegistrationFormData({
    this.firstName = '',
    this.lastName = '',
    this.dateOfBirth,
    this.gender,
    this.phone = '',
    this.email,
    this.ghanaCardId,
    this.regionId,
    this.regionName,
    this.districtId,
    this.districtName,
    this.constituencyId,
    this.constituencyName,
    this.pollingStationId,
    this.pollingStationName,
    this.ward,
    this.branch,
    this.residentialAddress,
    this.residenceTown,
    this.membershipType,
    this.preferredRole,
    this.profession,
    this.partyPosition,
    this.otherParty,
    this.employmentStatus,
    this.highestQualification,
    this.skills = const [],
    this.photoLocalPath,
    this.photoStoragePath,
  });

  RegistrationFormData copyWith({
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? gender,
    String? phone,
    String? email,
    String? ghanaCardId,
    bool clearGhanaCardId = false,
    int? regionId,
    String? regionName,
    int? districtId,
    String? districtName,
    int? constituencyId,
    String? constituencyName,
    int? pollingStationId,
    String? pollingStationName,
    String? ward,
    String? branch,
    String? residentialAddress,
    String? residenceTown,
    String? membershipType,
    String? preferredRole,
    String? profession,
    String? partyPosition,
    String? otherParty,
    String? employmentStatus,
    String? highestQualification,
    List<String>? skills,
    String? photoLocalPath,
    String? photoStoragePath,
    bool clearDateOfBirth = false,
    bool clearGender = false,
    bool clearEmail = false,
    bool clearRegion = false,
    bool clearDistrict = false,
    bool clearConstituency = false,
    bool clearPollingStation = false,
    bool clearMembershipType = false,
    bool clearPreferredRole = false,
    bool clearPhoto = false,
  }) {
    return RegistrationFormData(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      gender: clearGender ? null : (gender ?? this.gender),
      phone: phone ?? this.phone,
      email: clearEmail ? null : (email ?? this.email),
      ghanaCardId: clearGhanaCardId ? null : (ghanaCardId ?? this.ghanaCardId),
      regionId: clearRegion ? null : (regionId ?? this.regionId),
      regionName: clearRegion ? null : (regionName ?? this.regionName),
      districtId: clearDistrict ? null : (districtId ?? this.districtId),
      districtName: clearDistrict ? null : (districtName ?? this.districtName),
      constituencyId: clearConstituency ? null : (constituencyId ?? this.constituencyId),
      constituencyName: clearConstituency ? null : (constituencyName ?? this.constituencyName),
      pollingStationId: clearPollingStation ? null : (pollingStationId ?? this.pollingStationId),
      pollingStationName: clearPollingStation ? null : (pollingStationName ?? this.pollingStationName),
      ward: ward ?? this.ward,
      branch: branch ?? this.branch,
      residentialAddress: residentialAddress ?? this.residentialAddress,
      residenceTown: residenceTown ?? this.residenceTown,
      membershipType: clearMembershipType ? null : (membershipType ?? this.membershipType),
      preferredRole: clearPreferredRole ? null : (preferredRole ?? this.preferredRole),
      profession: profession ?? this.profession,
      partyPosition: partyPosition ?? this.partyPosition,
      otherParty: otherParty ?? this.otherParty,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      highestQualification: highestQualification ?? this.highestQualification,
      skills: skills ?? this.skills,
      photoLocalPath: clearPhoto ? null : (photoLocalPath ?? this.photoLocalPath),
      photoStoragePath: clearPhoto ? null : (photoStoragePath ?? this.photoStoragePath),
    );
  }

  Map<String, dynamic> toInsertMap(String registeredBy) {
    final dob = dateOfBirth;
    return {
      'first_name': firstName,
      'last_name': lastName,
      if (dob != null)
        'date_of_birth':
            '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}',
      if (gender != null) 'gender': gender,
      'phone': phone,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (ghanaCardId != null && ghanaCardId!.isNotEmpty) 'ghana_card_id': ghanaCardId,
      if (regionId != null) 'region_id': regionId,
      if (districtId != null) 'district_id': districtId,
      if (constituencyId != null) 'constituency_id': constituencyId,
      if (pollingStationId != null) 'polling_station_id': pollingStationId,
      if (ward != null && ward!.isNotEmpty) 'ward': ward,
      if (branch != null && branch!.isNotEmpty) 'branch': branch,
      if (residentialAddress != null && residentialAddress!.isNotEmpty) 'residential_address': residentialAddress,
      if (residenceTown != null && residenceTown!.isNotEmpty) 'residence_town': residenceTown,
      if (membershipType != null) 'membership_type': membershipType,
      if (preferredRole != null) 'preferred_role': preferredRole,
      if (profession != null && profession!.isNotEmpty) 'profession': profession,
      if (partyPosition != null && partyPosition!.isNotEmpty) 'party_position': partyPosition,
      if (otherParty != null && otherParty!.isNotEmpty) 'other_party': otherParty,
      if (employmentStatus != null) 'employment_status': employmentStatus,
      if (highestQualification != null) 'highest_academic_qualification': highestQualification,
      if (skills.isNotEmpty) 'skills': skills,
      if (photoStoragePath != null && photoStoragePath!.isNotEmpty) 'photo_path': photoStoragePath,
      'registered_by': registeredBy,
      'status': 'pending',
    };
  }

  // Serialise for offline queue (no photo storage path — upload hasn't happened yet)
  Map<String, dynamic> toOfflineJson(String registeredBy) {
    final map = toInsertMap(registeredBy);
    map.remove('photo_path'); // will be set on sync
    return map;
  }
}

class RegistrationFormNotifier extends StateNotifier<RegistrationFormData> {
  RegistrationFormNotifier() : super(const RegistrationFormData());

  void updateStep1({
    required String firstName,
    required String lastName,
    DateTime? dateOfBirth,
    String? gender,
    required String phone,
    String? email,
    String? ghanaCardId,
  }) {
    state = state.copyWith(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      clearDateOfBirth: dateOfBirth == null,
      gender: gender,
      clearGender: gender == null,
      phone: phone,
      email: email,
      ghanaCardId: ghanaCardId,
      clearGhanaCardId: ghanaCardId == null,
    );
  }

  void updateStep2({
    int? regionId,
    String? regionName,
    int? districtId,
    String? districtName,
    int? constituencyId,
    String? constituencyName,
    int? pollingStationId,
    String? pollingStationName,
    String? ward,
    String? branch,
    String? residentialAddress,
    String? residenceTown,
  }) {
    state = state.copyWith(
      regionId: regionId,
      regionName: regionName,
      districtId: districtId,
      districtName: districtName,
      constituencyId: constituencyId,
      constituencyName: constituencyName,
      pollingStationId: pollingStationId,
      pollingStationName: pollingStationName,
      ward: ward,
      branch: branch,
      residentialAddress: residentialAddress,
      residenceTown: residenceTown,
    );
  }

  void updateStep3({
    String? membershipType,
    String? preferredRole,
    String? profession,
    String? partyPosition,
    String? otherParty,
    String? employmentStatus,
    String? highestQualification,
    required List<String> skills,
  }) {
    state = state.copyWith(
      membershipType: membershipType,
      preferredRole: preferredRole,
      profession: profession,
      partyPosition: partyPosition,
      otherParty: otherParty,
      employmentStatus: employmentStatus,
      highestQualification: highestQualification,
      skills: skills,
    );
  }

  void setPhotoLocalPath(String? path) {
    state = state.copyWith(
      photoLocalPath: path,
      clearPhoto: path == null,
    );
  }

  void setPhotoStoragePath(String path) {
    state = state.copyWith(photoStoragePath: path);
  }

  // Clears personal + membership + photo; keeps all location fields.
  // Used by "Save & Add Another" so operators stay on the same station.
  void resetPersonalOnly() {
    state = RegistrationFormData(
      regionId: state.regionId,
      regionName: state.regionName,
      districtId: state.districtId,
      districtName: state.districtName,
      constituencyId: state.constituencyId,
      constituencyName: state.constituencyName,
      pollingStationId: state.pollingStationId,
      pollingStationName: state.pollingStationName,
      ward: state.ward,
      branch: state.branch,
      residentialAddress: state.residentialAddress,
      residenceTown: state.residenceTown,
    );
  }

  void reset() {
    state = const RegistrationFormData();
  }
}

final registrationFormProvider =
    StateNotifierProvider.autoDispose<RegistrationFormNotifier, RegistrationFormData>(
  (ref) => RegistrationFormNotifier(),
);
