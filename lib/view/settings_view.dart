import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

class SettingsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settingsViewModel = Provider.of<SettingsViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ustawienia', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Consumer<FontSizeModel>(
        builder: (context, fontSizeModel, child) {
          return ListView(
            padding: EdgeInsets.all(16.0),
            children: [
              Card(
                child: Container(
                  constraints: BoxConstraints(maxHeight: 180.0, minHeight: 180),
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
                          Icon(Icons.text_fields, size: 20),
                          Expanded(
                            child: Slider(
                              value: fontSizeModel.fontSize,
                              min: 10.0,
                              max: 30.0,
                              divisions: 10,
                              label: "${fontSizeModel.fontSize.round()}",
                              onChanged: (value) {
                                fontSizeModel.setFontSize(value);
                              },
                            ),
                          ),
                          Icon(Icons.text_fields, size: 28),
                        ],
                      ),
                    ),
                    ListTile(
                      subtitle: Row(
                        children: [
                          Icon(Icons.format_line_spacing, size: 20),
                          Expanded(
                            child: Slider(
                              value: fontSizeModel.lineHeight,
                              min: 1.0,
                              max: 3.0,
                              divisions: 10,
                              label:
                              "${fontSizeModel.lineHeight.toStringAsFixed(1)}",
                              onChanged: (value) {
                                fontSizeModel.setLineHeight(value);
                              },
                            ),
                          ),
                          Icon(Icons.format_line_spacing, size: 28),
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
                          Text('Przywróć ustawienia domyślne'),
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
                        Icon(Icons.sms),
                        title:
                        Text('Kontakt'),
                        onTap:
                            () => settingsViewModel.launchURL('https://spiewnik.odoo.com/contactus'),
                      ),
                    ),
                    Divider(color:
                    Theme.of(context).colorScheme.primary),
                    ListTile(
                      leading:
                      Icon(Icons.person),
                      title:
                      Text('O mnie'),
                      onTap:
                          () => settingsViewModel.launchURL('https://spiewnik.odoo.com/about-us'),
                    ),
                    Divider(color:
                    Theme.of(context).colorScheme.primary),
                    ListTile(
                      leading:
                      Icon(Icons.favorite),
                      title:
                      Text('Wesprzyj'),
                      onTap:
                          () => settingsViewModel.launchURL('https://suppi.pl/spiewnik'),
                    ),
                    Divider(color:
                    Theme.of(context).colorScheme.primary),
                    Padding(
                      padding:
                      const EdgeInsets.only(bottom:
                      4.0),
                      child:
                      ListTile(
                        leading:
                        Icon(Icons.error),
                        title:
                        Text('Zgłoś błąd'),
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
            ],
          );
        },
      ),
    );
  }
}