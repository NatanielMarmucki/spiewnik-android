# Psałterz — system wizualny

Referencja dla implementacji. Źródło: projekt w Claude Design („Psałterz — system wizualny
śpiewnika"). Ten plik jest jedynym źródłem prawdy dla kodu — projekt w Claude Design nie jest
czytelny dla agenta.

Zasada nadrzędna: **tekst pieśni jest interfejsem**, reszta aplikacji tylko do niego prowadzi.
Żadnych kart, kolorowych kółek ani cieni — hierarchię niosą krój, odstęp i jedna barwa akcentu.

---

## 1. Kolory

Kontrast policzony wobec tła, na którym element **rzeczywiście leży**, nie wobec czerni.

### Motyw ciemny (pierwszorzędny) — wobec tła `#191A1D`

| Rola | Hex | Kontrast | Zastosowanie |
|---|---|---|---|
| tło | `#191A1D` | — | ekrany, pasek górny, nawigacja |
| powierzchnia | `#212328` | — | pole szukania, wiersz wciśnięty |
| powierzchnia +2 | `#262930` | — | dialog, arkusz, snackbar |
| linia | `#2E3138` | — | hairline 1 dp |
| linia — kropki indeksu | `#45494F` | — | linia wiodąca w wierszu listy |
| tekst (ciepła biel) | `#F4EFE6` | 15,0:1 | treść pieśni, tytuły |
| tekst drugi | `#A8A29B` | 6,8:1 | numer pieśni, opisy |
| tekst trzeci | `#938F87` | 5,3:1 | nieaktywna zakładka |
| akcent — szafran | `#E2B872` | 9,3:1 | inicjał, wersaliki, znaki powtórzenia, aktywna zakładka |
| niszczący | `#F29186` | 7,5:1 | usuwanie |
| ulubiona | `#E39AAF` | 7,8:1 | serce |

### Motyw jasny (równorzędny) — wobec tła `#F7F4EE`

| Rola | Hex | Kontrast | Zastosowanie |
|---|---|---|---|
| tło — papier kostny | `#F7F4EE` | — | nie biel ekranowa |
| powierzchnia | `#FFFDF8` | — | pole szukania, dialog, arkusz |
| wciśnięta | `#EFEAE0` | — | reakcja na dotknięcie wiersza |
| linia | `#E2DCD1` | — | hairline 1 dp |
| linia — kropki indeksu | `#C9C2B5` | — | linia wiodąca |
| tekst | `#1B1A17` | 15,9:1 | atrament |
| tekst drugi | `#5C5852` | 6,4:1 | |
| tekst trzeci | `#6E6A62` | 4,9:1 | |
| akcent — szafran ciemny | `#7A5518` | 6,1:1 | |
| niszczący | `#A3231B` | 6,8:1 | |
| ulubiona | `#8C2F4F` | 7,3:1 | |

### Pozostałe

- Przyciemnienie pod dialogiem: ciemny `rgba(0,0,0,.60)`, jasny `rgba(27,26,23,.45)`
- Fokus: obwódka 2 dp w kolorze akcentu
- Akcent to **jedna barwa (szafran ≈ 40°) w dwóch tonach** — jeden ton nie utrzyma 4,5:1
  wobec obu teł naraz

### Co to naprawia

Obecna wersja ma białe cyfry na `#9bd8ff` = **1,5:1**. Numer traci tło i staje się tekstem
drugoplanowym na tle ekranu = **6,8:1**, cyframi tabelarycznymi.

---

## 2. Typografia

Dwa kroje z Google Fonts, oba z pełnym `latin-ext` (ą ć ę ł ń ó ś ź ż).

- **Newsreader** (200/300/400) — tekst pieśni, tytuły, numery. Szeryf z rozmiarem optycznym;
  przy 10–30 pt trzyma rytm i nie rozjeżdża się na diakrytykach.
- **Schibsted Grotesk** (400/500/600) — interfejs: wersaliki, etykiety, przyciski, nawigacja.
  Cyfry tabelaryczne.

Nie Inter i nie Roboto.

### Skala interfejsu (dp)

| Rola | Rozmiar / interlinia | Krój |
|---|---|---|
| tytuł ekranu | 20 / 1,05 | Newsreader |
| tytuł pieśni na liście | 17 / 1,2 | Newsreader |
| numer na liście (tabelarycznie) | 15 / 1 | Newsreader |
| tytuł dialogu | 19 / 1,3 | Grotesk 500 |
| treść dialogu, arkusz, stan pusty | 15 / 1,5 | Grotesk 400 |
| przycisk tekstowy | 15 / 1,2 | Grotesk 600 |
| etykieta zakładki | 10,5 / 1 | Grotesk 500 |
| wersalik sekcji („Refren") | 8,5 · letter-spacing +0.26em | Grotesk 500 |

### Skala pieśni — proporcje od S

`S` = rozmiar ustawiony suwakiem (10–30 pt, **domyślnie 19**). Wszystko inne liczone z S.

| Miara | Wzór | Przy S = 19 |
|---|---|---|
| interlinia | 1,62 × S | 30,8 |
| odstęp między blokami | 1,26 × S | 24 |
| wcięcie refrenu | 0,74 × S | 14 |
| inicjał pierwszej zwrotki | 2,16 × S | 41 |
| numer kolejnej zwrotki | 0,74 × S | 14 |
| margines boczny kolumny | 22 dp (stałe) | 22 |
| maks. szerokość kolumny | 34 × S | 646 |

Interlinia zostaje mnożnikiem, ale suwak dostaje zakres **1,4–1,8** zamiast 1,0–3,0
(domyślnie 1,62).

---

## 3. Renderer tekstu pieśni

Baza daje jeden ciąg znaków ze znacznikami. Renderer **zdejmuje znaczniki z toku tekstu**
i zamienia je na typografię — bez ikon i bez kolorowych plam.

| Wzorzec | Znaczenie | Renderowanie |
|---|---|---|
| `^\d+\.\s` | numer zwrotki | pierwsza: inicjał 2,16 × S; kolejne: cyfra 0,74 × S z linią |
| `^Refren:\s` | refren | wersalik „Refren" z linią + wcięcie 0,74 × S. **Bez kursywy** |
| `[: … :]` | powtórzenie | dwa znaki w kolorze akcentu, przyklejone do pierwszego i ostatniego słowa frazy — trzymają się jej także przy zawinięciu akapitu |
| `\n\n` | granica bloku | odstęp 1,26 × S, **nigdy puste wiersze** |

Podziału na wiersze w danych nie ma i nie da się go odtworzyć bezbłędnie (łamanie po
interpunkcji wywraca się na „Nućcie Jemu chwałę, / cześć!"). Zwrotka płynie jak akapit
i zawija się sama.

Renderer przyjmuje opcjonalne `\n` wewnątrz bloku — gdyby dane kiedyś odzyskały łamania,
ten sam ekran zacznie je pokazywać bez przeprojektowania.

### Wymiary dopowiedziane przy wdrożeniu

Dwie wartości, których projekt nie określał, a kod ich potrzebował:

| Miara | Wartość | Dlaczego tak |
|---|---|---|
| linia obok cyfry zwrotki i wersalika „REFREN” | `1,5 × S`, stała | Linia wiodąca przez całą szerokość znaczy co innego — w wierszu listy prowadzi wzrok do numeru pieśni. Powielanie jej w tekście pieśni myli, więc tutaj jest tylko krótka kreska przy etykiecie |
| odstęp między etykietą bloku a jego treścią | `1,26 × S ÷ 3`, czyli jedna trzecia odstępu międzyblokowego | Etykieta ma trzymać się swojej zwrotki; pełny odstęp blokowy odrywałby ją od tekstu |

**Niesparowane znaki powtórzenia.** W danych zdarzają się literówki w rodzaju `[Czym prędzej
pośpiesz Doń!:]`, gdzie otwarcie zgubiło dwukropek. Parser zostawia taki pojedynczy znak jako
zwykły tekst, zamiast udawać powtórzenie.

---

## 4. Odstępy i kształty

Baza 4 dp, sześć wartości:

| Wartość | Zastosowanie |
|---|---|
| 4 | ikona ↔ podpis zakładki |
| 8 | tytuł ↔ serce ulubionej |
| 12 | wnętrze pola, odstęp akcji |
| 16 | margines boczny listy i pasków |
| 24 | wnętrze dialogu, odstęp bloków pieśni |
| 32 | bloki ustawień, stan pusty |

Dwa promienie: **12 dp** (dialog, arkusz, blok) i **pastylka** (pole szukania, przycisk).
Wiersz listy nie ma promienia, bo nie ma tła — rozdziela go hairline.

Znikają: 1, 2, 10, 15 i 30 dp razem z kartami.

---

## 5. Komponenty

**Wiersz listy** — 48 dp, jeden wariant dla trzech list. Tytuł (Newsreader 17), linia wiodąca
z kropek, numer na prawej krawędzi (Newsreader 15, tabelarycznie). Serce ulubionej 11 dp
**przy tytule, nie na końcu wiersza** — nie ginie przy długim tytule. Własna pieśń: wersalik
`MOJA` zamiast numeru. Stany: spoczynek, wciśnięty (powierzchnia), wybrany (numer w akcencie).
Cały wiersz jest celem dotknięcia.

**Pole wyszukiwania** — 44 dp, pastylka, **widoczne zawsze**. Lupa 15 dp, podpowiedź
„Numer albo tytuł", przy treści krzyżyk czyszczenia (cel 48 dp). Fokus: obwódka 2 dp w akcencie.
Jedno pole obsługuje numer i tytuł, szukanie bez diakrytyków, trafienie podświetlone w tytule.

**Pasek górny** — 48 dp, hairline zamiast cienia. Na liście: tytuł ekranu (Newsreader 20) plus
dodawanie i ustawienia. W pieśni: powrót, numer w akcencie, tytuł z ellipsis, serce i trzy kropki
w celach 40 × 48 dp.

**Dolna nawigacja** — Material 3 `NavigationBar`, trzy zakładki, wysokość 48 dp: ikona kreskowa
17 dp i podpis w jednej linii. Aktywna: kreska 2 dp w akcencie, ikona w akcencie, podpis w kolorze
tekstu, waga 600. Nieaktywna: tekst trzeci.

**Dialog** — promień 12 dp, wnętrze 24 dp. Tytuł 19, treść 15, dwie akcje po prawej, akcja
niszcząca w kolorze niszczącym z tłem 12% — **nigdy jako wypełniony przycisk**. „Anuluj"
przestaje być niebieskie.

**Arkusz** — uchwyt 34 × 3 dp, pozycje 52 dp, sekcja niszcząca odcięta hairline'em.

**Stan pusty** — ikona kreskowa 26 dp w kolorze linii, nagłówek Newsreader 21, zdanie 14/1,55
mówiące co zrobić, opcjonalnie jedno wyjście jako przycisk-pastylka 48 dp. Trzy wystąpienia:
brak wyników, brak ulubionych, brak własnych pieśni. Nigdy duża ilustracja.

**Suwak** — tor 3 dp, uchwyt 20 dp w celu 48 dp, poświata 6 dp przy dotknięciu. Wartość zawsze
wypisana liczbą obok nazwy. Pod suwakiem rozmiaru tekstu stoi próbka pieśni zmieniająca się
na żywo.

---

## 6. Dostępność

- Obszary dotyku: ikona 16–17 dp w celu **min. 40 × 48 dp**
- Reakcja na dotknięcie: przyciemnienie tła wiersza na 80 ms i powrót (zamiast globalnie
  wyłączonego splash)
- Każda ikona-akcja ma `Semantics(label:)` **po polsku**
- Wszystko działa przy systemowym powiększeniu czcionki ×1,3 i ×2,0

---

## 7. Reguły, które muszą zostać w kodzie

1. Żadnej stałej wysokości na elemencie z tekstem — tylko `minHeight`.
2. Kontrast liczony wobec tła, na którym element leży, nie wobec czerni.
3. Każda ikona-akcja ma `Semantics(label:)` po polsku.
4. Kolory wyłącznie z `Theme.of(context)` — **zero literałów w widokach i zero sprawdzania
   jasności motywu**.
5. Tekst pieśni skalowany przez S z ustawień, mnożony dodatkowo przez systemowy `textScaler`,
   **nigdy zamiast niego**.
6. Lista 2000 pozycji zawsze przez `ListView.builder` z `itemExtent` **null** (wiersz rośnie
   z czcionką).

---

## 8. Ikony

Podglądy w Claude Design rysują kreski SVG — w Flutterze wchodzą odpowiedniki z Material Icons
w rozmiarze 24 dp: `menu_book`, `favorite`, `favorite_border`, `edit_note`, `search`, `share`,
`more_vert`, `settings`.

---

## 9. Kolejność wdrożenia

| Krok | Zakres |
|---|---|
| 1 | **Tokeny i motyw** — dwa `ColorScheme`, dwa kroje, skala odstępów, dwa promienie, usunięcie literałów kolorów z widoków. Sam ten krok kasuje błąd 1,5:1. |
| 2 | **Wiersz i listy** — jeden komponent wiersza 48 dp dla trzech list, stała wyszukiwarka, sortowanie po numerze, reakcja na dotknięcie, stany puste. |
| 3 | **Renderer pieśni** — parser znaczników, inicjał, wersalik refrenu, znaki powtórzenia, margines 22 dp i limit kolumny, skala od S. |
| 4 | **Nawigacja i okna** — pasek pieśń wstecz / numer / pieśń w przód, modal „Przejdź do pieśni" z klawiaturą systemową, arkusz opcji, dialogi z tokenów. |
| 5 | **Dostępność** — etykiety dla czytnika ekranu, audyt obszarów dotyku, test przy ×1,3 i ×2,0, kontrola kontrastu każdej pary w obu motywach. |

---

## 10. Decyzje do podjęcia przed wdrożeniem

Rzeczy, które system zmienia poza samym wyglądem — wymagają świadomej zgody:

1. **Migracja ustawień istniejących użytkowników.** Zakres interlinii zmienia się z 1,0–3,0
   na 1,4–1,8, domyślne z 16/1,5 na 19/1,62. Zapisane wartości spoza nowego zakresu trzeba
   **przyciąć, nie zresetować**; nowe domyślne obowiązują tylko przy pierwszej instalacji.
2. **Gest przeciągnięcia między pieśniami** — zostaje obok nowego dolnego paska ze strzałkami,
   czy znika?
3. **Pasek szybkiego przewijania z etykietą numeru** znika razem z `itemExtent`. To usuwa
   `draggable_scrollbar` z issue #17 przez wykreślenie funkcji, nie zamianę.
4. **Nowe funkcje w arkuszu opcji**: „Kopiuj tekst", „Nie gaś ekranu", **„Zgłoś błąd w tekście"**
   (nowa funkcja — wymaga decyzji o zakresie).
5. **Przełącznik motywu w ustawieniach** — dziś aplikacja idzie wyłącznie za systemem.
6. **Trzy kroje w pliku HTML, dwa w aplikacji.** IBM Plex Mono służy tylko dokumentacji.
   Newsreader i Schibsted Grotesk trzeba wciągnąć jako assety z podzbiorem latin + latin-ext,
   żeby nie rozdąć pakietu.
