# PARITY — Śpiewnik iOS vs Android

Źródła:
- iOS: `/Users/natanielmarmucki/Spiewnik/AUDIT.md` (w prośbie nazwany `AUDIT-ios.md`). Opisuje stan HEAD `37f0a8e`, wersję `11.2024`, Core Data.
- Android: `/Users/natanielmarmucki/StudioProjects/Spiewnik/AUDIT.md` (w prośbie nazwany `AUDIT-flutter.md`). Opisuje kopię roboczą `1.2.1+5`, ObjectBox.

Dokument pokazuje wyłącznie różnice i zgodności. Nie ocenia, która wersja jest właściwa. Oznaczenie **NIEPOTWIERDZONE** jest przeniesione z audytów. Numery linii są w audytach źródłowych.

Oznaczenia w kolumnie „Rozbieżność”:
- **—** zgodne,
- **R** różnica w zachowaniu lub wartościach,
- **B** funkcja tylko po jednej stronie.

---

## 1. Zestawienie funkcji

| Funkcja | iOS | Android | Rozbieżność |
|---|---|---|---|
| **Nawigacja główna** | `TabView`, 3 zakładki: „Śpiewnik”, „Ulubione”, „Moje pieśni” | `ConvexAppBar` (`TabStyle.reactCircle`), 2 zakładki: „Śpiewnik”, „Ulubione” | **B/R.** Brak zakładki „Moje pieśni” na Androidzie. Inny komponent paska. |
| Układ na tablet | Osobne widoki `*SplitView` (`NavigationSplitView`: lista + szczegóły) dla `.pad` | Brak rozróżnienia, ten sam układ na każdym ekranie | **R** |
| Wejście do ustawień | Zębatka tylko w zakładce „Śpiewnik”; ustawienia otwierają się jako arkusz (`.sheet`) | Ikona `Icons.settings` w `AppBar`, dostępna z obu zakładek; `Navigator.push` | **R** |
| Tytuł paska na liście | „Śpiewnik” / „Ulubione” / „Moje pieśni” zależnie od zakładki | Zawsze `'Śpiewnik'` | **R** |
| **Lista pieśni: sortowanie** | Jawne: `number` rosnąco (`NSSortDescriptor`) | Od 12.0.0 jawne: `number` rosnąco w zapytaniu repozytorium | **—** |
| Lista pieśni: wygląd wiersza | `"<number>. "` (headline) + tytuł, 1 linia, serce przy ulubionych | Od 12.0.0 wspólny wiersz: tytuł (Newsreader 17), linia wiodąca z kropek, numer na prawej krawędzi, serce 11 dp przy tytule | **R** (wizualnie) |
| Ulubione: zawijanie długiego tytułu | 1 linia | Do 12.0.0 tytuł zawijał się do wielu linii (wiersz na `Card`, bez `maxLines`); od 12.0.0 jedna linia z wielokropkiem, jak na pozostałych listach | **—** świadoma zmiana z systemu wizualnego |
| Fallback pustego tytułu | `"Brak tytułu"` (lista główna, szczegóły) / `"Brak tytuł"` (ulubione, moje pieśni) | Brak. `title` jest typu `String` non-null. | **R** |
| Szybkie przewijanie z etykietą numeru | Brak | Usunięte w 12.0.0 razem z paczką `draggable_scrollbar`; zastępuje je stała wyszukiwarka | **—** |
| **Wyszukiwanie: pola** | `content` (po oczyszczeniu) + podciąg `number` | `content` (po oczyszczeniu) + podciąg `number` | **—** |
| Wyszukiwanie: tytuł | Nieprzeszukiwany: filtr sprawdza tylko treść i numer | Od 12.0.0 przeszukiwany razem z treścią i numerem, trafienie podświetlone akcentem w tytule | **R** — świadome ulepszenie z systemu wizualnego |
| Wyszukiwanie: białe znaki po usunięciu ignorowanych znaków | Usunięcie znaku wewnątrz tekstu zostawia podwójną spację (przycinane są tylko końce), więc „boży zmiłuj” nie pasuje do „Baranku Boży, x zmiłuj się”, a „boży  zmiłuj” tak | To samo zachowanie | **—** wspólne zachowanie, **błąd, nie decyzja projektowa**. Do naprawy przy grupie A: normalizacja białych znaków po usunięciu ignorowanych znaków |
| Wyszukiwanie: usuwane znaki z treści | `1 2 3 4 5 6 7 8 9 , . ; : ' [ ] ( ) ! ? - ” — „ x` | `"123456789,.;:'[]()!?-”—„x"` (ten sam zestaw) | **—** |
| Wyszukiwanie: obróbka zapytania | Tylko `lowercased()` | Tylko `toLowerCase()` | **—** |
| Wyszukiwanie: polskie znaki | Brak normalizacji diakrytyków | Od 12.0.0: polskie litery zamieniane na litery bazowe w treści i w zapytaniu (`removePolishDiacritics`), więc „zrodlo” znajduje „źródło” i odwrotnie | **R** — świadome ulepszenie, nie odtworzenie zachowania iOS (stara wersja Androida też tego nie miała) |
| Wyszukiwanie: wyzwalanie | Zależne od ustawienia: po zatwierdzeniu (`onCommit`) albo dynamicznie z debounce **0,5 s** | Zawsze dynamicznie, debounce **250 ms** | **R** |
| Wyszukiwanie: przycisk „Anuluj” | Jest (chowa klawiaturę, czyści) | Brak; jest ikona `Icons.cancel` (czyści, przewija na górę) | **R** |
| Wyszukiwanie w ulubionych | Brak | Brak | **—** |
| Wyszukiwanie we własnych pieśniach | Pole widoczne, **nie filtruje** | Brak funkcji | **B** (i martwa funkcja po stronie iOS) |
| Własne pieśni: sortowanie listy | `title` rosnąco (`NSSortDescriptor` bez porównania uwzględniającego lokalizację): kolejność punktów kodowych Unicode, polskie znaki diakrytyczne za „Z”, wielkie litery przed małymi | Od 12.0.0: `title` rosnąco według polskiego alfabetu (Ł po L, Ż po Ź), bez rozróżniania wielkości liter; te same tytuły po `id` rosnąco | **R** — świadome ulepszenie, nie odtworzenie zachowania iOS |
| **Szczegóły: tytuł paska** | `"<number>. <title>"` | `'${song.number}. ${song.title}'` | **—** |
| Szczegóły: wyświetlanie treści | Jeden `Text`, bez parsowania | Jeden `Text`, bez parsowania | **—** |
| **Przejście do numeru: wejście** | `UIAlertController`, klawiatura `.numberPad`, brak limitu długości | `AlertDialog`, `digitsOnly`, maks. 4 znaki | **R** |
| Przejście do numeru: zakres | 1…2000 (zakodowane) | Od 12.0.0: 1…liczba pieśni w bazie, bez zakodowanej wartości | **—** zachowanie takie samo przy pełnym śpiewniku |
| Przejście do numeru: błąd | Alert „Podano niepoprawny numer” / „W śpiewniku znajdują się 2000 pieśni.”; po OK dialog wejściowy otwiera się ponownie | Dialog „Uwaga”: „Podano niepoprawny numer. W śpiewniku znajduje się N pieśni.” (N z bazy) lub „Pieśń o podanym numerze nie została znaleziona”; bez ponownego otwarcia | **R** |
| Przejście do numeru: mechanizm | Podmiana `song` w tym samym widoku; `currentIndex` **nie** jest aktualizowany | `Navigator.pushReplacement` na nowy `SongDetailView` | **R** |
| **Swipe poprzednia/następna** | `DragGesture(minimumDistance: 50)`, rozstrzygane na końcu gestu; `width > 0` → poprzednia, pozostałe → następna | `onPanUpdate` przy każdym zdarzeniu z `\|dx\| > 10` (NIEPOTWIERDZONE: wielokrotne wyzwolenie) | **R** |
| Swipe: po przejściu do numeru | Liczy od pierwotnie otwartej pieśni | Liczy od wyświetlanej pieśni | **R** |
| **Ulubione: przełączanie** | Tylko z ekranu szczegółów | Tylko z ekranu szczegółów | **—** |
| Ulubione: sortowanie listy | Jawne: `number` rosnąco | Od 12.0.0 jawne: `number` rosnąco | **—** |
| Ulubione: komunikat pustej listy | „Lista ulubionych pieśni jest pusta” | Stan pusty z systemu wizualnego: ikona, nagłówek i zdanie mówiące co zrobić | **R** |
| **Udostępnianie** | Systemowy `UIActivityViewController`, tylko treść; **tylko iPhone** | Ikona `Icons.share`, ale **kopiuje do schowka** i pokazuje SnackBar „Treść skopiowana do schowka” | **R** |
| **Własne pieśni: dodawanie / edycja / usuwanie** | Jest (usuwanie tylko iPhone) | Brak | **B** |
| Skanowanie tekstu aparatem (Live Text) | Jest, warunkowo; zastępuje całą treść | Brak | **B** |
| **Rozmiar czcionki** | Klucz `isSize`; domyślnie 16 (iPhone) / 24 (iPad); zakres 10…30 (iPhone) / 24…44 (iPad), krok 2 | Klucz `fontSize`; domyślnie 16.0; zakres 10…30, krok 2 | **R** (iPad) |
| **Interlinia** | Klucz `isLineSpacing`; **dodatkowe punkty** (`lineSpacing`); domyślnie 0; zakres 0…10, krok 1 | Klucz `lineHeight`; **mnożnik** (`TextStyle.height`); domyślnie 1.5; zakres 1.0…3.0, krok 0.2 | **R** (inna jednostka i semantyka) |
| Reset ustawień | `isLineSpacing = 0`, `isSize = 16` (także na iPadzie) | `fontSize = 16.0`, `lineHeight = 1.5` | **R** |
| Podgląd tekstu w ustawieniach | Jest (ten sam fragment „Alleluja, chwalcie Pana…”) | Jest (ten sam fragment) | **—** |
| Przełącznik „Dynamiczna wyszukiwarka” | Jest (`isSearchDynamic`) | Brak | **B** |
| **Tryb nocny** | Systemowy, brak przełącznika | Systemowy (`ThemeMode.system`), brak przełącznika; własne motywy `lightTheme` / `darkTheme` | **—** (brak przełącznika po obu stronach); **R** (kolorystyka) |
| **Blokada wygaszania ekranu** | Brak | Zawsze włączona na ekranach szczegółów pieśni i własnej pieśni (`wakelock_plus`), bez ustawienia (przełącznik planowany w A3). **Naprawione w 12.0.0:** wcześniej po `pushReplacement` (przejście do numeru, przeciągnięcie na następną lub poprzednią pieśń) blokada się wyłączała, bo `dispose` starego ekranu wywoływał `disable` po `enable` nowego. Teraz `ScreenWakeLock` liczy otwarte ekrany: `enable` przy przejściu z 0 na 1, `disable` z 1 na 0; testy w `test/song_detail_view_wakelock_test.dart` | **B** |
| Link „Kontakt” | `https://spiewnik.odoo.com/contactus` | `https://spiewnik.odoo.com/contactus` | **—** |
| Link „O mnie” | `https://spiewnik.odoo.com/about-us` | `https://spiewnik.odoo.com/about-us` | **—** |
| „Wesprzyj” | Link `https://suppi.pl/spiewnik` (+ niepodpięty kod zakupów) | Link `https://suppi.pl/spiewnik` | **—** w UI; **R** w kodzie |
| „Zgłoś błąd”: adres | `mailto:n.marmucki@icloud.com` | `mailto:n.marmucki@icloud.com` | **—** |
| „Zgłoś błąd”: temat | `Zgłoszenie błędu w aplikacji Śpiewnik <wersja>` | `Zgłoszenie błędu w aplikacji Śpiewnik (<wersja>)` — z nawiasami, `packageInfo.version` bez builda | **R** |
| „Zgłoś błąd”: obsługa błędu | Alerty „Błąd” / „Zgłoś błąd” z kopiowaniem adresu | `print` w konsoli, brak komunikatu dla użytkownika | **R** |
| **Changelog po aktualizacji** | Alert „Nowa wersja <v>” z tekstem dla `9.2024`/`10.2024`/`11.2024`; przyciski „OK”, „Zgłoś błąd”, „Wesprzyj”; także przy pierwszej instalacji | Brak | **B** |
| **Prośba o ocenę: wyzwalacz** | `scenePhase == .active` + licznik uruchomień | (a) licznik w `MyApp.build`; (b) pierwsze dodanie ulubionej w sesji | **R** |
| Prośba o ocenę: progi | `[20, 50, 90, 140, 200, 270, 300, 390, 490, 640, 840, 1140, 1440, 1940]` | `[5, 10, 50, 100, 250, 500, 750, 1000]` | **R** |
| Prośba o ocenę: limit per wersja | Tak (`lastVersionPromptedForReviewKey`) | Nie | **R** |
| Prośba o ocenę: inkrementacja licznika | +2 na uruchomienie (`init` + `onAppear`) | +1 na każdy `MyApp.build` (NIEPOTWIERDZONE, jak często) | **R** |
| Aktualizacja tekstów u istniejących użytkowników | Mechanizm `update()` wywoływany przy zmianie wersji; w HEAD funkcje puste | Mechanizm `_updateStoreFromJson` przy zmianie wersji; niedziałający (rzutowanie Map → List) | **R** (mechanizm); po obu stronach obecnie brak skutecznych aktualizacji |
| Zakupy w aplikacji | Kod StoreKit 1 i 2, **niepodpięty** | Brak | **B** (tylko martwy kod) |
| Orientacja | Portrait, LandscapeLeft, LandscapeRight; `UIRequiresFullScreen = true` | Brak blokady | **R** |
| Pasek statusu | `UIStatusBarHidden = true` | Domyślny | **R** |
| Splash | `Launch Screen.storyboard` (obraz `applogo`) | `flutter_native_splash` (biały / czarny, `playstore-transparent.png`) | **R** |

---

## 2. Funkcje obecne tylko po jednej stronie

### Tylko iOS

| Funkcja | Uwagi z audytu |
|---|---|
| „Moje pieśni”: lista, dodawanie, podgląd, edycja, usuwanie | Usuwanie tylko na iPhonie; wyszukiwarka w tej zakładce nie filtruje |
| Skanowanie tekstu aparatem (Live Text) przy dodawaniu i edycji własnej pieśni | Warunkowo, gdy `captureTextFromCamera` jest dostępne |
| Systemowy arkusz udostępniania | Tylko iPhone |
| Przełącznik „Dynamiczna wyszukiwarka” (tryb wyszukiwania po zatwierdzeniu) | — |
| Układ dwukolumnowy (`NavigationSplitView`) na iPadzie | — |
| Alert „Nowa wersja” z changelogiem | — |
| Limit prośby o ocenę raz na wersję | — |
| Kod zakupów w aplikacji (StoreKit 1 + StoreKit 2, `Configuration.storekit`) | Niepodpięty, nieosiągalny z UI |
| Osobne rozmiary domyślne i zakresy czcionki dla iPada | — |

### Tylko Android

| Funkcja | Uwagi z audytu |
|---|---|
| Blokada wygaszania ekranu na ekranie szczegółów | Zawsze włączona, bez ustawienia |
| Kopiowanie treści do schowka z SnackBarem | W miejscu udostępniania |
| Prośba o ocenę po pierwszym dodaniu ulubionej | Raz na uruchomienie |
| Wejście do ustawień z każdej zakładki | — |
| Komunikat „Pieśń o podanym numerze nie została znaleziona” | Osobny od „niepoprawny numer” |

---

## 3. Różnice w schemacie danych pieśni

### 3.1 Źródło i format

| Aspekt | iOS | Android |
|---|---|---|
| Plik źródłowy w repo | `Model.sqlite` (katalog główny repo, 1 732 608 B) | `assets/songs_data.json` (1 629 390 B) |
| Format | SQLite w formacie store’u Core Data | JSON: `{"songs": [ {...}, ... ]}` |
| Baza robocza na urządzeniu | Kopia pliku: `Documents/Model.sqlite` | ObjectBox: `<getApplicationDocumentsDirectory()>/objectbox` (dokładna ścieżka NIEPOTWIERDZONA) |
| Moment załadowania | Skopiowanie pliku, gdy nie istnieje | `putMany` z JSON, gdy box jest pusty |
| Liczba pozycji | 2000 | 2000 |
| Zakres `number` | 1…2000, unikalne, bez luk | 1…2000, unikalne, posortowane |
| Treść zawiera `\n` / `\r` | 1938 / 0 | 1938 / 0 |
| Dane wbudowane / pobierane | Wbudowane | Wbudowane |

### 3.2 Pola

| Pole logiczne | iOS: atrybut Core Data | iOS: kolumna SQLite | iOS: typ, opcjonalność | Android: pole Dart / ObjectBox | Android: typ, opcjonalność | Android: klucz JSON | Rozbieżność |
|---|---|---|---|---|---|---|---|
| Identyfikator techniczny | — (niejawny `Z_PK`) | `Z_PK INTEGER PRIMARY KEY` | — | `id` (`@Id()`) | `int`, auto; ObjectBox `type 6`, `flags 1` | brak w JSON | **R.** W bundlu iOS `Z_PK` = `ZNUMBER`; na Androidzie `id` jest nadawane przez ObjectBox. |
| Numer | `number` | `ZNUMBER INTEGER` | `Integer 64`, **optional = YES**, domyślnie `0` | `number` (`@Index()`) | `int`, **wymagane**; `type 6`, `flags 8` (indeks) | `number` (`as int`, wymagany) | **R.** Opcjonalność, indeks (iOS bez indeksu). Unikalność niewymuszona po obu stronach. |
| Tytuł | `title` | `ZTITLE VARCHAR` | `String`, **optional = YES** | `title` | `String`, **non-null**; `type 9` | `title` (`as String`, wymagany) | **R** (opcjonalność) |
| Treść | `content` | `ZCONTENT VARCHAR` | `String`, **optional = YES** | `content` | `String`, **non-null**; `type 9` | `content` (`as String`, wymagany) | **R** (opcjonalność) |
| Ulubiona | `favorite` | `ZFAVORITE INTEGER` | `Boolean` scalar, **optional = YES**, brak domyślnej w modelu; w bundlu `0` | `favorite` | `bool`, **non-null**; `type 1` | `favorite` (`as bool? ?? false`, **opcjonalny**; w pliku nie występuje) | **R** (opcjonalność, źródło wartości początkowej) |
| Kolumny techniczne | — | `Z_ENT` (NULL w bundlu), `Z_OPT` (1 w bundlu) | — | — | — | — | **B** (tylko iOS) |

Nazwy encji: iOS `Song` (tabela `ZSONG`), Android `Song` (UID encji `1:668007825265052091`).

### 3.3 Różnice w zawartości

| Aspekt | Wartość |
|---|---|
| Różne tytuły | 3: nr `923` (iOS `'Gdy idziesz sam'` / Android `'Zjednani sercem i ustami'`), nr `1497` i `1498` (tytuły zamienione miejscami) |
| Różne treści | 58 pozycji; pierwsze: `292`, `450`, `686`, `898`, `900`, `923`, `930`, `939`, `944`, `959` |
| Konwencje zapisu treści | Zgodne: `"1. "`, `"Refren: "`, `\n\n` między akapitami, `[:…:]`, `/…/3x` |
| Zawartość na urządzeniach użytkowników | iOS: może różnić się od repo (historyczne poprawki przez `update()`). Android: pozostaje taka, jak przy pierwszej instalacji (aktualizacja nie działa). |

### 3.4 Aktualizacja danych pieśni

| Aspekt | iOS | Android |
|---|---|---|
| Wyzwalacz | Zmiana `CFBundleShortVersionString` względem `lastInstalledVersion` | Zmiana `"<version>+<buildNumber>"` względem `last_run_app_version` |
| Zakres | Pojedyncze pieśni wskazane w kodzie (`update(number:title:content:)`) | Cały plik JSON |
| Zachowanie `favorite` | Zachowane | Zachowane (dopasowanie po `number`) |
| Dodawanie nowych numerów | Brak | Tak |
| Usuwanie numerów spoza źródła | Brak | Tak, razem ze statusem ulubionej |
| Stan obecny | Funkcje puste w HEAD | Rzuca wyjątek, który jest łapany; wersja i tak zapisywana |

---

## 4. Różnice w sposobie zapisu danych użytkownika

### 4.1 Mechanizmy

| Rodzaj danych | iOS: mechanizm | Android: mechanizm | Rozbieżność |
|---|---|---|---|
| Ulubione | Core Data (SQLite), ten sam plik co teksty | ObjectBox, ten sam obiekt co teksty | **R** (silnik); **—** (brak rozdzielenia od treści po obu stronach) |
| Własne pieśni | Core Data, encja `MySong` | Nie istnieją | **B** |
| Historia / ostatnio otwierane | Brak | Brak | **—** |
| Ustawienia wyświetlania | `UserDefaults.standard` | `SharedPreferences` (legacy API) | **R** |
| Metadane (licznik, wersje) | `UserDefaults.standard` (w tym `@AppStorage`) | `SharedPreferences` | **R** |
| Synchronizacja chmurowa | Brak | Brak | **—** |
| Wersjonowanie schematu | Jedna wersja modelu Core Data, brak mapping models; `MySong` dopisany bez wersjonowania (niejawna migracja lekka, NIEPOTWIERDZONA) | `objectbox-model.json` (UID-y, `version: 1`), brak własnych migracji | **R** |

### 4.2 Ulubione

| Aspekt | iOS | Android |
|---|---|---|
| Lokalizacja | `Documents/Model.sqlite` (+ ewent. `-wal`, `-shm`, NIEPOTWIERDZONE) | katalog `objectbox` (nazwy plików NIEPOTWIERDZONE) |
| Tabela / encja | `ZSONG` / `Song` | `Song` |
| Kolumna / pole | `ZFAVORITE` / `favorite` | `favorite` |
| Typ zapisany | INTEGER `0`/`1` | ObjectBox Bool (`type 1`) |
| Powiązanie z pieśnią | Ten sam wiersz; `ZNUMBER` | Ten sam obiekt; `number` (i `id`) |
| Kolejność / data dodania | Nie zapisywana | Nie zapisywana |
| Moment zapisu | `save()` po przełączeniu + zapis kontekstu przy przejściu w tło | `box.put(song)` od razu |

### 4.3 Własne pieśni (tylko iOS)

| Aspekt | iOS | Android |
|---|---|---|
| Encja | `MySong` | — |
| Pola | `title` (`String`, optional), `content` (`String`, optional) | — |
| Identyfikator | Brak własnego (tylko `Z_PK`) | — |
| Daty | Brak | — |
| Tabela na urządzeniu | `ZMYSONG` wg konwencji Core Data; brak w bundlu, kolumny i `Z_ENT` NIEPOTWIERDZONE | — |

### 4.4 Klucze ustawień i metadanych

| Znaczenie | iOS: klucz (`UserDefaults`) | iOS: typ, domyślna | Android: klucz w kodzie | Android: klucz fizyczny | Android: typ fizyczny, domyślna |
|---|---|---|---|---|---|
| Rozmiar czcionki | `isSize` | `CGFloat` (NSNumber); 16 iPhone / 24 iPad | `fontSize` | `flutter.fontSize` | `String` z prefiksem `VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu`; 16.0 |
| Interlinia | `isLineSpacing` (punkty) | `CGFloat`; 0 | `lineHeight` (mnożnik) | `flutter.lineHeight` | `String` z prefiksem jw.; 1.5 |
| Tryb wyszukiwarki | `isSearchDynamic` | `Bool`; `false` | — | — | — |
| Rozmiar ikon | `isSizeImg` (tylko odczyt; zapis trafia pod `isSize`) | `CGFloat`; 16 / 24 | — | — | — |
| Nieużywany licznik | `counter` | `Int`; 0 | — | — | — |
| Licznik uruchomień | `engagementCounterKey` | `Int`; 0 | `launch_count` | `flutter.launch_count` | `long`; 0 |
| Ostatnia wersja (zmiana wersji) | `lastInstalledVersion` | `String`, format `M.RRRR` (np. `11.2024`); `""` | `last_run_app_version` | `flutter.last_run_app_version` | `String`, format `<version>+<build>` (np. `1.2.1+5`); `null` |
| Wersja ostatniej prośby o ocenę | `lastVersionPromptedForReviewKey` | `String` | — | — | — |

Plik fizyczny na Androidzie: `FlutterSharedPreferences`. Na iOS klucze leżą bez prefiksu w `UserDefaults.standard`. Z kodu pakietu `shared_preferences` (legacy) wynika, że Flutter na iOS zapisuje klucze z prefiksem `flutter.` w `NSUserDefaults`.

### 4.5 Kopia robocza iOS (niewydana, dla kompletności)

| Element | Wartość |
|---|---|
| Nowe klucze `UserDefaults` | `RealmMigrationCompleted` (`Bool`), `ObjectBoxMigrationCompleted` (`Bool`) |
| Realm `Song` | `id: ObjectId` (PK), `number: Int`, `title: String`, `content: String`, `favorite: Bool`, `lastModified: Date` |
| Realm `MySong` | `id: ObjectId` (PK), `title`, `content`, `createdAt: Date`, `lastModified: Date` |
| ObjectBox `SongEntity` | `id: UInt64`, `number: Int64`, `title`, `content`, `category: String`, `favorite: Bool` |
| ObjectBox `MySongEntity` | `id: UInt64`, `title`, `content`, `createdDate: Date` |
| Różnica względem Androida | Encja ObjectBox iOS ma dodatkowe pole `category`; nazwy encji `SongEntity` vs `Song`; typ `number` `Int64` vs `int` (Dart int 64-bit) |
