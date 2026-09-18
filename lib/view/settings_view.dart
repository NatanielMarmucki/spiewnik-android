import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spiewnik/model/app_settings_model.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/view/data_migration_notice.dart';
import 'package:spiewnik/view/widgets/settings_section.dart';
import 'package:spiewnik/view/widgets/song_content.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

/// Ustawienia po redesignie (docs/DESIGN-SYSTEM.md, sekcje 4-6).
///
/// Sekcje zamiast kart: „Czytanie”, „Wygląd”, „Aplikacja” i wersje na końcu. Próbka pieśni stoi
/// **bezpośrednio pod suwakiem rozmiaru** i rośnie razem z tekstem — nie ma stałej wysokości,
/// więc przy największej czcionce nic się nie ucina (reguła 1 z sekcji 7).
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  /// Dwa wersy pieśni: dość, żeby zobaczyć interlinię, i mało, żeby nie zasłonić suwaków.
  static const String sampleText = 'Alleluja, chwalcie Pana,\nNućcie Jemu chwałę, cześć!';

  @override
  Widget build(BuildContext context) {
    final settingsViewModel = Provider.of<SettingsViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          const _ReadingSection(),
          const _AppearanceSection(),
          SettingsSection(
            title: 'Aplikacja',
            children: [
              SettingsRow(
                icon: Icons.sms,
                label: 'Kontakt',
                onTap: () => settingsViewModel.launchURL('https://spiewnik.odoo.com/contactus'),
              ),
              SettingsRow(
                icon: Icons.person,
                label: 'O mnie',
                onTap: () => settingsViewModel.launchURL('https://spiewnik.odoo.com/about-us'),
              ),
              SettingsRow(
                icon: Icons.favorite_border,
                label: 'Wesprzyj',
                onTap: () => settingsViewModel.launchURL('https://suppi.pl/spiewnik'),
              ),
              SettingsRow(
                icon: Icons.error_outline,
                label: 'Zgłoś błąd',
                onTap: () async {
                  final version = await settingsViewModel.getAppVersion();
                  settingsViewModel.sendEmail(version);
                },
              ),
            ],
          ),
          _VersionsSection(settingsViewModel: settingsViewModel),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0),
            child: DataMigrationNotice(settingsViewModel: settingsViewModel),
          ),
          const SizedBox(height: 24.0),
        ],
      ),
    );
  }
}

class _ReadingSection extends StatelessWidget {
  const _ReadingSection();

  @override
  Widget build(BuildContext context) {
    final fontSizeModel = context.watch<FontSizeModel>();
    final appSettings = context.watch<AppSettingsModel>();

    return SettingsSection(
      title: 'Czytanie',
      children: [
        SettingsSlider(
          label: 'Rozmiar tekstu',
          value: fontSizeModel.fontSize,
          valueLabel: '${fontSizeModel.fontSize.round()}',
          min: FontSizeModel.minFontSize,
          max: FontSizeModel.maxFontSize,
          divisions: (FontSizeModel.maxFontSize - FontSizeModel.minFontSize).round(),
          onChanged: fontSizeModel.setFontSize,
        ),
        // Próbka zaraz pod suwakiem rozmiaru, żeby zmianę widać było bez przewijania.
        Padding(
          padding: const EdgeInsets.fromLTRB(22.0, 4.0, 22.0, 16.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              // Bez ograniczenia wysokości: próbka rośnie razem z czcionką.
              child: SongContent(
                content: SettingsView.sampleText,
                padding: EdgeInsets.zero,
                scrollable: false,
              ),
            ),
          ),
        ),
        SettingsSlider(
          label: 'Interlinia',
          value: fontSizeModel.lineHeight,
          valueLabel: fontSizeModel.lineHeight.toStringAsFixed(2),
          min: FontSizeModel.minLineHeight,
          max: FontSizeModel.maxLineHeight,
          divisions: ((FontSizeModel.maxLineHeight - FontSizeModel.minLineHeight) / 0.05).round(),
          onChanged: fontSizeModel.setLineHeight,
        ),
        SettingsSwitch(
          label: 'Nie gaś ekranu przy pieśni',
          description: 'Ekran zostaje włączony, dopóki masz otwartą pieśń.',
          value: appSettings.keepScreenOn,
          onChanged: appSettings.setKeepScreenOn,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22.0, 8.0, 22.0, 4.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              // Reset dotyczy tylko rozmiaru i interlinii: motyw i blokada ekranu zostają.
              onPressed: fontSizeModel.resetToDefaults,
              style: TextButton.styleFrom(foregroundColor: context.appColors.accent),
              child: const Text('Przywróć domyślny rozmiar i interlinię'),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  static const List<({ThemeMode mode, String label})> _options = [
    (mode: ThemeMode.system, label: 'Jak w systemie'),
    (mode: ThemeMode.light, label: 'Jasny'),
    (mode: ThemeMode.dark, label: 'Ciemny'),
  ];

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettingsModel>();

    return SettingsSection(
      title: 'Wygląd',
      children: [
        for (final option in _options)
          SettingsRow(
            icon: appSettings.themeMode == option.mode ? Icons.check : null,
            label: option.label,
            selected: appSettings.themeMode == option.mode,
            onTap: () => appSettings.setThemeMode(option.mode),
          ),
      ],
    );
  }
}

/// Wersje aplikacji i danych pieśni, potrzebne przy zgłaszaniu błędów w tekstach.
class _VersionsSection extends StatelessWidget {
  final SettingsViewModel settingsViewModel;

  const _VersionsSection({required this.settingsViewModel});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String appVersion, int dataVersion})>(
      future: settingsViewModel.getVersions(),
      builder: (context, snapshot) {
        final versions = snapshot.data;
        return SettingsSection(
          title: 'Wersje',
          children: [
            SettingsRow(label: 'Wersja aplikacji', value: versions?.appVersion ?? '—'),
            SettingsRow(label: 'Wersja bazy pieśni', value: versions == null ? '—' : '${versions.dataVersion}'),
          ],
        );
      },
    );
  }
}
