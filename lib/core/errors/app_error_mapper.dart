import 'package:flutter/foundation.dart';

/// Central error → friendly-message converter.
///
/// Every caught error that will be shown to a user must go through this class.
/// Raw exceptions, URLs, provider names, and status codes are NEVER forwarded
/// to UI. In debug mode the full error + stack are printed to console.
class AppErrorMapper {
  AppErrorMapper._();

  // ── Auth errors (login / signup / Google sign-in) ─────────────────────────

  /// Maps any auth-layer exception to a short, safe user-facing string.
  /// Returns null when the error should be shown silently (e.g. user cancel).
  static String? forAuth(Object e, [StackTrace? st]) {
    _log('Auth', e, st);
    final s = e.toString();

    // User cancelled Google sign-in — no banner needed
    if (s.contains('sign_in_cancelled') ||
        (s.contains('cancelled') && s.contains('google')) ||
        s.contains('PlatformException(sign_in_cancelled')) {
      return null;
    }

    // Network / connection failures
    if (_isNetwork(s)) {
      return "Couldn't reach the server. Check your connection and try again.";
    }

    // Already registered
    if (s.contains('user_already_exists') ||
        s.contains('User already registered') ||
        s.contains('already been registered') ||
        s.contains('already registered')) {
      return 'This email already has an account. Sign in instead.';
    }

    // Weak password
    if (s.contains('weak_password') || s.contains('Password should be')) {
      return 'Use at least 8 characters for your password.';
    }

    // Invalid email format
    if (s.toLowerCase().contains('invalid') && s.toLowerCase().contains('email')) {
      return 'Enter a valid email address.';
    }

    // Wrong credentials
    if (s.contains('Invalid login credentials') ||
        s.contains('invalid_credentials') ||
        s.contains('invalid login')) {
      return 'Email or password is incorrect.';
    }

    // Email not confirmed
    if (s.contains('Email not confirmed') || s.contains('email_not_confirmed')) {
      return 'Confirm your email first, then sign in.';
    }

    // Rate limiting
    if (s.contains('Too many requests') || s.contains('rate_limit')) {
      return 'Too many attempts. Wait a moment and try again.';
    }

    // Server / DB error from signup trigger
    if (s.contains('Database error saving new user') ||
        s.contains('unexpected_failure') ||
        s.contains('statusCode: 500') ||
        s.contains('500')) {
      return "We couldn't complete that right now. Please try again in a moment.";
    }

    // Google ApiException:10 (DEVELOPER_ERROR) or other Google failures
    if (s.contains('ApiException: 10') ||
        s.contains('ApiException: 12') ||
        s.contains('sign_in_failed') ||
        s.contains('com.google.android.gms')) {
      return "Google sign-in didn't work. Try again or use email instead.";
    }

    // Fallback — safe generic message, no raw details
    return "Something didn't work. Please try again.";
  }

  // ── Data-loading errors (list screens, paginated queries) ─────────────────

  static String forDataLoad(Object e, [StackTrace? st]) {
    _log('DataLoad', e, st);
    if (_isNetwork(e.toString())) {
      return "No connection. Pull down to retry.";
    }
    return "Couldn't load data. Pull down to retry.";
  }

  // ── General-purpose friendly message ─────────────────────────────────────

  static String friendly(Object e, [StackTrace? st]) {
    _log('General', e, st);
    if (_isNetwork(e.toString())) {
      return "No connection. Check your network and try again.";
    }
    return "Something went wrong. Please try again.";
  }

  // ── Admin / operator action errors ────────────────────────────────────────

  static String forAdminAction(Object e, [StackTrace? st]) {
    _log('AdminAction', e, st);
    if (_isNetwork(e.toString())) {
      return "No connection. Check your network and try again.";
    }
    return "Action failed. Please try again.";
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _isNetwork(String s) {
    return s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Software caused connection abort') ||
        s.contains('connection abort') ||
        s.contains('AuthRetryableFetchException') ||
        s.contains('Connection refused') ||
        s.contains('network') ||
        s.contains('timeout') ||
        s.contains('timed out') ||
        s.contains('host lookup') ||
        s.contains('statusCode: null');
  }

  static void _log(String context, Object e, StackTrace? st) {
    debugPrint('[$context error] $e');
    if (st != null) debugPrint('$st');
  }
}
