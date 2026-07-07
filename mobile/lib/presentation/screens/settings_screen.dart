import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/app_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/config_service.dart';
import '../../services/login_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _recommendedController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _countryController;
  late String _languageCode;

  @override
  void initState() {
    super.initState();
    final config = context.read<ConfigService>();
    final login = context.read<LoginService>();
    _recommendedController =
        TextEditingController(text: config.recommendedDailyCount.toString());
    _displayNameController =
        TextEditingController(text: config.displayName);
    _countryController =
        TextEditingController(text: login.currentUser?.country ?? '');
    _languageCode = config.languageCode;
  }

  @override
  void dispose() {
    _recommendedController.dispose();
    _displayNameController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strings = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final config = context.read<ConfigService>();
    final login = context.read<LoginService>();
    await config
        .setRecommendedDailyCount(int.parse(_recommendedController.text.trim()));
    await config.setDisplayName(_displayNameController.text);
    await config.setLanguageCode(_languageCode);

    // Country lives on the account (used for country-scope comparisons).
    if (login.isLoggedIn) {
      final country = _countryController.text.trim().toUpperCase();
      if (country.isNotEmpty && country != (login.currentUser?.country ?? '')) {
        final ok = await login.updateCountry(country);
        if (!ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.errorNetwork)),
          );
          return;
        }
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.settingsSaved)),
    );
    Navigator.of(context).pop();
  }

  String _languageLabel(AppLocalizations strings, String code) {
    switch (code) {
      case 'es':
        return strings.languageSpanish;
      case 'en':
      default:
        return strings.languageEnglish;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final login = context.watch<LoginService>();

    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _displayNameController,
                  decoration: InputDecoration(
                    labelText: strings.displayNameSetting,
                    hintText: strings.displayNameHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _languageCode,
                  decoration: InputDecoration(
                    labelText: strings.languageSetting,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.language),
                  ),
                  items: [
                    for (final code in AppConfig.supportedLanguageCodes)
                      DropdownMenuItem<String>(
                        value: code,
                        child: Text(_languageLabel(strings, code)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _languageCode = value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _recommendedController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: strings.recommendedCountSetting,
                    hintText: strings.recommendedCountHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.flag_outlined),
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed <= 0) {
                      return strings.invalidNumberError;
                    }
                    return null;
                  },
                ),
                if (login.isLoggedIn) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _countryController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 2,
                    decoration: InputDecoration(
                      labelText: strings.countrySetting,
                      hintText: strings.countryHint,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.public),
                      counterText: '',
                    ),
                    validator: (value) {
                      final trimmed = (value ?? '').trim().toUpperCase();
                      if (trimmed.isEmpty) return null; // optional
                      if (!RegExp(r'^[A-Z]{2}$').hasMatch(trimmed)) {
                        return strings.invalidCountryError;
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(strings.cancelButton),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        child: Text(strings.saveButton),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
