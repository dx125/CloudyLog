import 'package:flutter/foundation.dart';

import '../data/gateways.dart';

/// Session state. Users start anonymous (no sign-up friction) and upgrade in
/// place with an email when they go Pro — same user id, data continuity free.
/// Everything degrades gracefully offline: no session just means no cloud.
class AuthService extends ChangeNotifier {
  AuthService(this._gateway);

  final AuthGateway _gateway;

  bool get isConfigured => _gateway.isConfigured;
  AuthAccount? get account => _gateway.current;
  bool get hasSession => account != null;
  bool get isAnonymous => account?.isAnonymous ?? true;

  /// Best-effort anonymous session; called in the background at startup and
  /// retried before any cloud action. Never throws.
  Future<bool> ensureSession() async {
    try {
      await _gateway.ensureSession();
      notifyListeners();
      return hasSession;
    } on CloudUnavailable {
      return false;
    }
  }

  /// Attaches email+password to the anonymous account. Returns false when
  /// the cloud is unreachable or the upgrade is rejected.
  Future<bool> upgrade({required String email, required String password}) async {
    try {
      await _gateway.upgrade(email: email, password: password);
      notifyListeners();
      return true;
    } on CloudUnavailable {
      return false;
    }
  }

  /// Signs in to an existing account (reclaiming Pro on a new phone). Returns
  /// false when the cloud is unreachable or the credentials are rejected.
  Future<bool> signIn({required String email, required String password}) async {
    try {
      await _gateway.signIn(email: email, password: password);
      notifyListeners();
      return true;
    } on CloudUnavailable {
      return false;
    }
  }

  /// Ends the session; a fresh anonymous one takes its place so the core loop
  /// keeps working. Pro is account-bound, so callers drop the local
  /// entitlement mirror alongside this.
  Future<bool> signOut() async {
    try {
      await _gateway.signOut();
      notifyListeners();
      return true;
    } on CloudUnavailable {
      return false;
    }
  }

  /// Total cloud deletion (account + everything cascading from it).
  Future<bool> deleteAccount() async {
    try {
      await _gateway.deleteAccount();
      notifyListeners();
      return true;
    } on CloudUnavailable {
      return false;
    }
  }
}
