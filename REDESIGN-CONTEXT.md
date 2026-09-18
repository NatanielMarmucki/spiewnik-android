# Kontekst warstwy wyglądu — materiał do redesignu

Stan: `main` po PR #26, Flutter 3.47.4. Dokument tylko opisuje istniejący kod: nie proponuje zmian i nie ocenia
obecnych rozwiązań. Odnośniki mają postać `plik:linia`.

Warstwa wyglądu to `lib/main.dart` (start, pasek górny i dolny), `lib/view/` (11 plików) i `lib/theme/theme.dart`.

---

## 1. Inwentarz ekranów

### 1.1 `HomeScreen` — ramka aplikacji
`lib/main.dart:134-222`. Pierwszy ekran po starcie, zawsze widoczny pod spodem zakładek.

| Element | Miejsce | Uwagi |
|---|---|---|
| Pasek górny, tytuł „Śpiewnik”, wyśrodkowany, pogrubiony | `main.dart:170-175` | Ten sam tytuł na wszystkich trzech zakładkach |
| Przycisk „+” (`Icons.add`, tooltip „Dodaj pieśń”) | `main.dart:177-187` | **Tylko na zakładce 2**; otwiera `MySongFormView` |
| Przycisk ustawień (`Icons.settings`, bez tooltipa) | `main.dart:188-196` | Widoczny na wszystkich zakładkach |
| `IndexedStack` z trzema zakładkami | `main.dart:199-202` | Zakładki nie są niszczone przy przełączaniu, więc pozycja przewijania i tekst wyszukiwania przeżywają zmianę zakładki |
| `ConvexAppBar` (dolny pasek) | `main.dart:203-219` | `TabStyle.reactCircle`, `curveSize: 80` |

Stany: brak stanu ładowania i błędu. Dane są gotowe przed `runApp` (`main.dart:79-101`), więc pierwszy klatka
ma już pełną listę.

### 1.2 `SongListView` — zakładka „Śpiewnik”
`lib/view/song_list_view.dart`.

| Element | Miejsce |
|---|---|
| Pole wyszukiwania, podpowiedź „Szukaj”, ikona `Icons.search` z przodu | `song_list_view.dart:52-73` |
| Przycisk czyszczenia `Icons.cancel`, tylko gdy pole niepuste | `song_list_view.dart:57-62` |
| Pasek szybkiego przewijania z etykietą numeru | `song_list_view.dart:83-93` |
| Wiersz listy: numer w kółku, tytuł, serce przy ulubionej | `song_list_view.dart:101-167` |
| Dotknięcie wiersza → `SongDetailView` | `song_list_view.dart:156-160` |

Stany:
- **z danymi** — jedyny w pełni obsłużony;
- **pusty wynik wyszukiwania** — **nieobsłużony**: `ListView` z zerem elementów, bez żadnego komunikatu; ekran jest po prostu pusty;
- **pusta baza** — jw.; w praktyce nie występuje, bo pieśni ładują się z assetu przed startem;
- **ładowanie** — brak (dane synchronicznie z ObjectBoksa);
- **błąd** — brak obsługi w widoku; błąd ładowania danych trafia tylko do logu (`main.dart:62`).

Długie treści:
- tytuł: `maxLines: 1` + `TextOverflow.ellipsis` (`song_list_view.dart:147-149`);
- wysokość wiersza jest **stała**: `itemExtent: 70.0` (`song_list_view.dart:98`), więc dłuższy tytuł nie zwiększa wiersza;
- numery czterocyfrowe (do 2000) mieszczą się w `CircleAvatar` bez zmiany rozmiaru czcionki.

### 1.3 `FavoriteSongsView` — zakładka „Ulubione”
`lib/view/favorite_songs_view.dart`.

| Element | Miejsce |
|---|---|
| Komunikat pustej listy „Brak ulubionych pieśni” | `favorite_songs_view.dart:19-26` |
| Wiersz listy (na `Card`, nie na `Container`) | `favorite_songs_view.dart:31-86` |
| Dotknięcie wiersza → `SongDetailView` | `favorite_songs_view.dart:71-80` |

Różnice wobec listy głównej, choć wiersz wygląda podobnie:
- brak `itemExtent`, więc **wysokość wiersza zależy od długości tytułu**;
- tytuł **bez** `maxLines` i bez `ellipsis` (`favorite_songs_view.dart:67-70`), czyli zawija się do wielu linii;
- brak serca w wierszu (cała lista to ulubione);
- pierwszy element ma dodatkowe 24 px odstępu od góry (`favorite_songs_view.dart:32`);
- brak pola wyszukiwania i paska szybkiego przewijania.

Stany: pusty (obsłużony), z danymi (obsłużony), ładowanie i błąd — brak.

### 1.4 `MySongsView` — zakładka „Moje pieśni”
`lib/view/my_songs_view.dart`.

| Element | Miejsce |
|---|---|
| Komunikat pustej listy „Brak własnych pieśni” | `my_songs_view.dart:20-27` |
| Wiersz listy z ikoną `Icons.edit_note` w kółku | `my_songs_view.dart:48-105` |
| **Gest przesunięcia w lewo → usunięcie** (`Dismissible`, `endToStart`) | `my_songs_view.dart:33-47` |
| Czerwone tło pod gestem z ikoną kosza | `my_songs_view.dart:38-47` |
| Potwierdzenie usunięcia przed zniknięciem wiersza | `my_songs_view.dart:36` |
| Dotknięcie wiersza → `MySongDetailView` | `my_songs_view.dart:91-98` |

Stany: pusty (obsłużony), z danymi (obsłużony), ładowanie i błąd — brak. Tytuł: jedna linia z wielokropkiem,
wysokość stała `itemExtent: 70.0`.

### 1.5 `SongDetailView` — treść pieśni ze śpiewnika
`lib/view/song_detail_view.dart`. Wejście: dotknięcie wiersza na liście głównej lub w ulubionych.

| Element | Miejsce |
|---|---|
| Tytuł paska „`<numer>. <tytuł>`”, pogrubiony, 18 px, `titleSpacing: 0` | `song_detail_view.dart:39-46` |
| Przełącznik ulubionej (serce pełne/obrysowane) | `song_detail_view.dart:48-64` |
| Ikona `Icons.share`, która **kopiuje treść do schowka** i pokazuje `SnackBar` | `song_detail_view.dart:65-81` |
| Ikona `Icons.search` → dialog „Przejdź do pieśni” | `song_detail_view.dart:82-95` |
| **Gest przeciągnięcia w bok** → poprzednia/następna pieśń | `song_detail_view.dart:98-108` |
| Treść pieśni, rozmiar i interlinia z `FontSizeModel` | `song_detail_view.dart:109-126` |
| Blokada wygaszania ekranu przy wejściu i wyjściu | `song_detail_view.dart:23-33` |

Stany: tylko „z danymi”. Pieśń zawsze istnieje, bo przychodzi z listy. Brak stanu pustego, ładowania i błędu.
Długa treść: przewijana pionowo (`SingleChildScrollView`), bez skracania. Długi tytuł w pasku: domyślne
zachowanie `AppBar`, czyli jedna linia z wielokropkiem.

### 1.6 Dialog „Przejdź do pieśni”
`lib/view/song_detail_view.dart:131-228`. Otwierany ikoną lupy na ekranie szczegółów.

- pole numeryczne, autofokus, tylko cyfry, maksymalnie 4 znaki, bez białych znaków (`:183-187`);
- przyciski „Anuluj” (czerwony) i „Przejdź” (niebieski);
- po zatwierdzeniu dialog zamyka się **zanim** pojawi się ewentualny komunikat błędu (`:208-211`).

### 1.7 Dialog „Uwaga” (komunikat)
`lib/view/song_detail_view.dart:230-261`. Dwa komunikaty: numer spoza zakresu i brak pieśni o danym numerze.
Jeden przycisk „OK”.

### 1.8 `MySongDetailView` — podgląd własnej pieśni
`lib/view/my_song_detail_view.dart`.

| Element | Miejsce |
|---|---|
| Tytuł paska: sam tytuł pieśni, pogrubiony, 18 px | `my_song_detail_view.dart:82-88` |
| `Icons.share` → **systemowy arkusz udostępniania** (share_plus) | `my_song_detail_view.dart:34-44, 91` |
| `Icons.edit` → formularz edycji, po powrocie odświeżenie ekranu | `my_song_detail_view.dart:46-54, 93` |
| `Icons.delete` → potwierdzenie i powrót do listy | `my_song_detail_view.dart:56-63, 94` |
| Treść pieśni (identyczny kod jak w `SongDetailView`, z komentarzem `TODO: Unify`) | `my_song_detail_view.dart:97-115` |
| Blokada wygaszania ekranu | `my_song_detail_view.dart:22-32` |

Brak gestów przechodzenia między pieśniami. Stany: tylko „z danymi”.

### 1.9 `MySongFormView` — dodawanie i edycja własnej pieśni
`lib/view/my_song_form_view.dart`. Wejście: „+” na pasku (dodawanie) albo ikona ołówka w podglądzie (edycja).

| Element | Miejsce |
|---|---|
| Tytuł paska „Dodaj pieśń” albo „Edytuj pieśń” | `my_song_form_view.dart:108-112` |
| Przycisk zapisu `Icons.check`, tooltip „Zapisz” | `my_song_form_view.dart:113-119` |
| Pole „Tytuł”, wielka litera na początku zdania, przejście do następnego pola | `my_song_form_view.dart:127-133` |
| Pole „Treść”, wielolinijkowe, minimum 12 linii, rośnie bez ograniczenia | `my_song_form_view.dart:135-149` |
| **Dialog odrzucenia zmian** przy wyjściu, tylko gdy coś zmieniono | `my_song_form_view.dart:83-105` |

Stany:
- **puste pola** — walidacja dopiero po pierwszej próbie zapisu (`AutovalidateMode.disabled` → `onUserInteraction`, `:69`);
- **błąd walidacji** — komunikat pod polem;
- **ładowanie i błąd zapisu** — brak; zapis jest synchroniczny i nie może się nie udać z punktu widzenia widoku.

Długa treść: pole rośnie w dół, `ListView` przewija całość. Bardzo długi tytuł: jedna linia, przewijana poziomo w polu.

### 1.10 `SettingsView` — ustawienia
`lib/view/settings_view.dart`. Wejście: zębatka na pasku górnym.

| Element | Miejsce |
|---|---|
| Karta podglądu tekstu, **stała wysokość 180 px** | `settings_view.dart:24-42` |
| Suwak rozmiaru czcionki: 10–30, 10 podziałek, ikony `Icons.text_fields` 20 i 28 px | `settings_view.dart:46-65` |
| Suwak interlinii: 1,0–3,0, 10 podziałek, ikony `Icons.format_line_spacing` 20 i 28 px | `settings_view.dart:66-85` |
| Przycisk „Przywróć ustawienia domyślne” | `settings_view.dart:86-97` |
| Cztery pozycje z ikonami: Kontakt, O mnie, Wesprzyj, Zgłoś błąd, rozdzielone `Divider` w kolorze wiodącym | `settings_view.dart:101-159` |
| Komunikat o nieudanej migracji (zwykle niewidoczny) | `settings_view.dart:160` |

Stany: podgląd tekstu przy największej czcionce i największej interlinii **przycina tekst** (`overflow: TextOverflow.clip`
przy sztywnych 180 px, `:26, 39`). Odnośniki zewnętrzne przy niepowodzeniu nie pokazują niczego użytkownikowi
(`viewmodel/settings_viewmodel.dart:22-26`).

### 1.11 `DataMigrationNotice` — komunikat o nieudanej migracji
`lib/view/data_migration_notice.dart`. Widoczny tylko wtedy, gdy migracja z iOS zakończyła się błędem.
Stany: `FutureBuilder` — dopóki trwa odczyt, zwraca `SizedBox.shrink()`, czyli **nie ma stanu ładowania**;
brak błędu → nic nie widać.

### 1.12 Wspólny dialog potwierdzenia
`lib/view/confirmation_dialog.dart`. Używany przez usuwanie własnej pieśni (`delete_my_song_dialog.dart`)
i przez odrzucenie zmian w formularzu. Układ: tytuł wyśrodkowany, treść, dwa przyciski w rogach —
„Anuluj” niebieski po lewej, akcja niszcząca czerwona po prawej.

### 1.13 `SnackBar`
Jedyne użycie: potwierdzenie skopiowania treści do schowka (`song_detail_view.dart:70-72`).

---

## 2. Teksty interfejsu (kompletna lista)

### Paski i zakładki
| Tekst | Miejsce |
|---|---|
| `Śpiewnik` (tytuł paska) | `main.dart:172` |
| `Śpiewnik` (zakładka 1) | `main.dart:206` |
| `Ulubione` (zakładka 2) | `main.dart:207` |
| `Moje pieśni` (zakładka 3) | `main.dart:208` |
| `Dodaj pieśń` (tooltip przycisku „+”) | `main.dart:180` |
| `Dodaj pieśń` / `Edytuj pieśń` (tytuł formularza) | `my_song_form_view.dart:109` |
| `Zapisz` (tooltip przycisku zapisu) | `my_song_form_view.dart:116` |
| `Ustawienia` | `settings_view.dart:16` |
| `<numer>. <tytuł>` (tytuł ekranu pieśni) | `song_detail_view.dart:41` |
| `<tytuł>` (tytuł ekranu własnej pieśni) | `my_song_detail_view.dart:83` |

### Listy i puste stany
| Tekst | Miejsce |
|---|---|
| `Szukaj` (podpowiedź wyszukiwania) | `song_list_view.dart:55` |
| `Brak ulubionych pieśni` | `favorite_songs_view.dart:22` |
| `Brak własnych pieśni` | `my_songs_view.dart:23` |
| (brak tekstu dla pustego wyniku wyszukiwania) | — |

### Dialogi
| Tekst | Miejsce |
|---|---|
| `Przejdź do pieśni` | `song_detail_view.dart:147` |
| `Podaj numer pieśni, do której chcesz przejść.` | `song_detail_view.dart:158` |
| `Numer pieśni` (podpowiedź pola) | `song_detail_view.dart:171` |
| `Anuluj` | `song_detail_view.dart:205`, `confirmation_dialog.dart:44` |
| `Przejdź` | `song_detail_view.dart:216` |
| `Uwaga` (tytuł komunikatu) | `song_detail_view.dart:242` |
| `OK` | `song_detail_view.dart:255` |
| `Odrzucić zmiany?` | `my_song_form_view.dart:86` |
| `Wprowadzone zmiany nie zostaną zapisane.` | `my_song_form_view.dart:87` |
| `Odrzuć` | `my_song_form_view.dart:88` |
| `Usunąć pieśń?` | `delete_my_song_dialog.dart:9` |
| `Pieśń „<tytuł>” zostanie trwale usunięta.` | `delete_my_song_dialog.dart:10` |
| `Usuń` | `delete_my_song_dialog.dart:11` |

### Komunikaty
| Tekst | Miejsce |
|---|---|
| `Treść skopiowana do schowka` (SnackBar) | `song_detail_view.dart:71` |
| `Pieśń o podanym numerze nie została znaleziona` | `song_detail_view.dart:269` |
| `Podano niepoprawny numer. W śpiewniku znajduje się <N> pieśni.` | `song_detail_view.dart:273` |
| `Podaj tytuł pieśni` (walidacja) | `my_song_form_view.dart:132` |
| `Podaj treść pieśni` (walidacja) | `my_song_form_view.dart:148` |
| `Nie udało się przenieść ulubionych i własnych pieśni z poprzedniej wersji aplikacji.` | `data_migration_notice.dart:39` |
| `Wyślij szczegóły błędu` | `data_migration_notice.dart:45` |
| `Nie udało się przenieść danych z poprzedniej wersji aplikacji.\n\nSzczegóły błędu:\n<błąd>` (treść e-maila) | `data_migration_notice.dart:21` |
| `Brak szczegółów błędu.` | `viewmodel/settings_viewmodel.dart:18` |
| `Zgłoszenie błędu w aplikacji Śpiewnik (<wersja>)` (temat e-maila) | `viewmodel/settings_viewmodel.dart:32` |

### Ustawienia
| Tekst | Miejsce |
|---|---|
| Fragment pieśni „Alleluja, chwalcie Pana…” (podgląd, 4 linie tekstu) | `settings_view.dart:29-32` |
| `Przywróć ustawienia domyślne` | `settings_view.dart:94` |
| `Kontakt` | `settings_view.dart:112` |
| `O mnie` | `settings_view.dart:123` |
| `Wesprzyj` | `settings_view.dart:133` |
| `Zgłoś błąd` | `settings_view.dart:148` |

Adresy otwierane z ustawień: `https://spiewnik.odoo.com/contactus`, `https://spiewnik.odoo.com/about-us`,
`https://suppi.pl/spiewnik` (`settings_view.dart:114, 125, 135`), adres e-mail `n.marmucki@icloud.com`
(`viewmodel/settings_viewmodel.dart:35`).

---

## 3. Obecne wartości wizualne

### 3.1 Motyw (`lib/theme/theme.dart`)

| Wartość | Jasny | Ciemny |
|---|---|---|
| `colorScheme.primary` | `#9bd8ff` (`:9`) | `Colors.black` (`:37`) |
| `cardTheme.color` | `#f6fbff` (`:12`) | `#282828` (`:40`) |
| Wypełnienie pól tekstowych | `Colors.white` (`:16`) | `Colors.grey[900]` (`:44`) |
| Obramowanie pól | szare, 1,5 px, promień 30 (`:17-20`) | białe, 1,5 px, promień 30 (`:45-48`) |
| Ikona z przodu pola | szara (`:21`) | biała (`:49`) |
| `ElevatedButton` | biały tekst na `#9bd8ff` (`:24-27`) | biały tekst na `Colors.grey[800]` (`:52-55`) |
| Efekt dotknięcia | `splashColor` i `highlightColor` przezroczyste, `NoSplash.splashFactory` (`:5-7`, `:33-35`) | jw. |

Reszta kolorów pochodzi z domyślnych `ColorScheme.light` i `ColorScheme.dark`; nie są jawnie ustawione
`secondary`, `surface`, kolory tekstu ani typografia.

### 3.2 Kolory wpisane bezpośrednio w widokach

| Kolor | Gdzie | Po co |
|---|---|---|
| `Colors.white` | `song_list_view.dart:141`, `favorite_songs_view.dart:64`, `my_songs_view.dart:83, 46` | Tekst numeru i ikony w kółku, ikona kosza |
| `Colors.red` | `song_detail_view.dart:61`, `song_list_view.dart:154`, `my_songs_view.dart:43`, `confirmation_dialog.dart:49`, `song_detail_view.dart:202` | Serce ulubionej, tło gestu usuwania, akcja niszcząca, przycisk „Anuluj” w dialogu numeru |
| `Colors.blue` | `song_detail_view.dart:213, 255`, `confirmation_dialog.dart:41` | Przyciski potwierdzające w dialogach |
| `Colors.grey` | `favorite_songs_view.dart:23`, `my_songs_view.dart:24`, `data_migration_notice.dart:41` | Teksty pustych list i komunikat o migracji |
| `Colors.grey[900]` / `Colors.white` | `song_detail_view.dart:145, 240`, `confirmation_dialog.dart:22` | Tło dialogów, wybierane ręcznie po `Theme.of(context).brightness` |
| `Colors.white` / `Colors.black` | `song_detail_view.dart:149, 244, 248`, `confirmation_dialog.dart:26, 30` | Kolor tekstu w dialogach, również ręcznie po jasności |
| `Colors.white70` / `Colors.black54` | `song_detail_view.dart:160` | Opis w dialogu numeru |
| `Colors.white38` / `Colors.black38` | `song_detail_view.dart:172` | Podpowiedź w polu numeru |
| `Colors.black54` / `Colors.grey[200]` | `song_detail_view.dart:174` | Wypełnienie pola numeru |
| `Colors.white.withAlpha(153)` | `main.dart:211` | Kolor aktywnej zakładki dolnego paska |

Dialogi **nie korzystają z motywu**: samodzielnie sprawdzają `brightness` i dobierają kolory.

### 3.3 Typografia

| Miejsce | Ustawienie |
|---|---|
| Tytuł paska głównego | `FontWeight.bold`, rozmiar domyślny (`main.dart:173`) |
| Tytuł ekranu szczegółów | `FontWeight.bold`, **18 px** (`song_detail_view.dart:42-45`, `my_song_detail_view.dart:84-87`) |
| Tytuł formularza i ustawień | `FontWeight.bold`, rozmiar domyślny (`my_song_form_view.dart:110`, `settings_view.dart:16`) |
| Tytuł wiersza listy | `FontWeight.bold`, rozmiar domyślny (`song_list_view.dart:146`, `favorite_songs_view.dart:69`, `my_songs_view.dart:87`) |
| Numer w kółku | rozmiar domyślny, biały (`song_list_view.dart:140-141`) |
| Treść pieśni | rozmiar i interlinia z `FontSizeModel`: domyślnie **16 px** i **1,5** (`model/font_size_model.dart:8-9`) |
| Teksty pustych list | **18 px**, szary (`favorite_songs_view.dart:23`, `my_songs_view.dart:24`) |
| Tytuł dialogu | **20 px**, pogrubiony (`song_detail_view.dart:150-151, 244`, `confirmation_dialog.dart:26`) |
| Treść dialogu | **16 px** (`song_detail_view.dart:248`, `confirmation_dialog.dart:30`) |
| Opis w dialogu numeru | **14 px** (`song_detail_view.dart:161`) |
| Przyciski dialogów | **18 px** (`song_detail_view.dart:205, 216`, `confirmation_dialog.dart:44, 52`) |
| Komunikat o migracji | **13 px** (`data_migration_notice.dart:41`) |

Aplikacja **nie definiuje własnego kroju pisma**: `pubspec.yaml` nie ma sekcji `fonts`, a motyw nie ustawia
`textTheme` ani `fontFamily`. Wszystko idzie z domyślnej typografii Material dla danej platformy.

### 3.4 Odstępy, promienie, cienie

| Wartość | Gdzie |
|---|---|
| Margines wiersza listy: 4 px w pionie, 12 px w poziomie | `song_list_view.dart:102`, `my_songs_view.dart:39, 49` |
| Odstępy wiersza ulubionych: 12 px po bokach, 1 px na dole, 24 px nad pierwszym | `favorite_songs_view.dart:32` |
| Wewnętrzne odstępy `ListTile`: 2 px w pionie, 16 px w poziomie | `song_list_view.dart:133-134`, `favorite_songs_view.dart:57-58`, `my_songs_view.dart:80` |
| Odsunięcie treści wiersza od kolorowego paska: 8 px | `song_list_view.dart:127`, `favorite_songs_view.dart:55`, `my_songs_view.dart:74` |
| Promień wiersza listy i tła gestu: 15 px | `song_list_view.dart:105`, `favorite_songs_view.dart:35`, `my_songs_view.dart:44, 52` |
| Promień dialogów: 20 px | `song_detail_view.dart:143, 238`, `confirmation_dialog.dart:20` |
| Promień pola wyszukiwania: 30 px | `theme.dart:18, 46`, powtórzony w `song_list_view.dart:66` |
| Promień pola numeru w dialogu: 10 px | `song_detail_view.dart:176` |
| Promień pola treści w formularzu: 15 px (nadpisuje motywowe 30) | `my_song_form_view.dart:141` |
| Odstęp wokół pola wyszukiwania: 8 px | `song_list_view.dart:48` |
| Odstęp treści pieśni: 16 px | `song_detail_view.dart:111`, `my_song_detail_view.dart:100` |
| Odstępy w ustawieniach: 16 px listy i karty podglądu | `settings_view.dart:22, 27` |
| Odstęp między polami formularza: 16 px | `my_song_form_view.dart:134` |
| Odstępy przycisków dialogu: 16 px w obu osiach, `actionsPadding: EdgeInsets.zero` | `song_detail_view.dart:191-192, 203`, `confirmation_dialog.dart:32-33, 42` |
| Ikony akcji na pasku: `EdgeInsets.symmetric(horizontal: 4)` | `song_detail_view.dart:49, 66, 83`, `my_song_detail_view.dart:67` |

Cienie: nie są ustawiane nigdzie ręcznie. Jedyne cienie to domyślne `Card` w ulubionych i ustawieniach oraz
domyślna elewacja `AppBar`; wiersze list głównej i własnych pieśni używają `Container` z `BoxDecoration`, czyli
**bez cienia**.

### 3.5 Ikony

Wszystkie pochodzą z wbudowanego zestawu Material (`uses-material-design: true`, `pubspec.yaml:96`); brak
własnych plików ikon w interfejsie.

`Icons.add`, `Icons.settings`, `Icons.auto_stories`, `Icons.favorite`, `Icons.edit_note` (`main.dart`),
`Icons.search`, `Icons.cancel` (`song_list_view.dart`), `Icons.favorite`, `Icons.favorite_border`, `Icons.share`,
`Icons.search` (`song_detail_view.dart`), `Icons.share`, `Icons.edit`, `Icons.delete` (`my_song_detail_view.dart`),
`Icons.delete` (`my_songs_view.dart`), `Icons.check` (`my_song_form_view.dart`), `Icons.text_fields`,
`Icons.format_line_spacing`, `Icons.sms`, `Icons.person`, `Icons.favorite`, `Icons.error` (`settings_view.dart`).

### 3.6 Rozmiary elementów

| Element | Rozmiar | Gdzie |
|---|---|---|
| Wysokość wiersza listy głównej i własnych pieśni | **70 px** (`itemExtent`) | `song_list_view.dart:98`, `my_songs_view.dart:30` |
| Wysokość wiersza ulubionych | zmienna, zależna od treści | `favorite_songs_view.dart:27-88` |
| Szerokość kolorowego paska przy wierszu | **15 px** | `song_list_view.dart:114`, `favorite_songs_view.dart:44`, `my_songs_view.dart:61` |
| `CircleAvatar` | domyślny promień Material (40 px średnicy) | trzy listy |
| Ikony akcji na pasku | **24 px** | `song_detail_view.dart:60, 78, 92`, `my_song_detail_view.dart:72` |
| Ikony suwaków w ustawieniach | **20 px** i **28 px** | `settings_view.dart:49, 62, 69, 82` |
| Karta podglądu w ustawieniach | **dokładnie 180 px** wysokości | `settings_view.dart:26` |
| Dolny pasek | `curveSize: 80`, reszta z `ConvexAppBar` | `main.dart:212` |
| Minimalna liczba linii pola treści | 12 | `my_song_form_view.dart:146` |

Liczba **70** występuje w dwóch rolach: jako wysokość wiersza i jako dzielnik przy wyliczaniu numeru na etykiecie
paska przewijania (`song_list_view.dart:91`). Zmiana wysokości wiersza bez zmiany tego dzielnika rozjedzie etykietę.

---

## 4. Zachowania, które muszą przetrwać

1. **Przeciąganie między pieśniami** (`song_detail_view.dart:98-108`): `onPanUpdate` reaguje na **każde** zdarzenie
   z przesunięciem większym niż 10 px, a nie na koniec gestu. Przejście odbywa się przez `pushReplacement`, więc
   historia nawigacji nie rośnie, ale też nie da się cofnąć do poprzedniej pieśni przyciskiem wstecz.
2. **Blokada wygaszania ekranu z licznikiem** (`view/screen_wake_lock.dart`): `acquire` w `initState`, `release`
   w `dispose`, włączenie przy przejściu 0→1 i wyłączenie przy 1→0. Licznik istnieje dlatego, że `pushReplacement`
   tworzy nowy ekran przed zniszczeniem starego. Prosta para włącz/wyłącz gasiła ekran w trakcie czytania.
   Testy: `test/song_detail_view_wakelock_test.dart`.
3. **Debounce wyszukiwania 250 ms** (`song_list_view.dart:26-33`): każda zmiana tekstu resetuje odliczanie,
   filtr uruchamia się raz po przerwie w pisaniu.
4. **Przewinięcie na górę po wyczyszczeniu wyszukiwania** (`song_list_view.dart:35-41`): `jumpTo(0.0)` przed
   wyczyszczeniem filtra, z zabezpieczeniem `hasClients`.
5. **Etykieta paska szybkiego przewijania** (`song_list_view.dart:86-93`): numer wyliczany z pozycji przewijania
   (`offset ~/ 70 + 1`), pokazywany **tylko wtedy, gdy lista jest pełna**; przy aktywnym wyszukiwaniu etykieta jest pusta.
6. **Przesunięcie do usunięcia** (`my_songs_view.dart:33-37`): tylko w lewo, z potwierdzeniem przed zniknięciem
   wiersza (`confirmDismiss`), usunięcie z bazy dopiero w `onDismissed`. Anulowanie przywraca wiersz.
7. **Dialog odrzucenia zmian** (`my_song_form_view.dart:99-105`): `PopScope` blokuje wyjście, gdy pola się zmieniły,
   i obsługuje też systemowy gest cofania. Po zablokowaniu pola są sprawdzane **ponownie** (`:53-61`), bo `canPop`
   aktualizuje się dopiero w następnej klatce.
8. **Walidacja odłożona do pierwszego zapisu** (`my_song_form_view.dart:23, 69`): komunikaty pod polami pojawiają się
   dopiero po nieudanej próbie zapisu, potem na bieżąco.
9. **Stan zakładek przeżywa przełączanie** (`main.dart:199-202`): `IndexedStack` trzyma wszystkie trzy zakładki żywe,
   więc pozycja przewijania i wpisany tekst wyszukiwania nie znikają.
10. **Autofokus w dialogu numeru** (`song_detail_view.dart:225-227`): fokus ustawiany po pierwszej klatce, żeby
    klawiatura numeryczna pojawiła się od razu.
11. **Zamknięcie dialogu przed komunikatem błędu** (`song_detail_view.dart:208-211`): po „Przejdź” dialog znika,
    a dopiero potem pojawia się „Uwaga”. Po zamknięciu komunikatu dialog **nie** otwiera się ponownie.
12. **Odświeżenie podglądu po edycji** (`my_song_detail_view.dart:46-54`): `setState` po powrocie z formularza.
13. **Kotwica arkusza udostępniania na iPadzie** (`my_song_detail_view.dart:34-44`): `sharePositionOrigin` z pozycji
    przycisku; bez tego arkusz na iPadzie nie ma się do czego przypiąć.
14. **Natychmiastowa reakcja na zmianę ustawień tekstu**: ekrany treści i podgląd w ustawieniach słuchają
    `FontSizeModel` przez `Consumer`, więc suwak zmienia tekst na żywo (`song_detail_view.dart:112`,
    `my_song_detail_view.dart:101`, `settings_view.dart:19`).
15. **Przycisk „+” tylko na zakładce własnych pieśni** (`main.dart:177`).
16. **Brak efektu dotknięcia** w całej aplikacji: motyw wyłącza `splash` i `highlight`, a `InkWell` na pasku
    dodatkowo ustawia je na przezroczyste (`theme.dart:5-7`, `song_detail_view.dart:56-57`).
17. **Zachowanie serca na ekranie pieśni**: `setState` wokół `toggleFavoriteStatus` (`song_detail_view.dart:51-55`),
    dzięki czemu ikona zmienia się natychmiast, a listy odświeżają się przez notyfikatory.

---

## 5. Zależności warstwy widoków

### 5.1 Paczki używane wyłącznie w widokach

| Paczka | Jedyne miejsce użycia |
|---|---|
| `convex_bottom_bar` | `lib/main.dart` |
| `draggable_scrollbar` | `lib/view/song_list_view.dart` |
| `share_plus` | `lib/view/my_song_detail_view.dart` |
| `wakelock_plus` | `lib/view/screen_wake_lock.dart` |
| `provider` | `lib/main.dart` + trzy widoki (`song_detail_view`, `my_song_detail_view`, `settings_view`) |

Poza widokami: `url_launcher` i `package_info_plus` (w `settings_viewmodel`), `in_app_review` (`model/review_model.dart`),
`shared_preferences`, `objectbox`, `path`, `sqflite`, `path_provider`, `logger` (warstwa danych i start).

### 5.2 `convex_bottom_bar` (issue #17)

Jedno użycie: `main.dart:203-219`. Realnie używane możliwości:
- `style: TabStyle.reactCircle` — wyróżnione kółko pod aktywną zakładką;
- `items` z ikoną i tytułem (3 pozycje);
- `backgroundColor` z koloru wiodącego motywu;
- `activeColor: Colors.white.withAlpha(153)`;
- `curveSize: 80`;
- `initialActiveIndex` i `onTap` (zmiana `_selectedIndex` przez `setState`).

Nieużywane: warianty stylów, znaczniki, animacje własne, `controller`.

### 5.3 `draggable_scrollbar` (issue #17)

Jedno użycie: `song_list_view.dart:83-93`, konstruktor `DraggableScrollbar.semicircle`. Realnie używane możliwości:
- `controller` wspólny z `ListView`;
- `backgroundColor` z koloru wiodącego;
- `labelTextBuilder` — etykieta z numerem liczona z pozycji przewijania;
- kształt „semicircle” uchwytu.

Nieużywane: pozostałe kształty (`rrect`, `arrows`), własny `labelConstraints`, `heightScrollThumb`, `padding`.

### 5.4 Co widoki dostają z view modeli, a co skądinąd

**Z view modeli przez konstruktor:**
- `SongViewModel`: `filteredSongsNotifier`, `favoriteSongsNotifier`, `songCount`, `goToNumber`, `findNextSong`,
  `findPreviousSong`, `findSongByNumber`, `toggleFavoriteStatus`, `searchText` (setter);
- `MySongViewModel`: `mySongsNotifier`, `addSong`, `updateSong`, `deleteSong`.

**Z `Provider`:**
- `FontSizeModel` (rozmiar i interlinia) — `song_detail_view`, `my_song_detail_view`, `settings_view`;
- `SettingsViewModel` — `settings_view` i `data_migration_notice`;
- `Provider<Store>` jest zarejestrowany (`main.dart:94`), ale **żaden widok go nie czyta**.

**Z innych źródeł, z pominięciem view modeli:**
- `ScreenWakeLock` — statyczny licznik wołany wprost z dwóch ekranów;
- `Clipboard` i `ScaffoldMessenger` — bezpośrednio w `song_detail_view.dart:69-72`;
- `SharePlus` — bezpośrednio w `my_song_detail_view.dart:36`;
- `Navigator` — każdy widok sam decyduje o `push` i `pushReplacement`;
- `Theme.of(context)` — kolory i obramowania, w tym ręczne rozróżnianie jasnego i ciemnego motywu w dialogach;
- `HomeScreen` tworzy oba view modele w `initState` (`main.dart:152-157`), więc żyją tak długo jak ekran.

---

## 6. Zastane problemy

### 6.1 Uwagi `flutter analyze` (11)

| Uwaga | Miejsce | Czy zniknie przy redesignie |
|---|---|---|
| `avoid_print` ×2 | `song_detail_view.dart:102, 105` (logi gestu przeciągnięcia) | **tak**, kod gestu będzie pisany od nowa |
| `library_private_types_in_public_api` | `main.dart:144` (`_HomeScreenState` w publicznym API) | **tak**, przy przenoszeniu `HomeScreen` z `main.dart` |
| `deprecated_member_use` ×4 (`canLaunch`, `launch`) | `viewmodel/settings_viewmodel.dart:22, 23, 39, 40` | **nie**, to warstwa view modelu; czeka na punkt B3 z PARITY |
| `avoid_print` ×4 | `viewmodel/settings_viewmodel.dart:25, 42, 45` | **nie**, jw. |

Czyli 3 z 11 dotyczą widoków.

### 6.2 Kod powielony między ekranami

| Co | Gdzie | Uwagi |
|---|---|---|
| Wyświetlanie treści pieśni (`SizedBox.expand` + `Padding 16` + `Consumer<FontSizeModel>` + `SingleChildScrollView` + `Text`) | `song_detail_view.dart:109-126`, `my_song_detail_view.dart:98-115` | W drugim pliku jest komentarz `TODO: Unify` (`:97`) |
| Wiersz listy (kontener z promieniem 15, kolorowy pasek 15 px, `CircleAvatar`, pogrubiony tytuł) | `song_list_view.dart:101-167`, `favorite_songs_view.dart:31-86`, `my_songs_view.dart:48-105` | Trzy warianty: `Container` vs `Card`, z `itemExtent` i bez, z `maxLines` i bez |
| Przycisk akcji na pasku (`Padding 4` + `InkWell` bez efektu + `Icon 24`) | `my_song_detail_view.dart:65-75` (metoda) i trzy razy wprost w `song_detail_view.dart:48-95` | |
| Styl dialogu (promień 20, tło i kolory tekstu po `brightness`, przyciski w rogach) | `song_detail_view.dart:141-221`, `song_detail_view.dart:236-258`, `confirmation_dialog.dart:18-57` | |
| Para `ScreenWakeLock.acquire/release` w `initState`/`dispose` | `song_detail_view.dart:23-33`, `my_song_detail_view.dart:22-32` | |
| Tekst pustej listy (18 px, szary, wyśrodkowany) | `favorite_songs_view.dart:20-25`, `my_songs_view.dart:21-26` | |

### 6.3 `test/song_list_row_parity_test.dart`

Jeden test: „user song rows have the same size and spacing as song list rows”. Buduje kolejno `SongListView`
(z jedną pieśnią) i `MySongsView` (z jedną własną pieśnią), dla pierwszego wiersza mierzy i porównuje trzy rzeczy
(`:26-48`):

1. prostokąt `ListTile` sprowadzony do `left`, `width` i `height` — czyli lewa krawędź i wymiary kafelka;
2. prostokąt `CircleAvatar` przesunięty względem lewego górnego rogu kafelka — czyli położenie i rozmiar kółka;
3. lewą krawędź tytułu względem kafelka.

Nie porównuje kolorów, ikony w kółku, czcionki ani prawej strony wiersza (serce). Plik zawiera komentarz, że test
istnieje do czasu, aż redesign zastąpi oba wiersze jednym wspólnym widgetem.

### 6.4 Punkty z `docs/PARITY.md` dotyczące wyglądu, jeszcze niezrobione

| Wiersz w PARITY | Rzecz |
|---|---|
| „Układ na tablet” | iOS ma dwukolumnowy `NavigationSplitView` dla iPada, Flutter ma jeden układ |
| „Wejście do ustawień” | iOS: zębatka tylko na liście głównej, ustawienia jako arkusz; tutaj: zębatka wszędzie, pełny ekran |
| „Lista pieśni: wygląd wiersza” | iOS: `"<numer>. "` + tytuł; tutaj: numer w kółku |
| „Fallback pustego tytułu” | iOS pokazuje „Brak tytułu”; tutaj `title` jest zawsze tekstem, brak zastępnika |
| „Wyszukiwanie: przycisk «Anuluj»” | iOS ma przycisk anulowania chowający klawiaturę; tutaj ikona `Icons.cancel` |
| „Ulubione: komunikat pustej listy” | inne brzmienie tekstu niż w iOS |
| „Udostępnianie” (A1) | ikona share na ekranie pieśni kopiuje do schowka zamiast otwierać arkusz |
| „Rozmiar czcionki” / „Interlinia” | iPad w iOS miał inne zakresy i domyślne; interlinia w iOS to punkty, tutaj mnożnik |
| „Changelog po aktualizacji” | iOS pokazywał alert z opisem nowości, tutaj nie ma |
| „Zgłoś błąd: obsługa błędu” (B3) | iOS pokazywał alert, tutaj niepowodzenie jest tylko w logu |
| „Orientacja” i „Pasek statusu” | iOS blokował orientacje i chował pasek statusu; obecny układ tego nie robi w kodzie Fluttera |
| „Wyszukiwanie: tytuł” i „białe znaki” | dwa wspólne zachowania wyszukiwania oznaczone jako do decyzji i do naprawy przy grupie A |
| Blokada wygaszania ekranu | działa zawsze, przełącznik w ustawieniach zaplanowany jako A3 |

---

## 7. Ograniczenia

### 7.1 Rozmiar ekranu

- W kodzie **nie ma żadnego punktu granicznego**: ani `MediaQuery`, ani `LayoutBuilder`, ani `OrientationBuilder`
  (sprawdzone w całym `lib/`). Układ jest jednokolumnowy i rozciąga się na dowolną szerokość.
- Najmniejszy sensowny rozmiar wyznaczają sztywne wartości: wiersz 70 px wysokości z kółkiem 40 px i marginesami
  4 px, karta podglądu w ustawieniach 180 px, pole treści w formularzu minimum 12 linii. Przy bardzo niskim ekranie
  (np. telefon w poziomie z otwartą klawiaturą) formularz i ustawienia przewijają się, więc nie przycinają treści,
  ale karta podglądu przytnie sam tekst.
- Na dużym ekranie wszystko rozciąga się na pełną szerokość: wiersze listy stają się bardzo szerokie, tytuł zostaje
  po lewej, treść pieśni ciągnie się na całą szerokość bez ograniczenia długości linii.

### 7.2 Tablet

- Brak układu dwukolumnowego. Ten sam kod i te same wymiary co na telefonie (patrz PARITY, „Układ na tablet”).
- `ios/Runner/Info.plist` ma `UIRequiresFullScreen = true`, więc na iPadzie nie ma pracy w podzielonym ekranie.
- Jedyne miejsce, które w ogóle uwzględnia tablet, to kotwica arkusza udostępniania własnej pieśni
  (`my_song_detail_view.dart:34-44`).

### 7.3 Orientacja pozioma

- iOS dopuszcza portret oraz obie orientacje poziome (`UISupportedInterfaceOrientations` w `Info.plist`).
- Android nie blokuje orientacji: manifest ma tylko `configChanges` (`android/app/src/main/AndroidManifest.xml:13`),
  bez `screenOrientation`.
- W kodzie Fluttera **nie ma** `SystemChrome.setPreferredOrientations`, więc aplikacja obraca się razem z urządzeniem.
- Układ nie jest dostosowany do poziomu: te same jednokolumnowe listy, ta sama wysokość wiersza, a treść pieśni
  zajmuje pełną szerokość ekranu.

### 7.4 Dostępność

- **Skalowanie czcionki systemowej**: nigdzie nie ma `textScaler`, `textScaleFactor` ani `MediaQuery` z tym związanego,
  więc obowiązuje domyślne zachowanie Fluttera, czyli teksty skalują się razem z ustawieniem systemowym. Zderza się
  to ze sztywnymi wymiarami: wiersz listy 70 px (tytuł jednolinijkowy z wielokropkiem), karta podglądu 180 px
  (`overflow: TextOverflow.clip`) i kółko z numerem o stałym rozmiarze.
- **Etykiety dla czytnika ekranu**: w `lib/` nie ma ani jednego `Semantics` czy `semanticLabel`. Ikony akcji na paskach
  (serce, udostępnianie, lupa, edycja, kosz) są zwykłymi `Icon` w `InkWell`, więc czytnik ekranu nie ma czego przeczytać.
  Tooltipy są tylko dwa: „Dodaj pieśń” (`main.dart:180`) i „Zapisz” (`my_song_form_view.dart:116`).
- **Obszar dotyku**: ikony akcji mają 24 px i 4 px odstępu po bokach, czyli poniżej zalecanych 48 px, bo `InkWell`
  otacza samą ikonę (`song_detail_view.dart:48-95`, `my_song_detail_view.dart:65-75`).
- **Kontrast** (wartości policzone dla obecnych kolorów):
  - biały tekst numeru na kółku `#9bd8ff`: około **1,5:1**; to główny element listy;
  - szary tekst pustej listy `Colors.grey` (`#9E9E9E`) na tle jasnego motywu: około **2,8:1**;
  - komunikat o migracji, 13 px, ten sam szary: jw.;
  - `ElevatedButton` w jasnym motywie: biały tekst na `#9bd8ff`, około **1,5:1**.

  Progi WCAG AA to 4,5:1 dla zwykłego tekstu i 3:1 dla dużego. Powyższe wartości są podane jako stan faktyczny.
- **Brak informacji zwrotnej przy dotknięciu**: motyw wyłącza `splash` i `highlight` w całej aplikacji
  (`theme.dart:5-7, 33-35`), więc dotknięcie wiersza czy ikony nie daje wizualnego potwierdzenia poza przejściem ekranu.
