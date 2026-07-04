import 'package:supabase_flutter/supabase_flutter.dart';

class MemberDetail {
  final String id;
  final String? memberNumber;
  final String firstName;
  final String lastName;
  final String? dateOfBirth;
  final String? gender;
  final String? phone;
  final String? email;
  final String? regionName;
  final String? districtName;
  final String? constituencyName;
  final String? pollingStationName;
  final String? ward;
  final String? branch;
  final String? membershipType;
  final String? preferredRole;
  final String? profession;
  final String? employmentStatus;
  final String? highestAcademicQualification;
  final List<String> skills;
  final String? photoPath;
  final String status;
  final String? rejectionReason;
  final String? residentialAddress;
  final String? residenceTown;
  final String? partyPosition;
  final String? otherParty;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemberDetail({
    required this.id,
    this.memberNumber,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.gender,
    this.phone,
    this.email,
    this.regionName,
    this.districtName,
    this.constituencyName,
    this.pollingStationName,
    this.ward,
    this.branch,
    this.membershipType,
    this.preferredRole,
    this.profession,
    this.employmentStatus,
    this.highestAcademicQualification,
    this.skills = const [],
    this.photoPath,
    required this.status,
    this.rejectionReason,
    this.residentialAddress,
    this.residenceTown,
    this.partyPosition,
    this.otherParty,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$firstName $lastName';

  factory MemberDetail.fromMap(Map<String, dynamic> m) {
    return MemberDetail(
      id: m['id'] as String,
      memberNumber: m['member_number'] as String?,
      firstName: m['first_name'] as String,
      lastName: m['last_name'] as String,
      dateOfBirth: m['date_of_birth'] as String?,
      gender: m['gender'] as String?,
      phone: m['phone'] as String?,
      email: m['email'] as String?,
      regionName: (m['regions'] as Map<String, dynamic>?)?['name'] as String?,
      districtName: (m['districts'] as Map<String, dynamic>?)?['name'] as String?,
      constituencyName: (m['constituencies'] as Map<String, dynamic>?)?['name'] as String?,
      pollingStationName: (m['polling_stations'] as Map<String, dynamic>?)?['name'] as String?,
      ward: m['ward'] as String?,
      branch: m['branch'] as String?,
      membershipType: m['membership_type'] as String?,
      preferredRole: m['preferred_role'] as String?,
      profession: m['profession'] as String?,
      employmentStatus: m['employment_status'] as String?,
      highestAcademicQualification: m['highest_academic_qualification'] as String?,
      skills: (m['skills'] as List?)?.map((e) => e as String).toList() ?? [],
      photoPath: m['photo_path'] as String?,
      status: m['status'] as String,
      rejectionReason: m['rejection_reason'] as String?,
      residentialAddress: m['residential_address'] as String?,
      residenceTown: m['residence_town'] as String?,
      partyPosition: m['party_position'] as String?,
      otherParty: m['other_party'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }
}

class AuditEntry {
  final int id;
  final String action;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.metadata,
    required this.createdAt,
  });

  factory AuditEntry.fromMap(Map<String, dynamic> m) {
    return AuditEntry(
      id: m['id'] as int,
      action: m['action'] as String,
      metadata: (m['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  String get humanAction => switch (action) {
        'member_created' => 'Member registered',
        'member_status_changed' => 'Status changed',
        'member_updated' => 'Record updated',
        _ => action.replaceAll('_', ' '),
      };
}

class ReviewRepository {
  final _db = Supabase.instance.client;

  static const _memberDetailSelect = '''
    id, member_number, first_name, last_name, date_of_birth, gender,
    phone, email, ward, branch, membership_type, preferred_role,
    profession, employment_status, highest_academic_qualification,
    skills, photo_path, status, rejection_reason, created_at, updated_at,
    regions(name), districts(name), constituencies(name), polling_stations(name)
  ''';

  Future<List<MemberDetail>> fetchPendingMembers({
    required int page,
    int pageSize = 20,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final data = await _db
        .from('members')
        .select(_memberDetailSelect)
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .range(from, to);
    return (data as List)
        .map((m) => MemberDetail.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<MemberDetail>> searchMembers({
    required int page,
    String? query,
    String? statusFilter,
    int? constituencyId,
    int pageSize = 20,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    // Build filter chain before .order()/.range() so we stay on PostgrestFilterBuilder.
    // Names: ILIKE with leading wildcard — uses pg_trgm GIN index (idx_members_name_trgm).
    // Phone/member_number: prefix-only ILIKE (no leading %) — uses btree indexes.
    var q = _db.from('members').select(_memberDetailSelect);

    if (query != null && query.trim().isNotEmpty) {
      final s = query.trim();
      q = q.or(
        'first_name.ilike.%$s%,'
        'last_name.ilike.%$s%,'
        'phone.ilike.$s%,'
        'member_number.ilike.$s%',
      );
    }

    if (statusFilter != null && statusFilter != 'all') {
      q = q.eq('status', statusFilter);
    }

    if (constituencyId != null) {
      q = q.eq('constituency_id', constituencyId);
    }

    final data = await q
        .order('created_at', ascending: false)
        .range(from, to);

    return (data as List)
        .map((m) => MemberDetail.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<MemberDetail> fetchMemberDetail(String id) async {
    final data = await _db
        .from('members')
        .select(_memberDetailSelect)
        .eq('id', id)
        .single();
    return MemberDetail.fromMap(data);
  }

  Future<void> approveMember(String memberId) async {
    await _db.from('members').update({
      'status': 'active',
      'reviewed_by': _db.auth.currentUser!.id,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', memberId);
  }

  Future<void> rejectMember(String memberId, String reason) async {
    await _db.from('members').update({
      'status': 'rejected',
      'reviewed_by': _db.auth.currentUser!.id,
      'rejection_reason': reason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', memberId);
  }

  Future<List<AuditEntry>> fetchAuditHistory(String memberId) async {
    final data = await _db
        .from('audit_log')
        .select('id, action, metadata, created_at')
        .eq('target_id', memberId)
        .order('created_at', ascending: false)
        .limit(20);
    return (data as List)
        .map((m) => AuditEntry.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> triggerExport({
    String? statusFilter,
    String? searchQuery,
    String? authToken,
    required String railwayUrl,
  }) async {
    // Implemented in capture_metadata_service pattern — fire & receive bytes
    // Export handled in the screen layer via ExportService
  }
}
