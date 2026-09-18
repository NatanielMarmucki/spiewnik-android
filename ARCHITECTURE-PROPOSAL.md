# Propozycja uporządkowania struktury — Śpiewnik (Flutter)

Data: 2026-09-17. Stan: gałąź `feature/ios-data-migration`, HEAD `0a4ad4a`
(w trakcie tej analizy równoległa sesja zacommitowała komunikat o nieudanej migracji; opis uwzględnia ten commit).
Dokument powstał tylko na podstawie czytania kodu, `flutter test` (**88 testów, wszystkie przechodzą**,
z `lib/libobjectbox.dylib` na miejscu) i `flutter analyze` (14 uwag). Żaden plik poza tym dokumentem nie został zmieniony.

**Werdykt w skrócie:** układ jest adekwatny do wielkości aplikacji (~2400 linii własnego kodu).
Przebudowa nie jest potrzebna. Brakuje jednej rzeczy o realnym znaczeniu: **warstwy danych (repozytoriów)**
między view modelami a ObjectBoksem. Do tego kilka punktowych zmian: rozdzielenie `main.dart`, wspólne widgety
wiersza i treści pieśni, usunięcie martwego kodu, `CLAUDE.md`. Przejście na układ feature-first **nie jest warte kosztu**.

---

## KROK 1 — Inwentaryzacja

### 1.1 Drzewo katalogów

Liczby linii dla plików `.dart`. `objectbox.g.dart` jest generowany i nie wlicza się do sumy kodu własnego.

```
lib/                                   2368 linii kodu własnego (+327 wygenerowanych)
├── main.dart                     217  start aplikacji, sprawdzenie wersji, MyApp, HomeScreen z paskiem zakładek
├── json_manager.dart             179  SongsData (parsowanie i walidacja assetu) + JsonManager (zapis do ObjectBoksa, dataVersion)
├── launch_counter.dart            17  licznik uruchomień w SharedPreferences i progi prośby o ocenę
├── objectbox.g.dart              327  WYGENEROWANY: openStore(), getObjectBoxModel(), metadane encji
├── objectbox-model.json               UID-y encji ObjectBoksa (źródło prawdy dla schematu, nie usuwać)
├── libobjectbox.dylib                 natywna biblioteka do testów, poza gitem (tools/fetch_objectbox_lib.sh)
├── migration/            2 pliki 332
│   ├── core_data_reader.dart     147  czyta ulubione i ZMYSONG z kopii starej bazy iOS (sqflite), bez zapisu
│   └── core_data_migration.dart  185  jednorazowy zapis snapshotu do ObjectBoksa, flagi w SharedPreferences
├── model/                4 pliki 124
│   ├── song_model.dart            40  encja ObjectBox Song + fromJson/toJson
│   ├── my_song_model.dart         26  encja ObjectBox MySong
│   ├── font_size_model.dart       48  ChangeNotifier z rozmiarem czcionki i interlinią (SharedPreferences)
│   └── review_model.dart          10  opakowanie in_app_review
├── theme/                1 plik   56
│   └── theme.dart                 56  lightTheme / darkTheme
├── view/                10 plików 1247
│   ├── song_list_view.dart       171  zakładka „Śpiewnik”: wyszukiwarka z debounce, lista z DraggableScrollbar
│   ├── song_detail_view.dart     305  treść pieśni, ulubione, kopiowanie, dialog „przejdź do numeru”, swipe, wakelock
│   ├── favorite_songs_view.dart   94  zakładka „Ulubione”
│   ├── my_songs_view.dart        110  zakładka „Moje pieśni” z usuwaniem gestem
│   ├── my_song_detail_view.dart  118  podgląd własnej pieśni: udostępnianie, edycja, usuwanie, wakelock
│   ├── my_song_form_view.dart    156  formularz dodawania i edycji z pytaniem o odrzucenie zmian
│   ├── settings_view.dart        166  czcionka, interlinia, linki, zgłoszenie błędu
│   ├── data_migration_notice.dart 53  komunikat w ustawieniach po nieudanej migracji z iOS
│   ├── confirmation_dialog.dart   61  wspólny dialog potwierdzenia akcji niszczącej
│   └── delete_my_song_dialog.dart 13  treść dialogu usuwania własnej pieśni
└── viewmodel/            3 pliki 196
    ├── song_viewmodel.dart        96  lista, ulubione, wyszukiwanie, szukanie po numerze, prośba o ocenę
    ├── my_song_viewmodel.dart     52  CRUD własnych pieśni + ValueNotifier listy
    └── settings_viewmodel.dart    48  wersja aplikacji, błąd migracji, url_launcher, e-mail ze zgłoszeniem

test/                    11 plików 1592 (+133 w support/)
├── core_data_reader_test.dart    269  czytnik na fixtures + dane syntetyczne na kopiach (WAL, NULL-e, uszkodzone pliki)
├── core_data_migration_test.dart 287  migracja: fixtures, brak bazy, błąd, idempotencja, runOnStartup
├── data_migration_notice_test.dart 119 komunikat w ustawieniach + SettingsViewModel
├── json_manager_test.dart         64  SongsData: formaty, walidacja, pełny asset 2000 pieśni
├── my_song_test.dart             148  encja MySong na ObjectBoksie + niezależność od aktualizacji assetu
├── my_song_viewmodel_test.dart    93  MySongViewModel
├── my_songs_view_test.dart       125  lista własnych pieśni, usuwanie gestem, zgodność wymiarów wiersza z listą pieśni
├── my_song_form_view_test.dart   223  formularz
├── my_song_detail_view_test.dart 158  podgląd, udostępnianie, wakelock, edycja, usuwanie
├── home_screen_test.dart          60  trzecia zakładka i przycisk dodawania
├── widget_test.dart               45  start MyApp z zakładkami
├── support/
│   ├── test_store.dart            22  ObjectBox w katalogu tymczasowym
│   ├── core_data_fixtures.dart    28  kopiowanie fixtures z -wal/-shm, zmiany syntetyczne
│   └── platform_fakes.dart        83  atrapy kanałów: wakelock, share, url_launcher
└── fixtures/                          3 prawdziwe bazy iOS (+ -wal/-shm) i README
```

Poza `lib/` i `test/`, ale istotne dla struktury: `SCHEMA-ZMYSONG.md`, `AUDIT.md` (nieśledzony), `docs/PARITY.md`,
`tools/fetch_objectbox_lib.sh`, `tools/song_merge/` (Python, budowanie `songs_data.json`). **Nie ma katalogu `ios/`.**

### 1.2 Każde bezpośrednie sięgnięcie do `Store` / `Box`

Kod aplikacji (bez `objectbox.g.dart`):

| Plik:linia | Co |
|---|---|
| `lib/main.dart:79` | `openStore()` |
| `lib/main.dart:80` | `JsonManager(objectBoxStore, …)` |
| `lib/main.dart:84` | `CoreDataMigration.runOnStartup(store: objectBoxStore, …)` |
| `lib/main.dart:89` | `Provider<Store>.value(…)` — **nikt tego nie odczytuje** |
| `lib/main.dart:93, 99` | `MyApp(store:)`, pole `final Store store` |
| `lib/main.dart:117, 131` | `HomeScreen(store:)`, pole `final Store store` |
| `lib/main.dart:150–151` | `SongViewModel(widget.store)`, `MySongViewModel(widget.store)` |
| `lib/json_manager.dart:76` | pole `final Store objectBoxStore` |
| `lib/json_manager.dart:97` | `objectBoxStore.box<Song>()` |
| `lib/json_manager.dart:101, 103` | `songBox.isEmpty()`, `songBox.putMany` |
| `lib/json_manager.dart:120–121` | `_updateStore(Box<Song> …)`, `runInTransaction(TxMode.write)` |
| `lib/json_manager.dart:124, 153, 155` | `getAll`, `putMany`, `removeMany` |
| `lib/viewmodel/song_viewmodel.dart:10` | pole `final Store store` |
| `lib/viewmodel/song_viewmodel.dart:40–41` | `box<Song>().getAll()` |
| `lib/viewmodel/song_viewmodel.dart:45–46` | `query(Song_.favorite.equals(true)).build().find()` — zapytanie niezamykane |
| `lib/viewmodel/song_viewmodel.dart:50–51` | `query(Song_.number.equals(n)).build().findFirst()` — zapytanie niezamykane |
| `lib/viewmodel/song_viewmodel.dart:55–57` | `box<Song>().put(song)` |
| `lib/viewmodel/my_song_viewmodel.dart:6` | pole `final Store store` |
| `lib/viewmodel/my_song_viewmodel.dart:16–18` | zapytanie z `order(MySong_.createdAt, descending)` + `close()` |
| `lib/viewmodel/my_song_viewmodel.dart:25, 39, 45` | `put`, `put`, `remove` |
| `lib/migration/core_data_migration.dart:56, 71` | pole `Store store`, parametr `runOnStartup` |
| `lib/migration/core_data_migration.dart:134–135` | `runInTransaction`, `box<Song>()` |
| `lib/migration/core_data_migration.dart:139–141` | `query(Song_.number.equals(n))` + `close()` |
| `lib/migration/core_data_migration.dart:151` | `putMany` ulubionych |
| `lib/migration/core_data_migration.dart:155, 157, 173` | `box<MySong>()`, `getAll`, `putMany` |

Testy: `test/support/test_store.dart:15` i osobno `test/my_song_test.dart:19` tworzą `Store`. Asercje bezpośrednio na boksach są
w `core_data_migration_test`, `my_song_test`, `my_song_viewmodel_test`, `my_songs_view_test`, `my_song_form_view_test`,
`my_song_detail_view_test`. Widoki nie dotykają ObjectBoksa bezpośrednio, ale `HomeScreen` i `MyApp` przekazują `Store` dalej.

**Podsumowanie:** ObjectBox jest w 4 plikach logiki (`main.dart`, `json_manager.dart`, dwa view modele, migracja).
Pieśń po numerze jest wyszukiwana w dwóch miejscach różnym kodem (`song_viewmodel.dart:50`, `core_data_migration.dart:139`),
pole `favorite` zapisują trzy miejsca (`song_viewmodel.dart:56`, `json_manager.dart:129`, `core_data_migration.dart:147`).

### 1.3 Gdzie leży logika biznesowa

| Logika | Miejsce | Warstwa |
|---|---|---|
| Wyszukiwanie: normalizacja treści, dopasowanie numeru | `song_viewmodel.dart:67–87` | VM |
| Przełączanie ulubionej + prośba o ocenę przy pierwszym dodaniu | `song_viewmodel.dart:54–65` | VM |
| Walidacja numeru 1…2000 i przejście do pieśni | `song_detail_view.dart:271–285` | **widok** |
| Poprzednia / następna pieśń gestem | `song_detail_view.dart:98–108, 287–305` | **widok** (VM tylko `number ± 1`) |
| Etykieta paska przewijania (2000 pieśni, 70 px wiersza) | `song_list_view.dart:86–92` | widok |
| Walidacja i przycinanie pól formularza, wykrywanie zmian | `my_song_form_view.dart:42–81` | widok (akceptowalne: logika formularza) |
| „Brak zmian → nie zmieniaj updatedAt” | `my_song_viewmodel.dart:31–42` | VM |
| Kiedy wymusić aktualizację pieśni (wersja aplikacji) | `main.dart:36–74` | **funkcja w main.dart** |
| Aktualizacja pieśni z zachowaniem ulubionych, dataVersion | `json_manager.dart:96–178` | serwis danych |
| Migracja z Core Data | `lib/migration/` | serwis danych |
| Progi prośby o ocenę | `launch_counter.dart` + wywołanie w **`MyApp.build`** (`main.dart:110, 121–126`) | widget |
| Odczyt błędu migracji | `settings_viewmodel.dart:13–19` (czyta klucze `CoreDataMigration`) | VM |
| Treść e-maila ze zgłoszeniem | `settings_viewmodel.dart:30–47` | VM |

Wniosek: logika danych jest w view modelach razem z logiką prezentacji. Logika startu jest w `main.dart`.
Część nawigacji i walidacji siedzi w widoku `song_detail_view.dart`.

### 1.4 Duplikacje

| Co | Gdzie |
|---|---|
| Wiersz listy (karta z paskiem, `CircleAvatar`, pogrubiony tytuł) | `song_list_view.dart:100–161`, `favorite_songs_view.dart:31–86` (wariant z `Card`), `my_songs_view.dart:48–100`. Test `my_songs_view_test.dart:103` istnieje tylko po to, żeby pilnować zgodności kopii. |
| Treść pieśni z `FontSizeModel` | `song_detail_view.dart:109–125`, `my_song_detail_view.dart:98–115` (z `TODO: Unify` w linii 97) |
| Wakelock w `initState`/`dispose` | `song_detail_view.dart:23–33`, `my_song_detail_view.dart:22–32` |
| Przycisk akcji w AppBarze | `my_song_detail_view.dart:65–75` (`_buildAction`) i trzy razy inline w `song_detail_view.dart:48–95` |
| Styl dialogów (zaokrąglenie 20, kolory dark/light, przyciski) | `confirmation_dialog.dart`, `song_detail_view.dart:139–236` i `238–269` |
| Zapytanie o pieśń po numerze | `song_viewmodel.dart:49–52`, `core_data_migration.dart:139–141` |
| Stała 2000 | `song_detail_view.dart:272, 283`, `song_list_view.dart:87` |
| Zestaw providerów aplikacji | `main.dart:87–93`, `test/widget_test.dart:26–31`, `test/data_migration_notice_test.dart:38–42`, częściowo `home_screen_test.dart:24` i `my_song_detail_view_test.dart:39` |
| Dostęp do `SharedPreferences` (klucze rozrzucone) | `main.dart:34, 42, 67`, `json_manager.dart:74, 163, 172`, `launch_counter.dart:5`, `font_size_model.dart:5–6`, `core_data_migration.dart:51–53`, `settings_viewmodel.dart:14` |
| `PackageInfo.fromPlatform()` | `main.dart:43`, `settings_viewmodel.dart:8` |
| Testy: tworzenie `Store` | `test/my_song_test.dart:17–26` powiela `support/test_store.dart` |
| Testy: kopiowanie fixtures | `test/core_data_reader_test.dart:48–66` powiela `support/core_data_fixtures.dart` |
| Testy: `buildMySong` | `my_song_test.dart:28`, `my_song_viewmodel_test.dart:13` |

### 1.5 Martwy kod i pliki

| Element | Miejsce | Uwagi |
|---|---|---|
| `_buildIconButton` | `song_detail_view.dart:131–137` | nieużywana metoda |
| `Song.toJson` | `song_model.dart:32–40` | brak wywołań w `lib/`, `test/`, `tools/` |
| `Provider<Store>.value` | `main.dart:89` (i kopia w `widget_test.dart:29`) | nikt nie czyta; **sugeruje agentowi, że `context.read<Store>()` w widoku jest dozwolone** |
| `import 'package:flutter/physics.dart'`, `import 'package:flutter/material.dart'`, zbędny `import objectbox.dart` | `song_viewmodel.dart:2, 6, 7` | `flutter analyze` |
| `song.content?.toLowerCase()` | `song_viewmodel.dart:75` | `?.` na typie nie-null |
| `print('Swipe left/right')` | `song_detail_view.dart:102, 105` | debug |
| `assets/songs.sqlite` | 0 bajtów | nieużywany |
| zależność `win32` | `pubspec.yaml` | nieimportowana |
| `assets/playstore-icon.png` w `flutter.assets` | `pubspec.yaml` | używany tylko przez `flutter_launcher_icons` (ścieżka pliku), niepotrzebnie pakowany do aplikacji |
| `canLaunch` / `launch` | `settings_viewmodel.dart:22–23, 39–40` | przestarzałe API (nie martwe, ale do wymiany) |

`CoreDataSnapshot.hasMySongTable` i `CoreDataMySong.primaryKey` są czytane tylko w testach — to celowa diagnostyka, **zostawić**.

### 1.6 Pokrycie testami

88 testów w 11 plikach. 8 z 11 plików wymaga `libobjectbox.dylib`
(wszystkie importujące `test_store.dart` lub `objectbox.g.dart`). Bez biblioteki działają tylko
`core_data_reader_test` (SQLite przez FFI), `data_migration_notice_test` i `json_manager_test`.

| Obszar | Pokrycie | Dlaczego tak |
|---|---|---|
| Czytnik Core Data | dobre (15 testów, prawdziwe fixtures, WAL, uszkodzone pliki) | wstrzykiwany `DatabaseFactory` |
| Migracja Core Data | dobre (13) | wstrzykiwane `reader`, `now`, `isIOS`, `documentsDirectory`; wymaga ObjectBoksa |
| Własne pieśni: VM, lista, formularz, podgląd | dobre (32) | wymaga ObjectBoksa; kanały platformy przez `platform_fakes.dart` |
| `SongsData` (parsowanie assetu) | dobre | czysta funkcja |
| `JsonManager.applySongsData` | **1 test pośredni** (`my_song_test.dart:105`); scalanie duplikatów numerów, usuwanie, zapis `dataVersion` nietestowane | wymaga ObjectBoksa; test leży w pliku o encji MySong |
| `initializeApp` (wersja aplikacji → forceUpdate) | **brak** | funkcja w `main.dart`, sama pobiera `SharedPreferences` i `PackageInfo`, wymaga `JsonManager` z prawdziwym `Store` |
| `main()` | **brak, nietestowalne** | `openStore()` pyta `path_provider`; w `testWidgets` wywołanie nigdy się nie kończy (`widget_test.dart:17–19`) |
| `SongViewModel`: wyszukiwanie, ulubione | **brak** | `Store` + twardo tworzony `ReviewModel` → `InAppReview.instance` (`song_viewmodel.dart:15`), toggle wywołuje kanał platformy |
| `SongListView`, `FavoriteSongsView` | **brak** (poza porównaniem wymiarów wiersza) | wymaga `SongViewModel`, czyli ObjectBoksa |
| `SongDetailView`: swipe, przejście do numeru, wakelock przy `pushReplacement` | **brak** | logika w widoku, wymaga VM z ObjectBoksem; atrapa wakelocka już istnieje |
| `FontSizeModel` | tylko pośrednio | ładowanie asynchroniczne w konstruktorze |
| `LaunchCounter`, `ReviewModel`, prośba o ocenę w `MyApp.build` | **brak** | twarde `InAppReview.instance`, wywołanie w `build` |
| `SettingsView`: linki, e-mail | częściowo (e-mail) | przez atrapę kanału `url_launcher` |

---

## KROK 2 — Diagnoza

Problemy uszeregowane od najbardziej dokuczliwych przy pracy z agentem.

### P1. Brak warstwy danych: `Store` jest przekazywany przez UI do view modeli

`main.dart:150–151` tworzy view modele z `Store`, a view modele same budują zapytania.
Skutki w tym projekcie:

- **Testy UI wymagają natywnej biblioteki.** Agent w świeżym klonie, na CI albo w sandboxie bez sieci uruchamia `flutter test`
  i dostaje awarię 8 z 11 plików, choć zmieniał tylko wygląd listy. Testy widoków `my_songs_view_test`, `my_song_form_view_test`,
  `my_song_detail_view_test`, `home_screen_test` nie testują ObjectBoksa, a i tak go potrzebują.
- **Reguły zapytań nie mają jednego miejsca.** „Pieśń po numerze” jest napisana dwa razy, raz z `close()`, raz bez.
  Brak jawnego sortowania listy i ulubionych (`song_viewmodel.dart:41, 46`, pułapka 8.3 w `AUDIT.md`) — agent naprawiający
  sortowanie nie ma oczywistego miejsca i poprawi jedno z dwóch.
- **`SongViewModel` jest nietestowalny** (ObjectBox + twardy `InAppReview`), więc wyszukiwanie, którego zgodność z iOS
  jest opisana w `docs/PARITY.md`, nie ma żadnego testu.

### P2. `main.dart` łączy cztery odpowiedzialności

Start i kolejność inicjalizacji (`:36–96`), `MyApp` z prośbą o ocenę w `build` (`:98–127`), `HomeScreen` z zakładkami
i przyciskiem dodawania (`:129–217`). Skutki:

- Agent zmieniający pasek zakładek musi wczytać logikę wersjonowania danych i migracji, i odwrotnie.
- **Kolejność „najpierw asset, potem migracja” jest zapisana tylko w komentarzu** (`:83`). Nic jej nie testuje.
  Zamiana dwóch linii przez agenta spowoduje, że migracja z iOS nie znajdzie pieśni i ulubione zostaną pominięte — bez błędu.
- Logika wersjonowania pieśni jest w dwóch plikach: decyzja „wymusić aktualizację” w `main.dart:36–74`,
  wykonanie i `dataVersion` w `json_manager.dart`. Pytanie „jak działa aktualizacja tekstów” wymaga złożenia obu.
- Testy odtwarzają `MultiProvider` ręcznie (`widget_test.dart:26–31`). Dodanie nowego providera w `main.dart`
  psuje testy wyjątkiem `ProviderNotFoundException` w miejscach, których agent nie zmieniał.

### P3. Zmiana w jednym miejscu wymusza zmiany w kilku

- **Wygląd wiersza listy**: 3 pliki (1.4). Istniejący test porównujący wymiary pilnuje tylko dwóch z trzech kopii.
- **Wyświetlanie treści pieśni** (np. nowe ustawienie wyrównania): 2 pliki, w jednym jest już `TODO`.
- **Nowy klucz ustawień lub migracja ustawień z iOS**: klucze są prywatne w `FontSizeModel` (`_fontSizeKey`),
  a migracja musiałaby je skopiować jako literały. `SettingsViewModel` importuje `CoreDataMigration` tylko po stałe kluczy.
- **Nowe pole w `Song`**: encja + regeneracja + walidacja w `SongsData.fromJson` (`json_manager.dart:57–60`) +
  `Song.fromJson` + ewentualnie `_updateStore` i migracja.
- **Liczba pieśni** (2000): 3 miejsca w UI + test assetu.

### P4. Brak granic: agent nie wie, gdzie dopisać nową funkcję

- `lib/model/` miesza trzy rodzaje rzeczy: encje ObjectBoksa, `ChangeNotifier` z ustawieniami, opakowanie pluginu.
  Agent szukający „modelu ustawień” trafi dobrze, ale reguła „zmiana w `model/` wymaga regeneracji” byłaby fałszywa.
- Brak miejsca na serwisy platformy: `ReviewModel` w `model/`, `LaunchCounter` w katalogu głównym `lib/`,
  `url_launcher` i `PackageInfo` wewnątrz `SettingsViewModel`.
- Brak miejsca na wspólne widgety: `confirmation_dialog.dart` leży w `view/` obok ekranów.
- `Provider<Store>` w drzewie (martwy) zachęca do dostępu do bazy z widoku.
- Trzy sposoby dostarczania zależności bez reguły: konstruktor (`SongListView(viewModel:)`), `Provider`
  (`SettingsViewModel`, `FontSizeModel`), tworzenie w polu (`MyApp.reviewModel`, `SongViewModel.reviewModel`).
- Trzy sposoby logowania: globalny `logger` z `main.dart`, wstrzykiwany `Logger` (migracja, `JsonManager`), `print`.

### P5. Kod nietestowalny bez urządzenia lub prawdziwej bazy

Zestawienie w 1.6. Główne przyczyny, wszystkie strukturalne:
`Store` w view modelach; `InAppReview.instance` tworzone w polu (`review_model.dart:4`, używane w `song_viewmodel.dart:15`
i `main.dart:100`); logika startu w `main.dart` pobierająca zależności samodzielnie; logika nawigacji w `SongDetailView`.

Dobre wzorce już są w repo i warto je upowszechnić: `CoreDataMigration` (wstrzykiwane `reader`, `now`, `isIOS`, `documentsDirectory`),
`CoreDataReader` (wstrzykiwany `DatabaseFactory`), `MySongViewModel` (wstrzykiwane `now`), `platform_fakes.dart`.

### P6. Pułapka narzędziowa: `core_data_migration.dart` jest dla gita i grepa plikiem binarnym

`lib/migration/core_data_migration.dart:184` zawiera **dosłowny bajt NUL** w `'$title\0$content'`.
Skutki już widoczne: `git log --stat` pokazuje `Bin 0 -> 7004 bytes` dla commita `9587c6d`, `git diff` nie pokazuje zmian,
`grep` pomija plik (przy inwentaryzacji wyszukanie `box<` nie znalazło w nim niczego). Agent szukający, gdzie zapisuje się
ulubione, **nie znajdzie tego pliku**, a recenzja PR nie pokaże diffu. Poprawka: `'$title $content'` — identyczna wartość w runtime.

### P7. Brakujące konwencje

- Nazewnictwo: `*_model.dart` dla różnych rzeczy; `*_view.dart` dla ekranów, ale `data_migration_notice.dart` i dialogi w tym samym katalogu.
- Testy płasko w `test/`, nazwy nie odpowiadają plikom: `widget_test.dart` testuje `MyApp`, `my_song_test.dart` testuje
  encję i `JsonManager`.
- Pliki wygenerowane i natywna biblioteka leżą w katalogu głównym `lib/` obok kodu, bez informacji, że nie wolno ich edytować
  ani usuwać (`objectbox-model.json` przechowuje UID-y: jego utrata i regeneracja od zera oznacza niezgodny schemat na urządzeniach użytkowników).
- Brak `CLAUDE.md`. Wiedza o pułapkach jest rozproszona w `README.md`, `test/fixtures/README.md`, komentarzach testów i `AUDIT.md`.

Uwaga o rozmiarze: **problemu „ogromnych plików” tu nie ma.** Największy jest `song_detail_view.dart` (305 linii).
Koszt dla agenta wynika ze sprzężeń (P1–P3), nie z długości plików.

---

## KROK 3 — Propozycja

### 3.1 Które podejście i dlaczego

**Oficjalna architektura Fluttera** (docs.flutter.dev/app-architecture) „mocno zaleca” warstwę UI (widoki + view modele)
i warstwę danych (repozytoria + serwisy), wstrzykiwanie zależności przez `provider`, abstrakcyjne repozytoria i fake'i w testach.
Warstwę domeny (use case'y) oznacza jako warunkową: „w większości aplikacji dodają zbędny narzut”.
W studium przypadku (Compass) **UI jest pogrupowane według funkcji, a dane według typu**.

**Feature-first** grupuje wszystko (widoki, VM, dane) w katalogach funkcji.

Tutaj pasuje **oficjalny podział na warstwy, bez domeny, bez grupowania UI według funkcji**:

- Projekt już ma warstwę UI w tym kształcie (`view/` + `viewmodel/`). Brakuje tylko warstwy danych — i to jest
  źródłem P1, P5 i części P3. Dodanie repozytoriów rozwiązuje konkretne problemy; przemeblowanie katalogów UI nie.
- Funkcje są trzy (śpiewnik z ulubionymi, własne pieśni, ustawienia) i **współdzielą dane**: ulubione to pole `Song`,
  migracja pisze do obu encji, aktualizacja assetu dotyka ulubionych. W feature-first `Song` i tak trafiłby do katalogu wspólnego,
  więc „funkcja” zawierałaby same widoki.
- Pogrupowanie `view/` według funkcji (jak w Compass) dałoby ~13 plików w 4 katalogach. Nazwy już mają prefiksy
  (`my_song*`, `song_*`, `settings_*`), więc agent znajduje pliki funkcji jednym globem. Przeniesienie zmieniłoby importy
  w każdym pliku testów i kolidowałoby z trwającą migracją (`settings_view.dart`, `data_migration_notice.dart`).
- Domena / use case'y: logika nie „tłoczy się” w VM (największy ma 96 linii). Pomijam.
- `go_router`: 5 tras, brak deep linków. Pomijam.

**Kiedy wrócić do tematu:** gdy `lib/view/` przekroczy ~20 plików albo pojawią się warianty ekranów
(np. układ dwukolumnowy na iPada, który ma wersja iOS wg `docs/PARITY.md`). Wtedy pogrupować **tylko** `view/` i `viewmodel/`
według funkcji, a `data/` zostawić według typu.

### 3.2 O wymaganiu „testowalne bez prawdziwej bazy”

Proponuję je rozumieć tak: **nic powyżej warstwy danych nie dotyka ObjectBoksa ani SQLite**. View modele i widoki
testujemy na fake'ach repozytoriów. Samą implementację repozytoriów, ładowanie assetu i migrację testujemy na ObjectBoksie
w katalogu tymczasowym (`TestStore`) i na fixtures SQLite. To nie jest urządzenie ani baza użytkownika, a atrapa ObjectBoksa
testowałaby tylko samą siebie. Skutek: `libobjectbox.dylib` jest potrzebny do ~4 plików testów danych zamiast 8.

### 3.3 Docelowa struktura

Zmiany oznaczone `←`. Wszystko bez strzałki zostaje na miejscu.

```
lib/
├── main.dart                         ← ~25 linii: ensureInitialized, bootstrap(), runApp
├── app.dart                          ← MyApp (MaterialApp, motywy) + buildAppProviders()
├── objectbox.g.dart                  (wygenerowany, bez zmian)
├── objectbox-model.json              (bez zmian, nie usuwać)
├── startup/
│   └── app_startup.dart              ← z main.dart:36–85: otwarcie store, wersja → asset, migracja iOS; kolejność w jednym miejscu
├── data/
│   ├── repositories/
│   │   ├── song_repository.dart      ← abstract SongRepository + ObjectBoxSongRepository (z song_viewmodel.dart)
│   │   └── my_song_repository.dart   ← abstract MySongRepository + ObjectBoxMySongRepository (z my_song_viewmodel.dart)
│   ├── songbook/
│   │   └── songbook_loader.dart      ← z json_manager.dart (SongsData + SongbookLoader), nazwa mówi, co robi
│   └── services/
│       ├── review_service.dart       ← z model/review_model.dart + launch_counter.dart
│       └── app_info_service.dart     ← PackageInfo + url_launcher (z settings_viewmodel.dart i main.dart)
├── migration/                        (bez zmian: już ma wstrzykiwane zależności i dobre testy)
│   ├── core_data_reader.dart
│   └── core_data_migration.dart
├── model/                            tylko encje ObjectBoksa
│   ├── song_model.dart
│   └── my_song_model.dart
├── theme/theme.dart
├── view/
│   ├── home_screen.dart              ← z main.dart:129–217
│   ├── widgets/                      ← wspólne widgety
│   │   ├── song_list_tile.dart       ← z 3 kopii wiersza
│   │   ├── song_content.dart         ← treść z FontSizeModel + wakelock (z 2 widoków szczegółów)
│   │   ├── app_bar_action.dart       ← z _buildAction i 3 kopii inline
│   │   └── confirmation_dialog.dart  ← przeniesiony z view/
│   └── (pozostałe ekrany bez zmian)
└── viewmodel/
    ├── font_size_model.dart          ← przeniesiony z model/ (nazwa klasy bez zmian)
    └── (bez zmian)

test/
├── data/                             ← testy repozytoriów, songbook_loader (na TestStore)
├── migration/                        ← core_data_reader_test, core_data_migration_test (po scaleniu migracji)
├── (testy VM i widoków jak dziś, ale na fake'ach)
└── support/
    ├── fakes/                        ← FakeSongRepository, FakeMySongRepository, FakeReviewService
    ├── test_store.dart, core_data_fixtures.dart, platform_fakes.dart
    └── pump_app.dart                 ← wspólny wrapper z buildAppProviders()
```

Czego świadomie **nie** przenoszę:

- **Encji z `model/` do `data/models/`.** Wymaga regeneracji `objectbox.g.dart`; UID-y są w `objectbox-model.json`, więc
  schemat by przetrwał, ale korzyść to tylko spójność nazw, a ryzyko dotyczy danych użytkowników.
- **`lib/migration/` do `lib/data/`.** Moduł jest dobrze odgraniczony i aktywnie rozwijany. Przeniesienie daje tylko spójność,
  a kosztuje konflikty. Reguła dla agenta obejmie oba katalogi.
- **Osobnych plików na interfejsy.** Klasa abstrakcyjna i implementacja ObjectBox w jednym pliku (~60 linii).
  Dla porównania z Laravelem: to jak interfejs repozytorium i implementacja Eloquent, tyle że bez kontenera —
  implementację wybiera `buildAppProviders()`, a test podaje fake.
- **Kontenera DI (`get_it`), zmiany zarządzania stanem (Riverpod/Bloc).** `provider` + `ValueNotifier` wystarczają.

### 3.4 Zmiany: co, dlaczego, co to daje

**Z1. Repozytoria `SongRepository` i `MySongRepository`**
- *Co:* wszystkie zapytania i zapisy z `song_viewmodel.dart:39–57` i `my_song_viewmodel.dart:15–47` trafiają do repozytoriów.
  VM dostają repozytorium w konstruktorze. `HomeScreen` i `MyApp` przestają znać `Store`. Znika `Provider<Store>`.
  Metody o nazwach z domeny: `all()`, `favorites()`, `byNumber(n)`, `setFavorite(song, bool)`; `newestFirst()`, `add`, `update`, `delete`.
- *Dlaczego:* P1, P4, P5.
- *Co daje:* testy `my_song_viewmodel`, `my_songs_view`, `my_song_form_view`, `my_song_detail_view`, `home_screen`, `widget_test`
  działają bez `libobjectbox.dylib`. `SongViewModel` staje się testowalny (wyszukiwanie, ulubione). Jedno miejsce na sortowanie
  i zamykanie zapytań. Reguła dla agenta: „`Store`/`Box` tylko w `lib/data/`, `lib/migration/`, `lib/startup/`” — sprawdzalna grepem.
- *Uwaga:* `SongbookLoader` i migracja **nie** korzystają z repozytoriów, bo potrzebują transakcji obejmującej wiele operacji.
  To też warstwa danych, więc wolno im używać `Store`.

**Z2. `ReviewService` (z `ReviewModel` + `LaunchCounter`), wstrzykiwany**
- *Co:* jedna klasa z `onAppLaunched()` i `onFavoriteAdded()`, zależna od `InAppReview` i `SharedPreferences`.
  Wywołanie przenoszone z `MyApp.build` do startu.
- *Dlaczego:* twardy `InAppReview.instance` blokuje test `toggleFavorite`. Zliczanie w `build` jest pułapką 8.13 z `AUDIT.md`.
- *Co daje:* `SongViewModel` testowalny w całości. Uwaga: przeniesienie zliczania z `build` do startu **zmienia zachowanie**
  (licznik rośnie wolniej). Zrobić jako osobny commit i świadomą decyzję.

**Z3. Start aplikacji w `lib/startup/app_startup.dart`, `MyApp` w `app.dart`, `HomeScreen` w `view/`**
- *Co:* `initializeApp` i kolejność z `main()` jako funkcja z wstrzykiwanymi `Store`, `SharedPreferences`, wersją aplikacji,
  źródłem assetu, `CoreDataMigration`. `buildAppProviders(...)` używane przez `main.dart` i testy.
- *Dlaczego:* P2.
- *Co daje:* test „najpierw asset, potem migracja” (fixture `ios_with_data` → ulubione 5 i 12 oznaczone) i test decyzji
  o wymuszeniu aktualizacji. Agent zmieniający zakładki czyta 90 linii zamiast 217, a dodanie providera nie psuje testów.
  Kolejna migracja (np. ustawień z iOS) ma oczywiste miejsce wywołania.

**Z4. `json_manager.dart` → `data/songbook/songbook_loader.dart`, decyzja o wersji do tej samej klasy**
- *Co:* zmiana nazwy pliku i klasy `JsonManager` → `SongbookLoader`. Logika `main.dart:36–74` („czy wymusić”) dołącza do niej
  jako metoda przyjmująca wersję aplikacji.
- *Dlaczego:* wersjonowanie pieśni jest dziś w dwóch plikach, a nazwa `JsonManager` nie mówi, że chodzi o pieśni.
- *Co daje:* odpowiedź na „gdzie jest wersjonowanie danych pieśni” to jeden plik. Brakujące testy `applySongsData`
  (scalanie duplikatów, usuwanie numerów, zapis `dataVersion` tylko po sukcesie) dostają własny plik `test/data/songbook_loader_test.dart`.

**Z5. Wspólne widgety w `view/widgets/`**
- *Co:* `SongListTile` (3 kopie), `SongContent` (treść + wakelock, 2 kopie), `AppBarAction` (4 kopie), `confirmation_dialog.dart` tutaj.
  Dialogi z `song_detail_view.dart:139–269` przechodzą na wspólny styl.
- *Dlaczego:* P3.
- *Co daje:* zmiana wyglądu wiersza lub treści w jednym pliku; test zgodności wymiarów (`my_songs_view_test.dart:103`)
  staje się zbędny; `song_detail_view.dart` spada z 305 do ~150 linii. Poprawka wakelocka przy `pushReplacement`
  (pułapka 8.7) trafi raz, do `SongContent`.
- *Uwaga:* `favorite_songs_view` używa `Card`, a pozostałe `Container` — widget musi zachować obecny wygląd każdej listy
  albo trzeba świadomie je ujednolicić (decyzja wizualna, Twoja).

**Z6. Logika nawigacji ze `SongDetailView` do `SongViewModel`**
- *Co:* `goToNumber(String input)` zwracające wynik (pieśń / „niepoprawny numer” / „nie znaleziono”),
  `next(song)` / `previous(song)`. Widok tylko pokazuje dialog i wykonuje `pushReplacement`.
  Stała 2000 → liczba pieśni z repozytorium.
- *Dlaczego:* zalecenie „brak logiki w widgetach”, brak testów tej logiki, trzy kopie stałej.
- *Co daje:* testy jednostkowe walidacji numeru bez widgetów; zmiana wielkości śpiewnika nie wymaga zmian w UI.

**Z7. `font_size_model.dart` → `viewmodel/`, klucze ustawień publiczne w jednym miejscu**
- *Co:* przeniesienie pliku (bez zmiany nazwy klasy). Klucze `fontSize`, `lineHeight` jako publiczne stałe.
- *Dlaczego:* P4 (`model/` = tylko encje), P3 (migracja ustawień z iOS potrzebuje tych kluczy).
- *Co daje:* prosta reguła „`model/` = encje, zmiana → `build_runner`”. Migracja ustawień nie kopiuje literałów.

**Z8. Martwy kod, NUL, duplikaty w testach**
- *Co:* lista z 1.5; ` ` w `core_data_migration.dart:184`; `my_song_test.dart` na `TestStore`;
  `core_data_reader_test.dart` na `CoreDataFixtures`.
- *Co daje:* P6 znika (grep i diff działają). `flutter analyze` spada o 3 ostrzeżenia. Agent nie trafia na `Provider<Store>`.

**Z9. `CLAUDE.md`** — treść w kroku 5.

### 3.5 Rzeczy niezwiązane z ekranem — gdzie mają być

| Rzecz | Miejsce | Uzasadnienie |
|---|---|---|
| Czytnik starej bazy iOS | `lib/migration/core_data_reader.dart` (bez zmian) | tylko odczyt SQLite, bez ObjectBoksa |
| Migracja z Core Data | `lib/migration/core_data_migration.dart` (bez zmian) | zapis w jednej transakcji do dwóch encji |
| Kolejne migracje z iOS (np. ustawienia z `UserDefaults`) | `lib/migration/<co>_migration.dart`, wywołanie w `startup/app_startup.dart` | jedna klasa na źródło, wzorzec jak `CoreDataMigration` (wstrzykiwane zależności, flaga „done”, nigdy nie rzuca) |
| Stan migracji do pokazania w UI | publiczna metoda w `CoreDataMigration`, np. `static Future<String?> lastError(SharedPreferences)` | `SettingsViewModel` przestaje znać klucze migracji |
| Wersjonowanie danych pieśni (`dataVersion`, wymuszenie po zmianie wersji aplikacji) | `lib/data/songbook/songbook_loader.dart` | jeden plik zamiast dwóch |
| Kolejność startu | `lib/startup/app_startup.dart` | jedyne miejsce, które wie, co musi być przed czym |
| Budowanie `songs_data.json` | `tools/song_merge/` (bez zmian) | poza aplikacją |

---

## KROK 4 — Plan wdrożenia

### 4.1 Założenia o trwającej migracji z iOS

Nie mam opisu kroków 2 i 3 migracji. Z historii wynika: czytnik (`e9135ee`), migracja ulubionych i własnych pieśni (`9587c6d`),
komunikat o błędzie w ustawieniach (`0a4ad4a`, commit powstał w trakcie tej analizy). Zakładam, że dalsze prace dotykają:
`lib/migration/**`, `lib/main.dart` (wywołanie przy starcie), `settings_view.dart`, `settings_viewmodel.dart`,
`data_migration_notice.dart`, `font_size_model.dart` (jeśli migrowane będą ustawienia), `test/support/platform_fakes.dart`,
`test/core_data_*`, `pubspec.yaml`, być może nowy katalog `ios/`. **Jeśli zakres jest inny, przesuń etapy według tej listy plików.**

**Strefa zamrożona do scalenia migracji:** pliki wymienione wyżej.

### 4.2 Etapy

Każdy etap to osobny PR, po którym `flutter test` i `flutter analyze` przechodzą, a aplikacja działa bez zmian widocznych dla użytkownika
(wyjątki oznaczone). Kolejność od największej korzyści.

| # | Etap | Pliki | Korzyść | Ryzyko | Kto | Kiedy |
|---|---|---|---|---|---|---|
| **1** | `CLAUDE.md` + zamiana NUL na ` ` | `CLAUDE.md`, `core_data_migration.dart:184` | każda kolejna sesja agenta; grep i diff migracji zaczynają działać | bardzo niskie (wartość stringa identyczna, klucz nie jest zapisywany) | agent | **teraz**; NUL najlepiej jako commit na gałęzi migracji |
| **2a** | `MySongRepository` + fake; testy VM i widoków własnych pieśni na fake'u | `my_song_viewmodel.dart`, nowe `data/repositories/my_song_repository.dart`, `test/support/fakes/`, 4 pliki testów, `main.dart:151` (1 linia) | 4 pliki testów bez dylib; wzorzec dla 2b | niskie: 32 istniejące testy są siatką bezpieczeństwa | agent | **teraz** (w `main.dart` jedna linia, konflikt trywialny) |
| **2b** | Testy charakteryzacyjne `SongViewModel` na obecnym kodzie → `SongRepository` + `ReviewService` wstrzykiwany do VM | `song_viewmodel.dart`, nowe repozytorium i serwis, `review_model.dart`, `main.dart:150`, testy | wyszukiwanie i ulubione pod testami; jedno miejsce na zapytania o pieśni | średnie: dziś zero testów, więc najpierw testy na starym kodzie, potem zmiana. **Kolejność list bez zmian** (sortowanie to osobna decyzja) | agent robi, **Ty przeglądasz** testy charakteryzacyjne, zanim ruszy refaktor | **teraz** |
| **3** | Wspólne widgety (`SongListTile`, `SongContent`, `AppBarAction`, dialogi) | `song_list_view`, `favorite_songs_view`, `my_songs_view`, `song_detail_view`, `my_song_detail_view`, `confirmation_dialog` | zmiana wyglądu w jednym miejscu; `song_detail_view` o połowę krótszy | niskie–średnie (wizualne) | agent; **Ty sprawdzasz na urządzeniu** w jasnym i ciemnym motywie | **teraz** (poza strefą migracji); nie ruszać `settings_view` |
| **4** | Logika nawigacji `SongDetailView` → `SongViewModel`, stała 2000 z repozytorium | `song_detail_view`, `song_viewmodel`, testy | testy walidacji numeru i swipe bez widgetów | niskie po 2b i 3 | agent | po 2b i 3 |
| **5** | Martwy kod + duplikaty w testach (bez `core_data_reader_test`) | lista 1.5, `my_song_test.dart`, `pubspec.yaml` (`win32`, asset ikony), `assets/songs.sqlite` | mniej fałszywych tropów, czysty analyzer | bardzo niskie; `pubspec.yaml` może kolidować z migracją | agent | **teraz**, część `pubspec.yaml` i `core_data_reader_test` po scaleniu migracji |
| **6** | Start: `startup/app_startup.dart`, `app.dart`, `view/home_screen.dart`, `buildAppProviders()`, test kolejności startu | `main.dart`, nowe pliki, `widget_test`, `home_screen_test` | P2: test kolejności asset → migracja, test wymuszenia aktualizacji, dodanie providera nie psuje testów | **średnie–wysokie**: tu uruchamia się migracja i aktualizacja danych użytkowników | agent pisze, **Ty uważnie przeglądasz** ścieżki błędów i kolejność | **po scaleniu migracji** |
| **7** | `JsonManager` → `SongbookLoader` + decyzja o wersji z `main.dart` + brakujące testy `applySongsData` | `json_manager.dart`, `main.dart`/`app_startup.dart`, `my_song_test.dart`, `json_manager_test.dart` | wersjonowanie pieśni w jednym pliku i pod testami | średnie (dane użytkowników: ulubione przy aktualizacji) | agent; **Ty przeglądasz** nowe testy | po 6 |
| **8** | `font_size_model.dart` → `viewmodel/`, publiczne klucze; stan błędu migracji jako metoda `CoreDataMigration`; `SettingsViewModel` na `AppInfoService` | `font_size_model`, `settings_viewmodel`, `data_migration_notice`, testy | `model/` = encje; migracja ustawień nie kopiuje kluczy | niskie | agent | **po scaleniu migracji** albo razem z migracją ustawień z iOS |
| **9** | Przeniesienie testów migracji do `test/migration/`, testów danych do `test/data/` | tylko `test/` | nazwy i położenie testów odpowiadają kodowi | bardzo niskie | agent | na końcu, po scaleniu migracji |

Poza planem (decyzje zachowania, nie struktury — osobne PR-y z Twoją decyzją):
jawne sortowanie list po numerze, zliczanie uruchomień poza `build`, wakelock przy `pushReplacement`, wielokrotny swipe,
wymuszanie aktualizacji tekstów przy każdej zmianie numeru builda (`main.dart:52`), skoro jest już `dataVersion`.

### 4.3 Podsumowanie

- **Teraz, bez konfliktów:** 1, 2a, 2b, 3, 4, 5 (bez `pubspec.yaml`).
- **Po scaleniu migracji:** 6, 7, 8, 9 i część 5.
- **Bezpiecznie dla agenta bez Twojego udziału poza zwykłym przeglądem:** 1, 2a, 4, 5, 9.
- **Wymagają Twojej uwagi:** 2b (akceptacja testów charakteryzacyjnych), 3 (wygląd na urządzeniu), 6 i 7 (dane użytkowników przy starcie).

---

## KROK 5 — Proponowana treść `CLAUDE.md`

Treść opisuje stan **docelowy po etapach 1–2** i jest oznaczona tam, gdzie reguła obowiązuje dopiero po danym etapie.
Po każdym etapie planu zaktualizuj sekcję „Gdzie co leży”.

````markdown
# Śpiewnik — instrukcja dla agentów

Aplikacja Flutter, bez backendu. Dane lokalnie: 2000 pieśni z `assets/songs_data.json` w ObjectBoksie,
ulubione (pole `Song.favorite`), własne pieśni (`MySong`), ustawienia w SharedPreferences.
Trwa migracja użytkowników ze starej aplikacji iOS (Swift, Core Data). UI po polsku, kod, komentarze i commity po angielsku.

## Gdzie co leży
- `lib/main.dart` — start: store → asset pieśni → migracja iOS → runApp. KOLEJNOŚĆ MA ZNACZENIE (migracja dopasowuje ulubione po numerze).
- `lib/model/` — encje ObjectBoksa (`Song`, `MySong`). Po zmianie: `dart run build_runner build`.
- `lib/data/repositories/` — jedyny dostęp do ObjectBoksa dla view modeli (od etapu 2).
- `lib/json_manager.dart` — parsowanie assetu (`SongsData`), aktualizacja pieśni z zachowaniem ulubionych, `dataVersion`.
- `lib/migration/` — czytnik starej bazy iOS (`core_data_reader.dart`) i jednorazowa migracja (`core_data_migration.dart`).
- `lib/viewmodel/` — view modele: zwykłe klasy z `ValueNotifier`, zależności w konstruktorze. Wzorzec: `my_song_viewmodel.dart`.
- `lib/view/` — ekrany; wspólne widgety w `lib/view/widgets/` (od etapu 3).
- `test/support/` — `TestStore`, `CoreDataFixtures`, atrapy kanałów platformy, fake'i repozytoriów.
- Dokumenty: `SCHEMA-ZMYSONG.md` (schemat bazy iOS), `docs/PARITY.md` (różnice iOS/Android), `test/fixtures/README.md`.

## Zasady
- `Store`/`Box` używaj tylko w `lib/data/`, `lib/migration/`, `lib/main.dart`. Nigdy w widokach ani view modelach.
- Nowa funkcja: widok w `lib/view/`, VM w `lib/viewmodel/`, dane przez repozytorium. VM przez konstruktor, `Provider` tylko dla obiektów całej aplikacji.
- Plugin platformy (wakelock, share, url_launcher, in_app_review, package_info) — owinąć w klasę wstrzykiwaną albo testować atrapą kanału z `test/support/platform_fakes.dart`.
- Czas przez wstrzykiwane `DateTime Function() now`, ścieżki i platformę przez parametry (wzorzec: `CoreDataMigration.runOnStartup`).
- Logowanie przez wstrzykiwany `Logger`, nie `print`.
- Każda zmiana z testem. Testy VM i widoków na fake'ach, testy repozytoriów i migracji na `TestStore` i fixtures.

## Czego nie ruszać
- `lib/objectbox-model.json` — UID-y schematu. Nie usuwać, nie edytować ręcznie. Usunięcie = niezgodna baza u użytkowników.
- `lib/objectbox.g.dart` — tylko przez `build_runner`.
- `test/fixtures/*.sqlite*` — prawdziwe bazy z iOS, tylko do odczytu. Dane syntetyczne twórz na kopiach (`CoreDataFixtures.copyTo` + `changeCopy`) i oznaczaj komentarzem `SYNTHETIC DATA`. Puste `-wal` i `-shm` są celowo.
- Kluczy SharedPreferences (`fontSize`, `lineHeight`, `launch_count`, `last_run_app_version`, `songs_data_version`, `coreDataMigration*`) — są na urządzeniach użytkowników.
- `assets/songs_data.json` — generowany przez `tools/song_merge/`, nie edytować ręcznie.

## Testy
```sh
tools/fetch_objectbox_lib.sh   # raz po klonie: pobiera lib/libobjectbox.dylib (gitignored)
flutter test                   # całość
flutter test test/my_song_viewmodel_test.dart
flutter analyze
```

## Pułapki
- Bez `lib/libobjectbox.dylib` padają wszystkie testy używające `TestStore`. To brak biblioteki, nie błąd w kodzie.
- `openStore()` w `testWidgets` wisi (path_provider bez implementacji). Zawsze `TestStore.open()`.
- Migracja iOS uruchamia się przy każdym starcie na iOS, ale działa raz: flaga `coreDataMigrationDone`. Po błędzie ustawia też `coreDataMigrationFailed` i NIE ponawia. Nigdy nie rzuca, nigdy nie usuwa starej bazy. Oryginału nie otwiera — czyta kopię z `-wal`/`-shm`.
- Nie filtruj po `Z_ENT` w bazie iOS (numeracja encji różni się między plikami, patrz `SCHEMA-ZMYSONG.md`).
- Zmiana wersji aplikacji (także numeru builda) nadpisuje tytuły i treści wszystkich pieśni z assetu. Pieśni spoza assetu są usuwane razem ze statusem ulubionej.
- `core_data_migration.dart` zawiera bajt NUL w kluczu, więc git i grep traktują plik jako binarny — czytaj go narzędziem Read (do czasu poprawki z etapu 1).
- Nie ma katalogu `ios/`.
- SQLite w testach czytnika idzie przez `sqflite_common_ffi`; na Linuksie potrzebny `libsqlite3-dev`.

## Commity
Conventional commits: `feat(scope): …`, `fix`, `test`, `deps`, `docs`, `chore`. Jeden etap / jedna zmiana na PR.
````
