import 'package:flutter/foundation.dart';

import '../data/gateways.dart';
import '../data/settings_repository.dart';
import '../domain/entitlement.dart';

/// Pro entitlement state. The server row is the truth; a local cache keeps
/// Pro working offline and self-downgrades once [Entitlement.expiresAt]
/// passes. All billing goes through the RevenueCat-shaped [PurchaseGateway].
class EntitlementService extends ChangeNotifier {
  EntitlementService(
    this._settings,
    this._purchases, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SettingsRepository _settings;
  final PurchaseGateway _purchases;
  final DateTime Function() _clock;

  Entitlement? _entitlement;
  bool _loaded = false;
  bool _inProgress = false;

  Entitlement? get entitlement => _entitlement;
  bool get isLoaded => _loaded;
  bool get isInProgress => _inProgress;
  bool get isPro => _entitlement?.isProAt(_clock()) ?? false;

  Future<void> load() async {
    _entitlement = await _settings.cachedEntitlement();
    _loaded = true;
    notifyListeners();
  }

  /// Re-reads the entitlement from the server; keeps the cache when offline.
  Future<void> refresh() async {
    try {
      await _apply(await _purchases.fetch());
    } on CloudUnavailable {
      // Cached state stands; isPro still enforces expiry locally.
    }
  }

  /// Returns true when Pro was activated.
  Future<bool> purchasePro() => _run(() => _purchases.purchasePro());

  /// Turns off renewal; Pro keeps working until expiry.
  Future<bool> cancelPro() => _run(() => _purchases.cancelPro());

  Future<void> clearLocal() async {
    await _apply(null);
  }

  Future<bool> _run(Future<Entitlement> Function() action) async {
    _inProgress = true;
    notifyListeners();
    try {
      await _apply(await action());
      return true;
    } on CloudUnavailable {
      return false;
    } finally {
      _inProgress = false;
      notifyListeners();
    }
  }

  Future<void> _apply(Entitlement? entitlement) async {
    _entitlement = entitlement;
    await _settings.cacheEntitlement(entitlement);
    notifyListeners();
  }
}
