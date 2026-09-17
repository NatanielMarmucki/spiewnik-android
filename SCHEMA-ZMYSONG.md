# Schemat starej bazy Core Data (iOS)

Spisany z bazy wygenerowanej przez aplikację Swift w symulatorze.
Plik na urządzeniu: Documents/Model.sqlite

## ZSONG

CREATE TABLE ZSONG (
  Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
  ZFAVORITE INTEGER, ZNUMBER INTEGER, ZCONTENT VARCHAR, ZTITLE VARCHAR
)

- ZFAVORITE: 0 lub 1
- ZNUMBER: numer pieśni, 1-2000
- ZTITLE i ZCONTENT są opcjonalne w modelu Core Data, mogą być NULL

## ZMYSONG

CREATE TABLE ZMYSONG (
  Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
  ZCONTENT VARCHAR, ZTITLE VARCHAR
)

- Brak jakichkolwiek kolumn z datami. createdAt i updatedAt przy migracji
  ustawiamy na czas migracji.
- ZTITLE i ZCONTENT opcjonalne, mogą być NULL.
- Tabela istnieje nawet w czystej bazie — Core Data tworzy ją przy pierwszym
  uruchomieniu aplikacji. Nie istnieje wyłącznie w pliku szablonowym
  z repo iOS (test/fixtures/ios_no_mysong.sqlite).

## Z_ENT — potwierdzone wartości

- ZSONG: Z_ENT = NULL we wszystkich wierszach (zasiew z bundla), mimo że
  Z_PRIMARYKEY przypisuje encji Song
