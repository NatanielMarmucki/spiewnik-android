import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/view/data_migration_notice.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsViewModel = Provider.of<SettingsViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Consumer<FontSizeModel>(
        builder: (context, fontSizeModel, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 180.0, minHeight: 180),
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Alleluja, chwalcie Pana, Nućcie Jemu chwałę, cześć! "
                        "Chwalcie, wszyscy aniołowie, Głosząc Jego łaski wieść! "
                        "Chwal Go, słońce i księżycu, Chwal Go, mnóstwo jasnych gwiazd, "
                        "Chwalcie, góry, chwalcie, drzewa, Chwalcie, ptaki, z swoich gniazd!",
                    style: TextStyle(
                      fontSize: fontSizeModel.fontSize,
                      height: fontSizeModel.lineHeight,
                    ),
                    textAlign: TextAlign.center,
                    softWrap: true,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      subtitle: Row(
                        children: [
                          const Icon(Icons.text_fields, size: 20),
                          Expanded(
                            child: Slider(
                              value: fontSizeModel.fontSize,
                              min: FontSizeModel.minFontSize,
                              max: FontSizeModel.maxFontSize,
                              divisions: 10,
                              label: "${fontSizeModel.fontSize.round()}",
                              onChanged: (value) {
                                fontSizeModel.setFontSize(value);
                              },
                            ),
                          ),
                          const Icon(Icons.text_fields, size: 28),
                        ],
                      ),
                    ),
                    ListTile(
                      subtitle: Row(
                        children: [
                          const Icon(Icons.format_line_spacing, size: 20),
                          Expanded(
                            child: Slider(
                              value: fontSizeModel.lineHeight,
                              min: FontSizeModel.minLineHeight,
                              max: FontSizeModel.maxLineHeight,
                              divisions: 8, // krok 0,05 w zakresie 1,4-1,8
                              label: fontSizeModel.lineHeight.toStringAsFixed(2),
                              onChanged: (value) {
                                fontSizeModel.setLineHeight(value);
                              },
                            ),
                          ),
                          const Icon(Icons.format_line_spacing, size: 28),
                        ],
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding:
                        const EdgeInsets.symmetric(vertical: 8.0),
                        child: ElevatedButton(
                          onPressed:
                              () => fontSizeModel.resetToDefaults(),
                          child:
                          const Text('Przywróć ustawienia domyślne'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                child: Column(
                  children: [
                    Padding(
                      padding:
                      const EdgeInsets.only(top: 4.0),
                      child:
                      ListTile(
                        leading:
                        const Icon(Icons.sms),
                        title:
                        const Text('Kontakt'),
                        onTap:
                            () => settingsViewModel.launchURL('https://spiewnik.odoo.com/contactus'),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading:
                      const Icon(Icons.person),
                      title:
                      const Text('O mnie'),
                      onTap:
                          () => settingsViewModel.launchURL('https://spiewnik.odoo.com/about-us'),
                    ),
                    const Divider(),
                    ListTile(
                      leading:
                      const Icon(Icons.favorite),
                      title:
                      const Text('Wesprzyj'),
                      onTap:
                          () => settingsViewModel.launchURL('https://suppi.pl/spiewnik'),
                    ),
                    const Divider(),
                    Padding(
                      padding:
                      const EdgeInsets.only(bottom:
                      4.0),
                      child:
                      ListTile(
                        leading:
                        const Icon(Icons.error),
                        title:
                        const Text('Zgłoś błąd'),
                        onTap:
                            () async {
                          String version =
                          await settingsViewModel.getAppVersion();
                          settingsViewModel.sendEmail(version);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              DataMigrationNotice(settingsViewModel: settingsViewModel),
            ],
          );
        },
      ),
    );
  }
}