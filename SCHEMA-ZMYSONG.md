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

Bazy z urządzenia (ios_fresh, ios_with_data):
- Z_PRIMARYKEY: MySong = 1, Song = 2
- ZSONG: Z_ENT = NULL we wszystkich wierszach (zasiew z bundla),
  mimo przypisania Song = 2
- ZMYSONG: Z_ENT = 1, zgodnie z Z_PRIMARYKEY

Szablon z repo iOS (ios_no_mysong):
- Z_PRIMARYKEY: Song = 1, encji MySong brak
- numeracja encji różni się od baz z urządzenia

Wniosek: NIE filtrować po Z_ENT w żadnej tabeli. Numeracja encji nie jest
stabilna między szablonem a bazą utworzoną na urządzeniu.
