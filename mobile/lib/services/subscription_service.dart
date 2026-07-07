import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/gateways.dart';
import '../data/models/subscription_status.dart';
import '../data/subscription_repository.dart';

class SubscriptionService extends ChangeNotifier {
  SubscriptionService(this._repository, this._gateway);

  final SubscriptionRepository _repository;
  final SubscriptionGateway _gateway;

  SubscriptionStatus _status = SubscriptionStatus.free;
  bool _loaded = false;
  bool _inProgress = false;

  SubscriptionStatus get status => _status;
  bool get isLoaded => _loaded;
  bool get isInProgress => _inProgress;
  bool get isPro => _status.isProAt(DateTime.now());

  Future<void> load() async {
    _status = await _repository.load() ?? SubscriptionStatus.free;
    _loaded = true;
    notifyListeners();
  }

  /// Re-reads the entitlement from the server. Requires a signed-in ApiClient;
  /// silently keeps the cached state when offline.
  Future<void> refresh() async {
    try {
      await _apply(await _gateway.fetch());
    } on ApiException {
      // Keep the cached snapshot; isProAt() still enforces expiry locally.
    }
  }

  /// Mock purchase flow — replaced by store billing later. Returns true when
  /// Pro was activated.
  Future<bool> purchasePro() async {
    return _run(() => _gateway.activateMock());
  }

  /// Turns off renewal; entitlement stays until the expiry date.
  Future<bool> cancel() async {
    return _run(() => _gateway.cancel());
  }

  /// Drops the cached entitlement (sign-out).
  Future<void> clearLocal() async {
    _status = SubscriptionStatus.free;
    await _repository.clear();
    notifyListeners();
  }

  Future<bool> _run(Future<SubscriptionStatus> Function() action) async {
    _inProgress = true;
    notifyListeners();
    try {
      await _apply(await action());
      return true;
    } on ApiException {
      return false;
    } finally {
      _inProgress = false;
      notifyListeners();
    }
  }

  Future<void> _apply(SubscriptionStatus status) async {
    _status = status;
    await _repository.save(status);
    notifyListeners();
  }
}
