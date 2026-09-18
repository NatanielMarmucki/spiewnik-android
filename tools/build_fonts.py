#!/usr/bin/env python3
"""Buduje kroje pisma dla aplikacji: statyczne odmiany z podzbiorem latin + latin-ext.

Źródło: zmienne pliki z repozytorium google/fonts (licencja OFL, kopie licencji leżą
w assets/fonts/). Pakiet google_fonts nie jest używany celowo: aplikacja działa offline,
więc kroje są w pakiecie zamiast pobierania w czasie działania.

Wymaga: pip3 install fonttools brotli
Użycie: python3 tools/build_fonts.py            # zapisuje do assets/fonts/
"""

import sys
import urllib.request
from pathlib import Path

from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

SOURCES = {
    "Newsreader.ttf": "https://raw.githubusercontent.com/google/fonts/main/ofl/newsreader/Newsreader%5Bopsz,wght%5D.ttf",
    "SchibstedGrotesk.ttf": "https://raw.githubusercontent.com/google/fonts/main/ofl/schibstedgrotesk/SchibstedGrotesk%5Bwght%5D.ttf",
}

# Zakresy podzbiorów latin i latin-ext z Google Fonts.
LATIN = (
    "U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,"
    "U+2000-206F,U+2074,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD"
)
LATIN_EXT = (
    "U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+0304,U+0308,U+0329,"
    "U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C0,U+2113,U+2C60-2C7F,U+A720-A7FF"
)

# opsz 18 to domyślny rozmiar optyczny Newsreadera; tekst pieśni ma 10-30 pt.
JOBS = [
    ("Newsreader.ttf", "Newsreader", {"wght": 200, "opsz": 18}, "ExtraLight"),
    ("Newsreader.ttf", "Newsreader", {"wght": 300, "opsz": 18}, "Light"),
    ("Newsreader.ttf", "Newsreader", {"wght": 400, "opsz": 18}, "Regular"),
    ("SchibstedGrotesk.ttf", "SchibstedGrotesk", {"wght": 400}, "Regular"),
    ("SchibstedGrotesk.ttf", "SchibstedGrotesk", {"wght": 500}, "Medium"),
    ("SchibstedGrotesk.ttf", "SchibstedGrotesk", {"wght": 600}, "SemiBold"),
]

# Znaki, bez których teksty pieśni i interfejsu wyglądałyby źle.
REQUIRED = "ąćęłńóśźżĄĆĘŁŃÓŚŹŻ„”—…0123456789[]:"


def unicodes(spec):
    codes = []
    for part in spec.split(","):
        part = part.strip().replace("U+", "")
        if "-" in part:
            start, end = part.split("-")
            codes.extend(range(int(start, 16), int(end, 16) + 1))
        else:
            codes.append(int(part, 16))
    return codes


def main():
    out_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/fonts")
    out_dir.mkdir(parents=True, exist_ok=True)
    work = Path("/tmp/spiewnik-fonts")
    work.mkdir(exist_ok=True)

    for name, url in SOURCES.items():
        target = work / name
        if not target.exists():
            print(f"pobieram {name}")
            urllib.request.urlretrieve(url, target)

    codes = set(unicodes(LATIN)) | set(unicodes(LATIN_EXT))

    for source, family, axes, style in JOBS:
        font = instancer.instantiateVariableFont(TTFont(work / source), axes, inplace=False, updateFontNames=False)
        options = Options()
        options.layout_features = ["*"]  # zachowuje m.in. tnum, czyli cyfry tabelaryczne
        options.name_IDs = ["*"]
        options.notdef_outline = True
        subsetter = Subsetter(options=options)
        subsetter.populate(unicodes=codes)
        subsetter.subset(font)

        cmap = font.getBestCmap()
        missing = [c for c in REQUIRED if ord(c) not in cmap]
        if missing:
            raise SystemExit(f"{family}-{style}: brak znaków {missing}")

        path = out_dir / f"{family}-{style}.ttf"
        font.save(path)
        print(f"{path} — {path.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()
