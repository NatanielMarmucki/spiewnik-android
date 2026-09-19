# Golden screenshots: every screen in both themes

`screens_golden_test.dart` renders every screen offscreen, in the light and the dark theme, and compares it with
the image in `goldens/`. No device or emulator is involved, so the images are reproducible and the tests run on CI.

Font rasterization differs between systems, so the images are generated and checked **only on Linux**: in a
container locally, directly on CI. On macOS a plain `flutter test` skips these tests.

```sh
tools/golden.sh            # checks that the UI has not changed
tools/golden.sh --update   # writes new images after an intended change
```

After a UI change **look at the differences** before updating the images: a failed comparison writes
`*_testImage.png`, `*_masterImage.png` and `*_isolatedDiff.png` to `test/golden/failures/` (on CI they are in the
`golden-failures` artifact). More in `docs/DEVELOPMENT.md`.

## What is in the set

The file names are in Polish and the numbering comes from old emulator screenshots taken before the redesign,
so there are gaps. Each name has a `-light.png` and a `-dark.png` file.

| Name | Screen |
|---|---|
| `01-lista-piesni` | Song list with the search field |
| `02-wyszukiwanie-wyniki` | Search results |
| `03-wyszukiwanie-brak-wynikow` | No search results |
| `04-ulubione`, `04b-ulubione-puste` | Favorites with data and the empty list |
| `05-moje-piesni`, `05b-moje-piesni-puste` | User songs with data and the empty list |
| `06-usuwanie-dialog` | Delete confirmation dialog for a user song |
| `07-formularz-pusty`, `08-formularz-walidacja` | User song form: empty, and with validation errors |
| `09-formularz-odrzuc-zmiany` | "Odrzucić zmiany?" (discard changes) dialog |
| `10-podglad-mojej-piesni` | User song preview |
| `12-szczegoly-piesni` | Song text |
| `13-dialog-przejdz-do-piesni`, `13b-dialog-przejdz-wpisany-numer` | Go to number dialog: empty, and with a number entered |
| `14-arkusz-opcji` | Options sheet on the song screen |
| `16-ustawienia`, `16b-ustawienia-max` | Settings at the default and the largest text size |
| `17-lista-piesni-x2`, `18-szczegoly-piesni-x2`, `19-ustawienia-x2` | Song list, song text and settings at system text scale ×2 |
| `20-lista-szybkie-przewijanie` | Song list while fast scrolling |
| `21-powitanie`, `22-powitanie-x2`, `22b-powitanie-x2-przycisk` | Welcome screen after the migration from iOS, also at ×2 and scrolled to the button |

## Why goldens and not emulator screenshots

Driving the emulator through `adb` turned out to be unreliable: taps landed in other apps, the screen went dark
halfway through, and the overloaded emulator showed ANRs. Golden tests are reproducible, also show states that are
hard to click through (an empty favorites list, the largest text size), and guard the UI on every code change.

Limitations: this is Flutter's rendering without the system layer, so there is no status bar, keyboard, system share
sheet or system-shown SnackBar.

## Fonts in the tests

`loadAppFonts` in `test/support/golden_harness.dart` loads Newsreader and Schibsted Grotesk from `assets/fonts` and the
Material icons font from the Flutter directory. Without it the test draws boxes instead of letters and icons.
