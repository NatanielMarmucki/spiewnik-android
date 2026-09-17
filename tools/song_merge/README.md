# song_merge — scalanie tekstów pieśni z trzech źródeł

## Wejście

Katalog źródeł (`--src`) musi zawierać:

- `ios-device.sqlite` **razem z `ios-device.sqlite-wal` i `ios-device.sqlite-shm`, jeśli istnieją**,
- `ios-repo.sqlite`,
- `android.json`.

Bez `ios-device.sqlite` skrypty odmawiają działania. Źródła są tylko czytane: bazy SQLite są kopiowane do
katalogu tymczasowego i dopiero kopia jest otwierana, a sumy kontrolne oryginałów są sprawdzane przed
odczytem i po nim.

Baza z urządzenia zawiera dane użytkownika (ulubione). Katalog roboczy najlepiej trzymać poza repozytorium.

## Kroki

```sh
cd tools/song_merge

# 1–3: REPORT.md, diffs/NNNN.md, DECISIONS.md
python3 compare.py --src ~/song_merge_work

# decyzje wpisujesz w diffs/NNNN.md, potem kopiujesz je do kolumny w DECISIONS.md:
python3 build_songs.py --work ~/song_merge_work --sync-index

# 4: assets/songs_data_v2.json
python3 build_songs.py --work ~/song_merge_work --data-version 1
```

`compare.py` nie nadpisze istniejących `DECISIONS.md` ani `diffs/` bez `--force`.

## Decyzje

W każdym `diffs/NNNN.md`:

```
## DECYZJA
tytuł: ios-device | ios-repo | android | manual
treść: ios-device | ios-repo | android | manual
uwagi:

## MANUAL-TYTUŁ
(wypełnij tylko gdy tytuł: manual)

## MANUAL-TREŚĆ
(wypełnij tylko gdy treść: manual)
```

Tekst w `MANUAL-TREŚĆ` można objąć blokiem ` ``` `, wtedy jest brany dokładnie tak, jak jest zapisany.
Bez bloku usuwane są puste linie na początku i końcu oraz białe znaki na samym końcu tekstu.

Automatycznie wypełniane są tylko pieśni różniące się wyłącznie białymi znakami lub końcami linii
(`auto-whitespace`, decyzja `ios-device`). Wszystkie pozostałe decyzje są puste.

## Wynik

`assets/songs_data_v2.json`: `{"dataVersion": N, "songs": [{"number", "title", "content"}]}`.
Skrypt nigdy nie zapisuje do `songs_data.json`.

Każda zmiana tekstów w tym pliku wymaga podbicia `--data-version`, bo to ta liczba wyzwala nadpisanie
tekstów u użytkowników. Przy nadpisywaniu pliku z inną treścią i niepodbitą wersją skrypt wypisze
ostrzeżenie.
