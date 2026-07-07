import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_client.dart';
import '../../data/gateways.dart';
import '../../data/models/today_stats.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/login_service.dart';

/// Pro feature: compares today's count with the user's country and the world
/// using the server's cached daily aggregates.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _ScopeResult {
  const _ScopeResult({this.stats, this.errorCode});

  final TodayStats? stats;
  final String? errorCode;
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<List<_ScopeResult>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_ScopeResult>> _load() {
    final gateway = context.read<StatsGateway>();
    return Future.wait([
      _fetch(gateway, 'worldwide'),
      _fetch(gateway, 'country'),
    ]);
  }

  Future<_ScopeResult> _fetch(StatsGateway gateway, String scope) async {
    try {
      return _ScopeResult(stats: await gateway.today(scope));
    } on ApiException catch (e) {
      return _ScopeResult(errorCode: e.code);
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final country = context.watch<LoginService>().currentUser?.country;

    return Scaffold(
      appBar: AppBar(title: Text(strings.statsTitle)),
      body: FutureBuilder<List<_ScopeResult>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final results = snapshot.data ??
              const [_ScopeResult(), _ScopeResult()];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ScopeCard(
                  title: strings.statsWorldwide,
                  icon: Icons.public,
                  result: results[0],
                ),
                const SizedBox(height: 12),
                _ScopeCard(
                  title: country != null
                      ? strings.statsCountry(country)
                      : strings.statsCountryUnknown,
                  icon: Icons.flag,
                  result: results[1],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.title,
    required this.icon,
    required this.result,
  });

  final String title;
  final IconData icon;
  final _ScopeResult result;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stats = result.stats;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (stats == null)
              Text(_errorText(strings, result.errorCode))
            else ...[
              Text(
                strings.statsYourCountToday(stats.count),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              if (stats.percentile == null)
                Text(strings.statsNoData)
              else ...[
                Text(
                  strings.statsPercentile(stats.percentile!),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (stats.totalUsers != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    strings.statsParticipants(stats.totalUsers!),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _errorText(AppLocalizations strings, String? code) {
    switch (code) {
      case 'country_not_set':
        return strings.statsCountryNotSet;
      case 'pro_required':
        return strings.proRequiredMessage;
      default:
        return strings.errorNetwork;
    }
  }
}
