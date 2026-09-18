# AUDIT — Śpiewnik Android (Flutter)

> **Stan sprzed migracji i redesignu, wrzesień 2026. Materiał źródłowy dla PARITY.md — nie opisuje
> obecnego kodu.**

Repozytorium: `/Users/natanielmarmucki/StudioProjects/Spiewnik`
Data audytu: 2026-09-17. Tryb tylko do odczytu.

## 0. Zakres i stan repozytorium (przeczytaj najpierw)

| Stan | Szczegóły |
|---|---|
| **HEAD** | commit `3016541` „Update to version 1.1.0”. Historia: `cc3bd9c` „Initial commit”, potem trzy commity „Update to version 1.1.0”. |
| **Kopia robocza** | Niezacommitowane zmiany w `lib/main.dart`, `lib/objectbox-model.json` (tylko kolejność kluczy we właściwości `number`) i `pubspec.yaml`: `version: 1.1.0` → `1.2.1+5`, `objectbox` `^4.3.0` → `^5.0.1`, `objectbox_generator` `^4.3.0` → `^5.0.1`, `package_info_plus` `^8.1.0` → `^9.0.0`. `pubspec.lock` odpowiada kopii roboczej (`objectbox 5.0.1`). Zmodyfikowane są też pliki `.idea/*` i `.DS_Store`. |

**Sekcje 1–7 opisują kopię roboczą**, bo ma nowszy numer wersji i zgadza się z `pubspec.lock`. **NIEPOTWIERDZONE**, co jest w Google Play. Różnice z HEAD są opisane tam, gdzie mają znaczenie (8.17).

Identyfikatory: `applicationId = "com.nm.spiewnik"` (`android/app/build.gradle:30`), `namespace = "com.nm.spiewnik"` (`:15`), `android:label="Śpiewnik"` (`android/app/src/main/AndroidManifest.xml:4`). Pakiet Dart: `name: spiewnik` (`pubspec.yaml:1`).

**W repo nie ma katalogu `ios/`** (ani `web/`, `macos/` itd.). `flutter_icons.ios: false` (`pubspec.yaml:26`), `flutter_native_splash.ios: false` (`pubspec.yaml:33`).

**W aplikacji Flutter nie ma funkcji „Moje pieśni”**, które są na iOS. Brak encji, ekranu i kodu (`grep` w `lib/`).

---

## 1. Ekrany

### 1.1 Lista ekranów

| # | Nazwa (klasa) | Plik | Co robi | Jak się dochodzi |
|---|---|---|---|---|
| 1 | `MyApp` (`MaterialApp`) | `lib/main.dart:92-121` | Korzeń: `title: 'Śpiewnik'`, `theme: lightTheme`, `darkTheme: darkTheme`, `themeMode: ThemeMode.system`, `home: HomeScreen` (`:105-112`). W `build` uruchamia licznik uruchomień i prośbę o ocenę (`:104`, `:115-120`). | `runApp` w `main()` (`:80-89`) |
| 2 | `HomeScreen` | `lib/main.dart:123-196` | `Scaffold` z `AppBar` (tytuł zawsze `'Śpiewnik'`, `:157-160`) i ikoną `Icons.settings` (`:163-171`). Treść to `IndexedStack` z dwoma zakładkami (`:174-177`). Dolny pasek `ConvexAppBar` (`TabStyle.reactCircle`) z `TabItem(icon: Icons.auto_stories, title: 'Śpiewnik')` i `TabItem(icon: Icons.favorite, title: 'Ulubione')` (`:178-193`). | Ekran startowy |
| 3 | `SongListView` | `lib/view/song_list_view.dart:9-171` | Pole „Szukaj” z przyciskiem czyszczenia (`:47-78`). Lista wszystkich pieśni (`ListView.builder`, `itemExtent: 70.0`, `:94-98`): `CircleAvatar` z numerem, pogrubiony tytuł w jednej linii, czerwone serce przy ulubionych (`:127-150`). Przeciągany pasek przewijania z etykietą numeru (`:83-92`). | Zakładka 0 „Śpiewnik” w #2 |
| 4 | `FavoriteSongsView` | `lib/view/favorite_songs_view.dart:6-95` | Lista ulubionych (`Card` + `ListTile`, numer w `CircleAvatar`, tytuł). Gdy pusta: `'Brak ulubionych pieśni'` (`:19-26`). Brak wyszukiwarki. | Zakładka 1 „Ulubione” w #2 |
| 5 | `SongDetailView` | `lib/view/song_detail_view.dart:9-306` | Tytuł `'${song.number}. ${song.title}'` (`:40-46`). Akcje: serce (`:48-64`), „udostępnij”, które **kopiuje do schowka** (`:65-81`), lupa „Przejdź do pieśni” (`:82-95`). Tekst w `SingleChildScrollView` z czcionką i interlinią z ustawień (`:112-124`). Swipe poziomy przełącza pieśń (`:98-108`). Włącza blokadę wygaszania (`:25`, `:31`). | Tap w wiersz #3 lub #4; zastąpienie przez siebie samego (swipe / „Przejdź”) |
| 6 | `SettingsView` | `lib/view/settings_view.dart:6-165` | Podgląd tekstu, suwak rozmiaru czcionki, suwak wysokości linii, „Przywróć ustawienia domyślne”, linki „Kontakt”, „O mnie”, „Wesprzyj”, „Zgłoś błąd” | Ikona `Icons.settings` w `AppBar` #2 (`main.dart:166-169`) |
| 7 | Dialog „Przejdź do pieśni” | `song_detail_view.dart:139-236` | `AlertDialog` z `TextField` (tylko cyfry, maks. 4 znaki, `:191-195`), „Anuluj” / „Przejdź” | Ikona `Icons.search` w #5 |
| 8 | Dialog „Uwaga” | `song_detail_view.dart:238-269` | Komunikat błędu i „OK” | Po niepoprawnym numerze w #7 (`:271-285`) |
| 9 | `SnackBar` „Treść skopiowana do schowka” | `song_detail_view.dart:70-72` | — | Ikona `Icons.share` w #5 |
| 10 | Systemowe okno oceny (In-App Review) | `lib/model/review_model.dart:3-11` | — | Automatycznie (sekcja 6) |

Martwe ekrany: **brak**. Nieużywana jest metoda `_buildIconButton` (`song_detail_view.dart:131-137`).

### 1.2 Mapa nawigacji

```
main() → openStore() → initializeApp() (JSON → ObjectBox) → runApp(MultiProvider)
└── MyApp (MaterialApp, themeMode: system)
    └── HomeScreen (Scaffold)
        ├── AppBar [Icons.settings] → Navigator.push → SettingsView
        │                                            ├── 'Kontakt'     → launch https://spiewnik.odoo.com/contactus
        │                                            ├── 'O mnie'      → launch https://spiewnik.odoo.com/about-us
        │                                            ├── 'Wesprzyj'    → launch https://suppi.pl/spiewnik
        │                                            └── 'Zgłoś błąd'  → launch mailto:n.marmucki@icloud.com?subject=...
        ├── ConvexAppBar tab 0 'Śpiewnik' → SongListView
        │   └── tap wiersz → Navigator.push → SongDetailView
        └── ConvexAppBar tab 1 'Ulubione' → FavoriteSongsView
            └── tap wiersz → Navigator.push → SongDetailView

SongDetailView
  ├── [favorite] toggle (setState, bez nawigacji)
  ├── [share] Clipboard + SnackBar
  ├── [search] showDialog "Przejdź do pieśni"
  │     └── 'Przejdź' → pop dialog → Navigator.pushReplacement → SongDetailView(nowa)
  │                    └── błąd → showDialog "Uwaga"
  └── swipe (onPanUpdate dx < -10 → następna, dx > 10 → poprzednia)
        → Navigator.pushReplacement → SongDetailView(nowa)
```

Zakładki są w `IndexedStack`, więc obie listy żyją jednocześnie i zachowują stan. Oba widoki dzielą **jedną** instancję `SongViewModel` utworzoną w `_HomeScreenState.initState` (`main.dart:140-144`). `SettingsView` i `SongDetailView` są pushowane na główny `Navigator`, więc zakrywają dolny pasek.

---

## 2. Dane pieśni

### 2.1 Gdzie leżą

- **Źródło wbudowane:** `assets/songs_data.json` (1 629 390 bajtów), zadeklarowane w `pubspec.yaml:91-93`.
- **Baza robocza:** ObjectBox, encja `Song`. Store otwierany w `main()` przez `openStore()` (`lib/main.dart:75`; `lib/objectbox.g.dart:76-96`).
  - Katalog: `directory ?? (await defaultStoreDirectory()).path` (`objectbox.g.dart:88`). W `objectbox_flutter_libs 5.0.1` to `'${(await getApplicationDocumentsDirectory()).path}/${Store.defaultDirectoryPath}'` (`~/.pub-cache/hosted/pub.dev/objectbox_flutter_libs-5.0.1/lib/objectbox_flutter_libs.dart:17-19`), gdzie `defaultDirectoryPath = 'objectbox'` (`~/.pub-cache/hosted/pub.dev/objectbox-5.0.1/lib/src/native/store.dart:33`). Ścieżki są spoza repo.
  - Dokładna ścieżka na Androidzie (`getApplicationDocumentsDirectory()`) — NIEPOTWIERDZONE w repo.
- **Dane są wbudowane w aplikację i nie są pobierane.** W `lib/` nie ma importu `http`, `dio` ani `HttpClient`.
- **Martwy plik:** `assets/songs.sqlite` ma 0 bajtów i nie jest zadeklarowany w `pubspec.yaml`. Brak odwołań w `lib/`.

### 2.2 Format pliku JSON i liczba pozycji

Struktura (sprawdzona skryptem Python na pliku):

```json
{
  "songs": [
    { "number": 1, "title": "Alleluja, chwalcie Pana", "content": "1. Alleluja, ..." },
    ...
  ]
}
```

- Klucz najwyższego poziomu: tylko `songs` (obiekt, **nie** lista).
- **2000 pozycji.** Każda ma dokładnie klucze `content`, `number`, `title`.
- `number`: `int`, od 1 do 2000, 2000 unikalnych, posortowane rosnąco.
- `title`: `str`, 0 pustych. `content`: `str`, 0 pustych.
- Klucz `favorite` nie występuje w żadnej pozycji.
- `content` zawiera `\n` w 1938 pozycjach, `\r` w żadnej.
- Konwencje treści są takie jak na iOS: zwrotki `"1. "`, `"Refren: "`, akapity rozdzielone `\n\n`, powtórzenia `[:…:]` i `/…/3x`. Kod nie parsuje treści, wyświetla ją jako jeden `Text` (`song_detail_view.dart:115-121`).

### 2.3 Schemat pojedynczej pieśni

**Klasa Dart / encja ObjectBox** (`lib/model/song_model.dart:3-21`):

| Pole Dart | Typ Dart | Adnotacja | Wymagane w konstruktorze | Domyślna | ObjectBox `type` / `flags` (`lib/objectbox-model.json`) | UID właściwości |
|---|---|---|---|---|---|---|
| `id` | `int` | `@Id()` | nie | `0` (ObjectBox nadaje przy `put`) | `6` (Long) / `1` (ID) | `1:3978059592178831290` |
| `number` | `int` | `@Index()` | tak | — | `6` (Long) / `8` (indexed), `indexId` `1:2701213689850694877` | `4:5797442437404568959` |
| `content` | `String` (non-null) | — | tak | — | `9` (String) | `2:6301132552975073782` |
| `favorite` | `bool` (non-null) | — | tak | — | `1` (Bool) | `3:6320005701937599207` |
| `title` | `String` (non-null) | — | tak | — | `9` (String) | `5:3166716226409056261` |

Encja: `"name": "Song"`, `"id": "1:668007825265052091"` (`objectbox-model.json:7-9`).

**Mapowanie JSON → obiekt** (`song_model.dart:23-30`):

| Klucz JSON | Pole | Rzutowanie | Opcjonalne w JSON |
|---|---|---|---|
| `number` | `number` | `as int` | nie (brak = wyjątek) |
| `title` | `title` | `as String` | nie |
| `content` | `content` | `as String` | nie |
| `favorite` | `favorite` | `as bool? ?? false` | **tak** |

`toJson()` (`:32-40`) zwraca `id`, `number`, `title`, `content`, `favorite`. Brak wywołań `toJson` w `lib/`.

`number` **nie jest unikalny** (`@Index()`, nie `@Unique()`).

### 2.4 Ładowanie i aktualizacja danych

`initializeApp` (`lib/main.dart:32-70`) → `JsonManager.loadDataFromJsonIfNeeded` (`lib/json_manager.dart:14-26`):

1. Odczytuje `SharedPreferences` klucz `last_run_app_version` (`main.dart:30, 43`) i porównuje z `"${packageInfo.version}+${packageInfo.buildNumber}"` (`:41`).
2. `shouldForceUpdate = true`, gdy klucz jest `null` lub wartość się różni (`:48-50`). Przy wyjątku `false` (`:54-57`).
3. W `JsonManager`:
   - **box pusty** → `_populateFreshStoreFromJson` (`json_manager.dart:28-61`). Akceptuje zarówno `Map` z kluczem `songs`, jak i gołą `List` (`:35-42`), potem `putMany`;
   - **box niepusty i `forceUpdate`** → `_updateStoreFromJson` (`:63-118`): dla każdego numeru z JSON nadpisuje `title` i `content` istniejącego obiektu (**zachowuje `favorite` i `id`**), dodaje nowe numery i **usuwa obiekty, których numeru nie ma w JSON** (`:94-108`);
   - w pozostałych przypadkach nic nie robi.
4. Jeśli `shouldForceUpdate`, zapisuje nową wersję do `last_run_app_version` (`main.dart:61-69`). Robi to **niezależnie od wyniku aktualizacji**.

**Aktualizacja jest w praktyce zepsuta.** `_updateStoreFromJson` rzutuje `jsonDecode(jsonString) as List<dynamic>` (`json_manager.dart:71`), a plik jest obiektem `{"songs": [...]}`. Szczegóły w 8.1.

---

## 3. Dane użytkownika

### 3.1 Ulubione

| Pozycja | Wartość |
|---|---|
| Mechanizm | **ObjectBox** (`objectbox 5.0.1`) |
| Lokalizacja | Katalog store’u `…/objectbox` (2.1). Nazwy plików wewnątrz (`data.mdb`, `lock.mdb`) — NIEPOTWIERDZONE w repo. |
| Encja / pole | `Song.favorite` (`lib/model/song_model.dart:12`) |
| Typ | `bool` (ObjectBox `type: 1`) |
| Klucz powiązania z pieśnią | Ten sam obiekt: `Song.id` (`int`, auto) i `Song.number` (`int`). Przy aktualizacji danych tożsamością jest `number` (`json_manager.dart:66-68, 81-87`). |
| Zapis | `SongViewModel.toggleFavoriteStatus`: `song.favorite = !song.favorite; box.put(song)`, potem przeładowanie list (`lib/viewmodel/song_viewmodel.dart:54-65`). Wywoływane z `song_detail_view.dart:51-55`. |
| Odczyt | `box.query(Song_.favorite.equals(true)).build().find()`, **bez sortowania** (`song_viewmodel.dart:44-47`) |
| Kolejność dodania / data | **Nie jest zapisywana** |
| Uwaga | Ulubione, tak jak na iOS, **nie są oddzielone od treści pieśni**. To pole w tym samym obiekcie. |

### 3.2 Własne pieśni

**Nie istnieją w tej aplikacji.** Brak encji, pól i ekranu. Sprawdzone: `lib/model/`, `lib/objectbox-model.json` (jedna encja `Song`), `lib/view/`.

### 3.3 Historia / ostatnio otwierane

**Brak.** W `lib/` nie ma żadnego zapisu otwieranych pieśni.

### 3.4 Ustawienia i metadane (SharedPreferences)

Wszystkie przez `SharedPreferences.getInstance()` (legacy API pakietu `shared_preferences 2.5.3`).

| Klucz w kodzie (dokładny) | Typ | Domyślna | Zapis / odczyt | Znaczenie |
|---|---|---|---|---|
| `fontSize` | `double` (`getDouble`/`setDouble`) | `16.0` | `lib/model/font_size_model.dart:5, 20, 27` | Rozmiar czcionki tekstu pieśni |
| `lineHeight` | `double` | `1.5` | `font_size_model.dart:6, 21, 28` | Mnożnik wysokości linii (`TextStyle.height`) |
| `launch_count` | `int` (`getInt`/`setInt`) | `0` | `lib/launch_counter.dart:5, 9, 11` | Licznik uruchomień dla prośby o ocenę |
| `last_run_app_version` | `String` (`getString`/`setString`), format `"<version>+<buildNumber>"`, np. `1.2.1+5` | brak (`null`) | `lib/main.dart:30, 41, 43, 64` | Wersja, dla której ostatnio uruchomiono ładowanie JSON |

**Fizyczny format na Androidzie.** Wynika z kodu pakietów w `~/.pub-cache`, nie z repo:
- Klucze są zapisywane z prefiksem **`flutter.`**, np. `flutter.fontSize`, `flutter.launch_count` (`~/.pub-cache/hosted/pub.dev/shared_preferences-2.5.3/lib/src/shared_preferences_legacy.dart:22, 173`).
- Plik Android SharedPreferences o nazwie `FlutterSharedPreferences` (`~/.pub-cache/hosted/pub.dev/shared_preferences_android-2.4.15/android/src/main/java/io/flutter/plugins/sharedpreferences/LegacySharedPreferencesPlugin.java:34`); wersja `2.4.15` jest zablokowana w `pubspec.lock`.
- `double` jest zapisywany jako **String** z prefiksem `VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu` (`LegacySharedPreferencesPlugin.java:40, 98`). `int` jest zapisywany jako `long` (`:92`).

### 3.5 Wersjonowanie schematu i migracje

- ObjectBox: `lib/objectbox-model.json` zawiera `"modelVersion": 5`, `"modelVersionParserMinimum": 5`, `"version": 1`, `"lastEntityId": "1:668007825265052091"`, `"lastIndexId": "1:2701213689850694877"`, puste `retired*Uids` (`:43-53`). Schemat opiera się na UID-ach encji i właściwości (2.3). Nie ma usuniętych ani przemianowanych pól.
- **Brak własnych migracji schematu** w kodzie.
- „Migracja danych” to jedynie ponowne wczytanie JSON sterowane kluczem `last_run_app_version` (2.4), obecnie nieskuteczne (8.1).
- `SharedPreferences`: brak wersjonowania i migracji kluczy.
- Kopia robocza podnosi `objectbox` z `4.3.0` do `5.0.1` (`pubspec.yaml`). NIEPOTWIERDZONE, czy format pliku bazy wymaga konwersji między tymi wersjami.

---

## 4. Ustawienia

Ekran: `lib/view/settings_view.dart`. Stan: `FontSizeModel` (`ChangeNotifier`) z `ChangeNotifierProvider` w `main.dart:84`.

| Nazwa w UI | Klucz | Domyślna | Zakres / krok | Gdzie zapisywana | Na co wpływa |
|---|---|---|---|---|---|
| Rozmiar czcionki (`Slider`, ikony `Icons.text_fields` 20/28) | `fontSize` | `16.0` (`font_size_model.dart:8, 20`) | `min: 10.0`, `max: 30.0`, `divisions: 10`, czyli krok 2 (`settings_view.dart:50-59`) | SharedPreferences | `TextStyle.fontSize` treści w `SongDetailView` (`song_detail_view.dart:117-120`) i w karcie podglądu (`settings_view.dart:32-35`). **Nie** wpływa na listy. |
| Wysokość linii (`Slider`, ikony `Icons.format_line_spacing` 20/28) | `lineHeight` | `1.5` (`font_size_model.dart:9, 21`) | `min: 1.0`, `max: 3.0`, `divisions: 10`, czyli krok 0,2 (`settings_view.dart:70-79`) | SharedPreferences | `TextStyle.height` (mnożnik) w tych samych miejscach |
| „Przywróć ustawienia domyślne” (`ElevatedButton`) | `fontSize`, `lineHeight` | — | ustawia `16.0` i `1.5` (`font_size_model.dart:43-48`) | SharedPreferences | jw. |

Ustawienia wczytują się asynchronicznie w konstruktorze `FontSizeModel` (`:14-23`). Do czasu wczytania obowiązują wartości domyślne.

**Brak** ustawień: motywu (zawsze `ThemeMode.system`, `main.dart:110`), wyszukiwarki dynamicznej, blokady wygaszania, sortowania, języka.

---

## 5. Funkcje

| Funkcja | Status | Szczegóły i lokalizacja |
|---|---|---|
| Lista 2000 pieśni | Jest | `box.getAll()` **bez jawnego sortowania** (`song_viewmodel.dart:39-42`) |
| Wyszukiwanie | Jest | 5.1 |
| Szybkie przewijanie z etykietą numeru | Jest | `DraggableScrollbar.semicircle`. Etykieta `(offset ~/ 70) + 1`, pokazywana **tylko gdy lista ma dokładnie 2000 pozycji** (`song_list_view.dart:83-92`). |
| Czyszczenie wyszukiwania | Jest | Przycisk `Icons.cancel` czyści pole, przewija na górę i resetuje filtr (`song_list_view.dart:35-41, 57-62`) |
| Szczegóły pieśni | Jest | 1.1 #5 |
| Przejście do pieśni po numerze | Jest | Pole: tylko cyfry, maks. 4 znaki (`song_detail_view.dart:191-195`). Walidacja `1..2000` (`:272`). Komunikaty: `'Pieśń o podanym numerze nie została znaleziona'` (`:280`), `'Podano niepoprawny numer. W śpiewniku znajduje się 2000 pieśni.'` (`:283`). |
| Nawigacja gestem poprzednia/następna | Jest | `onPanUpdate`: `details.delta.dx < -10` → następna, `> 10` → poprzednia (`song_detail_view.dart:100-107`). Szuka `number ± 1` (`song_viewmodel.dart:89-95`). Brak zawijania. |
| Ulubione (dodaj/usuń) | Jest | Tylko z ekranu szczegółów (`song_detail_view.dart:48-64`) |
| Lista ulubionych | Jest | Bez jawnego sortowania (`song_viewmodel.dart:44-47`) |
| „Udostępnianie” | **Tylko kopiowanie do schowka** | Ikona `Icons.share`, `Clipboard.setData(ClipboardData(text: song.content))`: sama treść, bez tytułu i numeru, plus SnackBar (`song_detail_view.dart:65-81`). **Brak systemowego share sheet.** |
| Eksport / import | Brak | — |
| Sortowanie wybierane przez użytkownika | Brak | — |
| Tryb nocny | Tylko systemowy | `ThemeMode.system` (`main.dart:110`). Motywy: `lightTheme` z `primary: Color(0xFF9bd8ff)`; `darkTheme` z `primary: Colors.black` (`lib/theme/theme.dart:3-57`). |
| Rozmiar czcionki / interlinia | Jest | Sekcja 4 |
| **Blokada wygaszania ekranu** | Jest, **zawsze na ekranie szczegółów** | `WakelockPlus.enable()` w `initState`, `WakelockPlus.disable()` w `dispose` (`song_detail_view.dart:23-33`). Brak przełącznika. |
| Kontakt / O mnie / Wesprzyj | Jest (linki) | `https://spiewnik.odoo.com/contactus`, `https://spiewnik.odoo.com/about-us`, `https://suppi.pl/spiewnik` (`settings_view.dart:113, 124, 134`) |
| Zgłoś błąd | Jest | `mailto:n.marmucki@icloud.com`, `subject=Zgłoszenie błędu w aplikacji Śpiewnik (<version>)`, gdzie `<version>` = `packageInfo.version` bez numeru builda (`settings_viewmodel.dart:5-8, 18-34`; `settings_view.dart:148-153`) |
| Prośba o ocenę | Jest | Sekcja 6 |
| Changelog po aktualizacji | **Brak** | (na iOS jest) |
| Własne pieśni | **Brak** | (na iOS są) |

### 5.1 Wyszukiwanie — dokładnie

Kod: `SongViewModel._filterSongs` i `_removeNumber` (`lib/viewmodel/song_viewmodel.dart:67-87`). Wejście: `SongListView._onSearchChanged` z **debounce 250 ms** (`song_list_view.dart:26-33`) ustawia `viewModel.searchText` (`song_viewmodel.dart:25-28`).

1. Pusty tekst → pełna lista (`:68-71`).
2. Treść: `song.content?.toLowerCase() ?? ''`, potem `_removeNumber`:
   - usuwa każdy znak występujący w stringu `"123456789,.;:'[]()!?-”—„x"` (`:84`); sprawdzenie per jednostka kodu (`str.split('')`) i `charactersToRemove.contains(char)`;
   - **cyfra `0` nie jest usuwana**; usuwana jest mała litera **`x`**;
   - na końcu `.trim()` (`:85`).
3. Zapytanie: tylko `_searchText.toLowerCase()` (`:73`). **Znaki z zapytania nie są usuwane.**
4. Dopasowanie (OR, `:78-79`):
   - `cleanedContent.contains(lowercaseSearchText)`: podciąg, rozróżnia znaki diakrytyczne;
   - `song.number.toString().contains(_searchText)`: podciąg numeru.
5. **Pole `title` nie jest przeszukiwane.**
6. **Brak normalizacji polskich znaków:** „zolw” nie znajdzie „żółw”. `toLowerCase()` obsługuje wielkie litery polskie.
7. Filtrowanie działa w pamięci na liście z `getAll()`, bez zapytań ObjectBox.
8. Algorytm jest **identyczny** z iOS (`Song/Songbook.swift:78-98` w repo iOS), różni się tylko debounce: iOS 0,5 s lub zatwierdzenie, Flutter 250 ms.
9. W „Ulubionych” nie ma wyszukiwania.

---

## 6. Elementy platformowe

| Element | Zadeklarowane | Faktycznie używane | Lokalizacja |
|---|---|---|---|
| `android.permission.INTERNET` | Tak (main + debug manifest) | **Brak kodu sieciowego w `lib/`.** `url_launcher` otwiera zewnętrzne aplikacje. NIEPOTWIERDZONE, czy `in_app_review` wymaga tego uprawnienia. | `android/app/src/main/AndroidManifest.xml:2`; `android/app/src/debug/AndroidManifest.xml:20` |
| Inne uprawnienia | Brak | — | Manifesty |
| `<queries>` `PROCESS_TEXT` | Tak (szablon Flutter) | Przez silnik Flutter (komentarz w manifeście) | `AndroidManifest.xml:40-45` |
| `<queries>` `VIEW` + `BROWSABLE` + `https` | Tak | Tak: `canLaunch` / `launch` dla linków | `AndroidManifest.xml:47-53`; `settings_viewmodel.dart:10-16` |
| `<queries>` `mailto` | Tak | Tak: „Zgłoś błąd” | `AndroidManifest.xml:55-59`; `settings_viewmodel.dart:18-34` |
| Blokada wygaszania (`wakelock_plus`) | Brak uprawnienia (niepotrzebne) | **Tak** | `song_detail_view.dart:7, 25, 31` |
| In-App Review (`in_app_review`) | — | **Tak:** (a) przy `launch_count` ∈ `[5, 10, 50, 100, 250, 500, 750, 1000]` (`lib/launch_counter.dart:4, 15-17`; `main.dart:115-120`); (b) przy pierwszym dodaniu do ulubionych w danej instancji `SongViewModel` (`song_viewmodel.dart:14, 61-64`). Obie ścieżki sprawdzają `isAvailable()` (`review_model.dart:6-9`). | — |
| Schowek | — | Tak | `song_detail_view.dart:69` |
| Powiadomienia | Nie | Nie | — |
| Deep linki / App Links | Nie. Jedyny `intent-filter` to `MAIN` + `LAUNCHER`. | Nie | `AndroidManifest.xml:24-27` |
| Widgety ekranu głównego | Nie | Nie | Brak `appwidget` w `res/`, brak receiverów |
| Zakupy w aplikacji | Nie | Nie. „Wesprzyj” to link WWW. | — |
| Share intent (systemowe udostępnianie) | Nie | Nie (5) | — |
| Splash screen (`flutter_native_splash`) | Konfiguracja: `color: "#ffffff"`, `image: assets/playstore-transparent.png`, `color_dark: "#000000"`, `image_dark: assets/playstore-transparent.png`, `android: true` | Wygenerowane zasoby: `res/drawable*/launch_background.xml`, `res/values*/styles.xml`, `values-v31`, `values-night-v31`. W `lib/` nie ma wywołań `FlutterNativeSplash`. | `pubspec.yaml:29-35` |
| Ikona (`flutter_launcher_icons`) | `android: true`, `image_path: "assets/playstore-icon.png"` | Wygenerowane `res/mipmap-*`, `mipmap-anydpi-v26/ic_launcher.xml` | `pubspec.yaml:24-27` |
| Motyw systemowy (jasny/ciemny) | — | Tak | `main.dart:107-110` |
| Orientacja | Brak `android:screenOrientation`, więc bez blokady | — | `AndroidManifest.xml:7-15` |
| `launchMode` | `singleTop`, `taskAffinity=""` | — | `AndroidManifest.xml:10-11` |
| Podpisywanie release | `signingConfigs.release` z `android/key.properties` | Tak (`buildTypes.release.signingConfig = signingConfigs.release`) | `android/app/build.gradle:8-12, 40-58` |

---

## 7. Zależności

Wersje zablokowane z `pubspec.lock`. „Użycie” = pliki w `lib/`, które importują pakiet.

| Pakiet | Ograniczenie w `pubspec.yaml` | Zablokowana | Do czego | Gdzie |
|---|---|---|---|---|
| `objectbox` | `^5.0.1` | `5.0.1` | Baza danych (encja `Song`) | `main.dart`, `json_manager.dart`, `song_model.dart`, `song_viewmodel.dart`, `objectbox.g.dart` |
| `objectbox_flutter_libs` | `any` | `5.0.1` | Natywne biblioteki ObjectBox, `defaultStoreDirectory()` | `objectbox.g.dart:15` |
| `shared_preferences` | `^2.0.0` | `2.5.3` | Ustawienia i metadane (3.4) | `main.dart`, `launch_counter.dart`, `font_size_model.dart` |
| `provider` | `^6.0.0` | `6.1.5+1` | DI i stan (`MultiProvider`, `Consumer<FontSizeModel>`) | `main.dart`, `settings_view.dart`, `song_detail_view.dart` |
| `package_info_plus` | `^9.0.0` | `9.0.0` | Wersja aplikacji (aktualizacja danych, e-mail) | `main.dart`, `settings_viewmodel.dart` |
| `url_launcher` | `^6.0.9` | `6.3.2` | Linki WWW i `mailto`. Używa przestarzałych `canLaunch` / `launch`. | `settings_viewmodel.dart:11-12, 26-27` |
| `in_app_review` | `^2.0.10` | `2.0.11` | Prośba o ocenę | `review_model.dart` |
| `wakelock_plus` | `^1.2.8` | `1.4.0` | Blokada wygaszania w szczegółach | `song_detail_view.dart` |
| `convex_bottom_bar` | `^3.0.0` | `3.2.0` | Dolny pasek zakładek | `main.dart:16, 178-193` |
| `draggable_scrollbar` | `^0.1.0` | `0.1.0` | Przeciągany pasek przewijania z etykietą | `song_list_view.dart:6, 83` |
| `logger` | `^2.0.1` | `2.6.2` | Logowanie | `main.dart:19-28`, `json_manager.dart` |
| `flutter_native_splash` | `^2.3.1` | `2.4.7` | Generator splash (tylko konfiguracja) | nie importowany w `lib/` |
| `cupertino_icons` | `^1.0.8` | `1.0.8` | — | nie importowany w `lib/` |
| `win32` | `^5.5.3` | `5.15.0` | NIEPOTWIERDZONE (nie importowany w `lib/`) | — |
| `path` | `^1.8.0` | `1.9.1` | NIEPOTWIERDZONE (nie importowany w `lib/`) | — |
| dev: `objectbox_generator` | `^5.0.1` | `5.0.1` | Generowanie `objectbox.g.dart` i `objectbox-model.json` | — |
| dev: `build_runner` | `^2.5.4` | `2.10.1` | Uruchamianie generatora | — |
| dev: `flutter_launcher_icons` | `^0.14.4` | `0.14.4` | Generowanie ikon | — |
| dev: `flutter_lints` | `^6.0.0` | `6.0.0` | Lint (`analysis_options.yaml:10`) | — |
| (tranzytywna) `flat_buffers` | — | — | Serializacja ObjectBox | `objectbox.g.dart:11` |

Toolchain Android: AGP `com.android.application` `8.12.0`, Kotlin `2.2.0` (`android/settings.gradle:21-22`), Gradle `9.0.0` (`android/gradle/wrapper/gradle-wrapper.properties`), Java/JVM target 11 (`android/app/build.gradle:19-26`). SDK Dart: `^3.5.3` (`pubspec.yaml:22`). Flutter `revision: "2663184aa79047d0a33a14a3b607954f8fdd8730"`, `channel: "stable"` (`.metadata`).

---

## 8. Pułapki

**Dane**
1. **Aktualizacja tekstów u istniejących użytkowników nie działa.** `_updateStoreFromJson` robi `jsonDecode(jsonString) as List<dynamic>` (`lib/json_manager.dart:71`), a `assets/songs_data.json` ma na górze obiekt `{"songs": [...]}`. Rzutowanie rzuca błąd. Łapie go `catch (e)` (`:115-117`) i tylko loguje. Mimo to `initializeApp` zapisuje nową `last_run_app_version` (`main.dart:61-69`), więc kolejna próba już się nie odbędzie. Działa tylko pierwsze wypełnienie pustej bazy, które obsługuje oba formaty (`json_manager.dart:35-42`). Wniosek z analizy statycznej i zawartości pliku; w runtime NIEPOTWIERDZONE.
2. Gdyby aktualizacja zadziałała, **usunie** z bazy każdą pieśń, której numeru nie ma w JSON, **razem ze statusem ulubionej** (`json_manager.dart:94-108`).
3. **Lista i ulubione nie mają jawnego sortowania** (`song_viewmodel.dart:39-47`). Kolejność zależy od `id` ObjectBox. Pieśń o nowym numerze dodana przy aktualizacji dostałaby wyższe `id` i trafiłaby na koniec listy. NIEPOTWIERDZONE, czy ObjectBox gwarantuje kolejność `id` w `getAll()` / `find()`.
4. `number` jest indeksowany, ale nie unikalny (`song_model.dart:8-9`). `findSongByNumber` zwraca `findFirst()` (`song_viewmodel.dart:49-52`).
5. Ulubione są polem obiektu pieśni, a nie osobnym rekordem (3.1).
6. `assets/songs.sqlite` (0 bajtów) i pusty katalog `assets/android/` (tylko `.DS_Store`) to martwe pliki. `assets/playstore-icon.png` jest zadeklarowany jako asset (`pubspec.yaml:93`), ale nie jest używany w `lib/`.

**Ekran szczegółów**
7. **Wakelock przy `pushReplacement`:** nowy `SongDetailView` wywołuje `WakelockPlus.enable()` w `initState`, a zastępowany wywołuje `WakelockPlus.disable()` w `dispose` (`song_detail_view.dart:23-33`). Swipe i „Przejdź” używają `pushReplacement` (`:275-278, 290-293, 300-303`), a stara trasa jest usuwana po nowej. Prawdopodobnie po zmianie pieśni blokada wygaszania jest **wyłączona**. NIEPOTWIERDZONE w runtime.
8. Swipe jest wykrywany w `onPanUpdate` przy każdym zdarzeniu z `|delta.dx| > 10` (`:100-107`), nie na końcu gestu. Jeden ruch może wygenerować kilka `pushReplacement`. `GestureDetector` z `onPanUpdate` otacza `SingleChildScrollView` (`:98-127`), co może kolidować z przewijaniem pionowym. Oba punkty NIEPOTWIERDZONE w runtime.
9. Ikona `Icons.share` **nie udostępnia**, tylko kopiuje do schowka (`:65-81`).
10. Liczba `2000` zakodowana na sztywno: `song_detail_view.dart:272, 283`; `song_list_view.dart:87`. Etykieta paska przewijania zakłada `itemExtent` 70 px (`song_list_view.dart:90, 97`) i znika przy filtrowaniu.
11. Nieużywana metoda `_buildIconButton` (`song_detail_view.dart:131-137`).

**Wyszukiwanie**
12. Asymetryczna normalizacja jak na iOS: znaki usuwane z treści, ale nie z zapytania; usuwane `x`, nieusuwane `0`; tytuł nieprzeszukiwany (5.1).

**Ocena / uruchomienia**
13. Licznik uruchomień jest zwiększany w **`MyApp.build`** (`main.dart:104, 115-120`), a nie przy starcie procesu. Każdy rebuild `MyApp` zwiększa `launch_count`. NIEPOTWIERDZONE, jak często `MyApp` się przebudowuje.
14. Prośba o ocenę przy pierwszym dodaniu ulubionej jest ograniczona flagą `_firstAddition` tylko w pamięci (`song_viewmodel.dart:14, 61-64`), czyli raz na uruchomienie aplikacji. Brak ograniczenia per wersja (na iOS jest `lastVersionPromptedForReviewKey`).

**UI**
15. Tytuł `AppBar` to zawsze `'Śpiewnik'`, także w zakładce „Ulubione” (`main.dart:157-160`).
16. `ConvexAppBar.activeColor: Colors.white.withAlpha(153)` przy `backgroundColor: Theme.of(context).colorScheme.primary` (`main.dart:184-185`). W motywie jasnym `primary` to `0xFF9bd8ff`.

**Stan repo / build**
17. **Niezacommitowane zmiany wersji i zależności** (sekcja 0). Wersja w HEAD `pubspec.yaml` (`1.1.0`) nie zgadza się z `pubspec.lock`. W HEAD `main.dart` przy wyjątku wywoływał `loadDataFromJsonIfNeeded(forceUpdate: false)` w `catch` (`git diff lib/main.dart`). W kopii roboczej wywołanie jest poza `try`.
18. Klucz wersji `last_run_app_version` zawiera numer builda (`"${version}+${buildNumber}"`, `main.dart:41`), więc każdy nowy build wymusza ścieżkę aktualizacji.
19. `android/upload_certificate.pem` **jest śledzony w git** (`git ls-files`). `android/key.properties` leży lokalnie i jest ignorowany (`android/.gitignore:11`). Zawartości nie cytuję.
20. W `defaultConfig` są jednocześnie `minSdk = flutter.minSdkVersion` i `minSdkVersion flutter.minSdkVersion` (`android/app/build.gradle:33, 37`). Komentarz „Signing with the debug keys for now” (`:51-52`) nie odpowiada kodowi, który używa `signingConfigs.release`.
21. Test `test/widget_test.dart:6-14` wywołuje prawdziwe `openStore()` i oczekuje `find.text('Śpiewnik')` → `findsOneWidget`. Tekst `'Śpiewnik'` występuje w `AppBar` (`main.dart:158`) i w `TabItem` (`:181`). NIEPOTWIERDZONE, czy test przechodzi (nie uruchamiałem).
22. Zależności `win32`, `path`, `cupertino_icons` nie są importowane w `lib/` (sekcja 7).
23. Katalog `.idea/` i pliki `.flutter-plugins*` są śledzone w git (lista plików), a `.idea/*` jest zmodyfikowany.

---

## 9. Pytania otwarte

1. **Która wersja jest w Google Play?** Czy `1.2.1+5` z niezacommitowanej kopii roboczej, czy `1.1.0` z HEAD?
2. Czy jakikolwiek użytkownik Androida dostał kiedyś poprawki tekstów po instalacji (8.1)? Od tego zależy, ile wersji treści istnieje na urządzeniach.
3. **Który zbiór tekstów jest wzorcowy?** `assets/songs_data.json` różni się od `Model.sqlite` z repo iOS (HEAD) w **3 tytułach** (numery `923`, `1497`, `1498`; `1497` i `1498` mają zamienione tytuły: iOS `'Drogi bracie mój'` / `'Wystarczy iskra'`, Flutter odwrotnie; `923`: iOS `'Gdy idziesz sam'`, Flutter `'Zjednani sercem i ustami'`) oraz w **58 treściach** (pierwsze: `292`, `450`, `686`, `898`, `900`, `923`, `930`, `939`, `944`, `959`).
4. Czy wspólna aplikacja ma być **aktualizacją obu istniejących aplikacji w sklepach** (`com.nm.spiewnik` na Androidzie, `com.natanielmarmucki.Spiewnik` na iOS)? Od tego zależy, czy trzeba przenosić dane:
   - Android: ObjectBox `Song.favorite` oraz `FlutterSharedPreferences` (`flutter.fontSize`, `flutter.lineHeight`, `flutter.launch_count`, `flutter.last_run_app_version`);
   - iOS: Core Data `ZSONG.ZFAVORITE`, `ZMYSONG` oraz `UserDefaults` bez prefiksu `flutter.`.
5. Dokładna ścieżka katalogu ObjectBox na Androidzie i nazwy plików w nim — w repo nie da się tego potwierdzić.
6. Czy brak „Moich pieśni” na Androidzie jest zamierzony?
7. Semantyka ustawień różni się między platformami: iOS `isLineSpacing` to dodatkowe punkty 0…10 (domyślnie 0), Flutter `lineHeight` to mnożnik 1,0…3,0 (domyślnie 1,5). iOS domyślny rozmiar na iPadzie to 24. Nie da się z kodu ustalić, która semantyka jest docelowa.
8. Czy wakelock faktycznie wyłącza się po swipe (8.7) i czy swipe wyzwala wielokrotne przejścia (8.8)? Wymaga testu na urządzeniu.
9. Czy `INTERNET` jest potrzebne (6)?
10. Do czego miały służyć `win32`, `path` i pusty `assets/songs.sqlite`?
