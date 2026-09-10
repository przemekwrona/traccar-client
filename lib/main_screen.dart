import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traccar_client/main.dart';
import 'package:traccar_client/password_service.dart';
import 'package:traccar_client/preferences.dart';

import 'geolocation_service.dart';
import 'l10n/app_localizations.dart';
import 'qr_code_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  static const _trackingTab = 0;
  static const _settingsTab = 1;

  final _settingsKey = GlobalKey<SettingsScreenState>();
  int _selectedIndex = _trackingTab;
  bool trackingEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshState();
    }
  }

  Future<void> _refreshState() async {
    final tracking = await GeolocationService.tracker.isTracking();
    if (!mounted) return;
    setState(() {
      trackingEnabled = tracking;
    });
  }

  void refresh() {
    setState(() {});
    _settingsKey.currentState?.refresh();
  }

  Future<void> _onDestinationSelected(int index) async {
    if (index == _settingsTab && _selectedIndex != _settingsTab) {
      if (await PasswordService.authenticate(context) && mounted) {
        setState(() => _selectedIndex = index);
      }
      return;
    }
    setState(() => _selectedIndex = index);
  }

  Widget _buildTrackingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.trackingTitle),
              titleTextStyle: Theme.of(context).textTheme.headlineMedium,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.idLabel),
              subtitle: Text(Preferences.instance.getString(Preferences.id) ?? ''),
            ),
            if (Platform.isAndroid) ...[
              Text(
                AppLocalizations.of(context)!.disclosureMessage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.trackingLabel),
              value: trackingEnabled,
              onChanged: (bool value) async {
                if (await PasswordService.authenticate(context) && mounted) {
                  if (value) {
                    FirebaseCrashlytics.instance.log('tracking_toggle_start');
                    var started = false;
                    try {
                      await GeolocationService.tracker.start();
                      started = true;
                    } on PlatformException {
                      // permission denied or startup error
                    }
                    if (!mounted) return;
                    if (!started) {
                      messengerKey.currentState?.showSnackBar(
                        const SnackBar(
                          content: Text('Failed to start tracking. Check location permissions.'),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                    setState(() => trackingEnabled = started);
                  } else {
                    FirebaseCrashlytics.instance.log('tracking_toggle_stop');
                    await GeolocationService.tracker.stop();
                    if (mounted) setState(() => trackingEnabled = false);
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await GeolocationService.tracker.requestPosition();
                    } on PlatformException {
                      // permission denied or location error
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.locationButton),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  onPressed: () async {
                    try {
                      await GeolocationService.tracker.requestPosition(alarm: 'sos');
                    } on PlatformException {
                      // permission denied or location error
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.sosAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onSettings = _selectedIndex == _settingsTab;
    return Scaffold(
      appBar: AppBar(
        title: Text(onSettings ? l10n.settingsTitle : 'Traccar Client'),
        actions: [
          if (onSettings)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const QrCodeScreen()));
                _settingsKey.currentState?.refresh();
              },
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: _buildTrackingCard(),
          ),
          SettingsScreen(key: _settingsKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.location_on_outlined),
            selectedIcon: const Icon(Icons.location_on),
            label: l10n.trackingTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settingsTitle,
          ),
        ],
      ),
    );
  }
}
