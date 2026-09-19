# Fixtures: baza Core Data starej aplikacji iOS

Schemat: `docs/SCHEMA-ZMYSONG.md`.

| Plik | Pochodzenie | Zawartość |
|---|---|---|
| `ios_with_data.sqlite` (+ `-wal`, `-shm`) | baza z symulatora, **ręcznie zmieniony jeden wiersz** (niżej) | 2000 pieśni, ulubione 5 i 12, jedna własna pieśń |
| `ios_fresh.sqlite` (+ `-wal`, `-shm`) | baza z symulatora zaraz po instalacji | 2000 pieśni, brak ulubionych i własnych pieśni |
| `ios_no_mysong.sqlite` | plik szablonowy z repozytorium iOS | 2000 pieśni, brak tabeli `ZMYSONG` |

Bazy z symulatora są w trybie WAL. Puste pliki `-wal` i przygotowane `-shm` są celowo w repozytorium,
żeby testy działały na takim samym zestawie plików jak na urządzeniu.

## Ręczna zmiana w `ios_with_data.sqlite`

Oryginalny wiersz z symulatora miał testowe teksty. Zamieniono je, pozostałe dane są bez zmian
(pełny zrzut bazy przed zmianą i po niej różni się tylko tym wierszem):

```sql
-- przed: INSERT INTO ZMYSONG VALUES(1,1,1,'Sdfdsfdsfdsfsdfds','Dsfdsfds');
UPDATE ZMYSONG SET ZTITLE = 'Pieśń poranna', ZCONTENT = '1. Dziękuję Ci, Panie, za nowy dzień.' WHERE Z_PK = 1;
```

Zmianę wykonano w `sqlite3` z `.filectrl persist_wal 1`, żeby zamknięcie połączenia nie usunęło plików
`-wal` i `-shm`. Po zmianie: `PRAGMA journal_mode` = `wal`, `PRAGMA integrity_check` = `ok`.

Testy nie modyfikują tych plików; przypadki syntetyczne powstają na kopiach (`test/core_data_reader_test.dart`).
