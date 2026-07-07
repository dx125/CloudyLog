import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_client.dart';
import '../../data/gateways.dart';
import '../../data/models/friend_models.dart';
import '../../l10n/generated/app_localizations.dart';

/// Pro feature: today's friend leaderboard, pending requests, and adding
/// friends by email.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _emailController = TextEditingController();
  List<FriendToday> _friends = const [];
  List<PendingFriendRequest> _pending = const [];
  bool _loading = true;
  bool _sending = false;
  String? _loadErrorCode;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final gateway = context.read<FriendsGateway>();
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        gateway.friendsToday(),
        gateway.pendingRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<FriendToday>;
        _pending = results[1] as List<PendingFriendRequest>;
        _loadErrorCode = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadErrorCode = e.code;
        _loading = false;
      });
    }
  }

  Future<void> _sendRequest() async {
    final strings = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack(strings.emailRequired);
      return;
    }
    setState(() => _sending = true);
    try {
      await context.read<FriendsGateway>().sendRequest(email);
      if (!mounted) return;
      _emailController.clear();
      _showSnack(strings.friendRequestSent);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(
        e.code == 'user_not_found'
            ? strings.friendUserNotFound
            : e.code == 'cannot_befriend_self'
                ? strings.friendCannotAddSelf
                : strings.errorNetwork,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _respond(PendingFriendRequest request, bool accept) async {
    final strings = AppLocalizations.of(context)!;
    try {
      await context
          .read<FriendsGateway>()
          .respond(requesterId: request.requesterId, accept: accept);
      if (!mounted) return;
      await _reload();
    } on ApiException {
      if (!mounted) return;
      _showSnack(strings.errorNetwork);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.friendsTitle)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_loadErrorCode != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _loadErrorCode == 'pro_required'
                                ? strings.proRequiredMessage
                                : strings.errorNetwork,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      strings.addFriendLabel,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_sending,
                            decoration: InputDecoration(
                              hintText: strings.emailLabel,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.person_add_alt),
                            ),
                            onSubmitted: (_) => _sendRequest(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _sending ? null : _sendRequest,
                          child: Text(strings.sendRequestButton),
                        ),
                      ],
                    ),
                    if (_pending.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        strings.friendRequestsHeader,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final request in _pending)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(request.requesterDisplayName),
                            subtitle: Text(request.requesterEmail),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check),
                                  tooltip: strings.acceptButton,
                                  color: Colors.green.shade600,
                                  onPressed: () => _respond(request, true),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: strings.declineButton,
                                  color: theme.colorScheme.error,
                                  onPressed: () => _respond(request, false),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      strings.friendsTodayHeader,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_friends.isEmpty && _loadErrorCode == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(strings.friendsEmpty),
                      )
                    else
                      for (var i = 0; i < _friends.length; i++)
                        Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${i + 1}'),
                            ),
                            title: Text(_friends[i].displayName),
                            trailing: Text(
                              '${_friends[i].count}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}
