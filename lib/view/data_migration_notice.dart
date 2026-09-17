import 'package:flutter/material.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

/// Shown at the bottom of the settings only when moving data from the old iOS app failed.
class DataMigrationNotice extends StatefulWidget {
  final SettingsViewModel settingsViewModel;

  const DataMigrationNotice({super.key, required this.settingsViewModel});

  @override
  DataMigrationNoticeState createState() => DataMigrationNoticeState();
}

class DataMigrationNoticeState extends State<DataMigrationNotice> {
  late final Future<String?> _error = widget.settingsViewModel.getDataMigrationError();

  Future<void> _sendDetails(String error) async {
    final version = await widget.settingsViewModel.getAppVersion();
    await widget.settingsViewModel.sendEmail(
      version,
      details: 'Nie udało się przenieść danych z poprzedniej wersji aplikacji.\n\nSzczegóły błędu:\n$error',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _error,
      builder: (context, snapshot) {
        final error = snapshot.data;
        if (error == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Column(
            children: [
              const Text(
                'Nie udało się przenieść ulubionych i własnych pieśni z poprzedniej wersji aplikacji.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              TextButton(
                onPressed: () => _sendDetails(error),
                child: const Text('Wyślij szczegóły błędu'),
              ),
            ],
          ),
        );
      },
    );
  }
}
