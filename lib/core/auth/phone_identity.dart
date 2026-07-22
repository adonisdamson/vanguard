/// Phone-as-login identity.
///
/// Most Tema West executives have no email, so they sign in with their phone
/// number. We map a normalized Ghana phone to a synthetic internal email
/// (`{phone}@temawest.local`) and reuse the existing Supabase email/password
/// auth engine unchanged. Existing email accounts (e.g. the system admin) still
/// sign in with their real email — the login screen routes on whether the input
/// contains "@".
class PhoneIdentity {
  PhoneIdentity._();

  /// Internal domain for synthetic emails. Never shown to users.
  static const domain = 'temawest.local';

  /// Shared default password for bulk-onboarded operators. They are forced to
  /// change it on first login (must_change_password).
  static const defaultPassword = 'temawestndc2026!';

  /// Normalize a Ghana phone to canonical `0XXXXXXXXX` (10 digits), fixing the
  /// common `O`→`0` typo and `+233`/`233` prefixes. Returns null if it can't be
  /// made into a valid 10-digit Ghana number.
  static String? normalize(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    // Common data-entry typo: letter O/o used for zero.
    s = s.replaceAll('O', '0').replaceAll('o', '0');
    // Keep leading + then digits only.
    final hasPlus = s.startsWith('+');
    s = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (hasPlus && s.startsWith('233')) {
      s = '0${s.substring(3)}';
    } else if (s.startsWith('233') && s.length == 12) {
      s = '0${s.substring(3)}';
    }
    return RegExp(r'^0\d{9}$').hasMatch(s) ? s : null;
  }

  /// Synthetic login email for an already-normalized phone.
  static String emailForPhone(String normalizedPhone) =>
      '$normalizedPhone@$domain';

  /// Raw phone → synthetic email, or null when the phone is invalid.
  static String? emailForRawPhone(String raw) {
    final n = normalize(raw);
    return n == null ? null : emailForPhone(n);
  }

  /// Resolve any login identifier to the email Supabase expects:
  /// - contains "@"  → treat as a real email (existing accounts, e.g. admin)
  /// - otherwise     → treat as a phone and map to the synthetic email
  /// Returns null if it's neither a valid email nor a valid phone.
  static String? resolveToEmail(String identifier) {
    final id = identifier.trim();
    if (id.contains('@')) return id.isEmpty ? null : id;
    return emailForRawPhone(id);
  }
}
