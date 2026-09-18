# Zrzuty golden — wygląd ekranów w obu motywach

`screens_golden_test.dart` renderuje każdy ekran offscreen, w motywie jasnym i ciemnym, i porównuje
z obrazem w `goldens/`. Testy chodzą w zwykłym `flutter test`, bez urządzenia i bez emulatora, więc
działają też na CI.

```sh
flutter test test/golden                    # sprawdza, czy wygląd się nie zmienił
flutter test --update-goldens test/golden   # zapisuje nowe obrazy po zamierzonej zmianie
```

Po zmianie wyglądu **obejrzyj różnice**, zanim zaktualizujesz obrazy: nieudana asercja zapisuje
pliki `*_testImage.png`, `*_masterImage.png` i `*_isolatedDiff.png` w `test/golden/failures/`.

## Co jest w zestawie

Numeracja odpowiada dawnym zrzutom z emulatora opisanym w `REDESIGN-CONTEXT.md`.

| Nazwa | Ekran |
|---|---|
| `01-lista-piesni` | Lista pieśni z polem wyszukiwania |
| `02-wyszukiwanie-wyniki` | Wyniki wyszukiwania |
| `03-wyszukiwanie-brak-wynikow` | Brak trafień (ekran bez komunikatu) |
| `04-ulubione`, `04b-ulubione-puste` | Ulubione z danymi i pusta lista |
| `05-moje-piesni`, `05b-moje-piesni-puste` | Własne pieśni z danymi i pusta lista |
| `06-usuwanie-dialog` | Gest usuwania i dialog potwierdzenia |
| `07-formularz-pusty`, `08-formularz-walidacja` | Formularz własnej pieśni |
| `09-formularz-odrzuc-zmiany` | Dialog „Odrzucić zmiany?” |
| `10-podglad-mojej-piesni` | Podgląd własnej pieśni |
| `12-szczegoly-piesni` | Treść pieśni |
| `13-dialog-przejdz-do-piesni`, `14-dialog-uwaga` | Dialogi na ekranie pieśni |
| `16-ustawienia`, `16b-ustawienia-max` | Ustawienia przy domyślnym i największym tekście |

## Dlaczego tak, a nie zrzuty z emulatora

Sterowanie emulatorem przez `adb` okazało się zawodne: kliknięcia trafiały w inne aplikacje, ekran
gasł w trakcie, a przeciążony emulator pokazywał ANR-y. Testy golden są powtarzalne, pokazują też
stany trudne do wyklikania (pusta lista ulubionych, największy rozmiar tekstu) i pilnują wyglądu
przy każdej zmianie kodu.

Ograniczenia: to render Fluttera bez warstwy systemowej, więc nie widać paska stanu, klawiatury,
systemowego arkusza udostępniania ani SnackBara pokazywanego przez system.

## Kroje pisma w testach

`loadAppFonts` w `test/support/golden_harness.dart` ładuje Newsreader i Schibsted Grotesk z `assets/fonts`
oraz czcionkę ikon Material z katalogu Fluttera. Bez tego test rysuje prostokąty zamiast liter i ikon.
