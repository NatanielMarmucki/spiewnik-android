"""Wspólne wczytywanie i porównywanie źródeł danych pieśni.

Używane przez compare.py i build_songs.py, żeby obie strony liczyły
rozbieżności w identyczny sposób.

Pliki źródłowe są wyłącznie czytane. Bazy SQLite są kopiowane (razem z -wal
i -shm) do katalogu tymczasowego i dopiero kopia jest otwierana, bo otwarcie
oryginału mogłoby zmodyfikować pliki WAL, a otwarcie w trybie immutable
pominęłoby zmiany zapisane tylko w -wal.
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import sqlite3
import tempfile
import unicodedata
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Kolejność ma znaczenie: pierwszy obecny klucz jest bazą diffów.
ALL_SOURCE_SPECS = [
    ("ios-device", "ios-device.sqlite", "coredata"),
    ("ios-repo", "ios-repo.sqlite", "coredata"),
    ("android", "android.json", "json"),
]
ALL_PAIRS = [("ios-repo", "ios-device"), ("ios-device", "android"), ("ios-repo", "android")]

# Ustawiane przez configure(); domyślnie wszystkie trzy źródła.
SOURCE_SPECS = list(ALL_SOURCE_SPECS)
SOURCE_KEYS = [key for key, _, _ in SOURCE_SPECS]
BASE = SOURCE_KEYS[0]
PAIRS = list(ALL_PAIRS)
DECISION_VALUES = tuple(SOURCE_KEYS) + ("manual",)


def configure(with_device: bool = True) -> None:
    """Tryb bez ios-device: bazą i źródłem auto-whitespace jest ios-repo."""
    global SOURCE_SPECS, SOURCE_KEYS, BASE, PAIRS, DECISION_VALUES
    SOURCE_SPECS = [spec for spec in ALL_SOURCE_SPECS if with_device or spec[0] != "ios-device"]
    SOURCE_KEYS = [key for key, _, _ in SOURCE_SPECS]
    BASE = SOURCE_KEYS[0]
    PAIRS = [pair for pair in ALL_PAIRS if all(key in SOURCE_KEYS for key in pair)]
    DECISION_VALUES = tuple(SOURCE_KEYS) + ("manual",)


def mode_line() -> str:
    return f"Tryb porównania: {', '.join(SOURCE_KEYS)} (baza: {BASE})"

EXPECTED_COUNT = 2000
REQUIRED_COLUMNS = ("ZNUMBER", "ZTITLE", "ZCONTENT", "ZFAVORITE")


class SourceError(Exception):
    pass


@dataclass
class Entry:
    number: int
    title: Optional[str]
    content: Optional[str]
    favorite: object
    origin: str  # np. "Z_PK=17" albo "songs[16]"


@dataclass
class Source:
    key: str
    path: Path
    entries: List[Entry]
    anomalies: List[str] = field(default_factory=list)
    meta: Dict[str, object] = field(default_factory=dict)

    def by_number(self) -> Dict[int, List[Entry]]:
        result: Dict[int, List[Entry]] = {}
        for entry in self.entries:
            result.setdefault(entry.number, []).append(entry)
        return result


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _companions(path: Path) -> Dict[str, Path]:
    return {suffix: Path(str(path) + suffix) for suffix in ("", "-wal", "-shm")}


def _fingerprint(path: Path) -> Dict[str, Optional[str]]:
    return {
        suffix: (sha256(p) if p.exists() else None)
        for suffix, p in _companions(path).items()
    }


def load_coredata(key: str, path: Path) -> Source:
    before = _fingerprint(path)
    with open(path, "rb") as handle:
        header = handle.read(20)
    if not header.startswith(b"SQLite format 3\x00"):
        raise SourceError(f"{path}: to nie jest plik SQLite")
    # Bajty 18/19 nagłówka: 1 = rollback journal, 2 = WAL.
    wal_mode = len(header) >= 20 and header[18] == 2 and header[19] == 2

    meta: Dict[str, object] = {
        "sha256": before[""],
        "size": path.stat().st_size,
        "wal_file": before["-wal"] is not None,
        "shm_file": before["-shm"] is not None,
        "wal_mode_header": wal_mode,
    }
    anomalies: List[str] = []
    if wal_mode and not meta["wal_file"]:
        anomalies.append(
            "nagłówek wskazuje tryb WAL, a pliku -wal obok bazy nie ma; jeśli plik "
            "skopiowano bez -wal, zmiany sprzed checkpointu mogą być niewidoczne"
        )

    with tempfile.TemporaryDirectory(prefix="song_merge_") as tmp:
        copy = Path(tmp) / "db.sqlite"
        for suffix, source_path in _companions(path).items():
            if source_path.exists():
                shutil.copy2(source_path, Path(str(copy) + suffix))
        con = sqlite3.connect(str(copy))
        try:
            columns = [row[1] for row in con.execute("PRAGMA table_info(ZSONG)")]
            if not columns:
                raise SourceError(f"{path}: brak tabeli ZSONG")
            missing = [c for c in REQUIRED_COLUMNS if c not in columns]
            if missing:
                raise SourceError(f"{path}: w ZSONG brak kolumn {missing}")
            pk = "Z_PK" if "Z_PK" in columns else "rowid"
            rows = con.execute(
                f"SELECT {pk}, ZNUMBER, ZTITLE, ZCONTENT, ZFAVORITE FROM ZSONG ORDER BY {pk}"
            ).fetchall()
            meta["journal_mode"] = con.execute("PRAGMA journal_mode").fetchone()[0]
        finally:
            con.close()

    after = _fingerprint(path)
    if after != before:
        raise SourceError(f"{path}: plik źródłowy zmienił się podczas odczytu")

    entries: List[Entry] = []
    for pk_value, number, title, content, favorite in rows:
        origin = f"{pk}={pk_value}"
        if not isinstance(number, int) or isinstance(number, bool):
            anomalies.append(f"{origin}: ZNUMBER={number!r} nie jest liczbą całkowitą, pominięto")
            continue
        for name, value in (("ZTITLE", title), ("ZCONTENT", content)):
            if value is not None and not isinstance(value, str):
                anomalies.append(f"nr {number} ({origin}): {name} ma typ {type(value).__name__}")
        entries.append(Entry(number, title, content, favorite, origin))
    return Source(key, path, entries, anomalies, meta)


def load_json(key: str, path: Path) -> Source:
    raw = path.read_bytes()
    meta: Dict[str, object] = {"sha256": hashlib.sha256(raw).hexdigest(), "size": len(raw)}
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise SourceError(f"{path}: niepoprawny JSON ({exc})")
    if not isinstance(data, dict) or not isinstance(data.get("songs"), list):
        raise SourceError(f'{path}: oczekiwano obiektu z listą "songs"')
    meta["top_level_keys"] = sorted(data.keys())

    anomalies: List[str] = []
    entries: List[Entry] = []
    for index, item in enumerate(data["songs"]):
        origin = f"songs[{index}]"
        if not isinstance(item, dict):
            anomalies.append(f"{origin}: element nie jest obiektem, pominięto")
            continue
        number = item.get("number")
        if not isinstance(number, int) or isinstance(number, bool):
            anomalies.append(f"{origin}: number={number!r} nie jest liczbą całkowitą, pominięto")
            continue
        extra = sorted(set(item) - {"number", "title", "content", "favorite"})
        if extra:
            anomalies.append(f"nr {number} ({origin}): dodatkowe klucze {extra}")
        for name in ("title", "content"):
            if name not in item:
                anomalies.append(f"nr {number} ({origin}): brak klucza {name}")
            elif item[name] is not None and not isinstance(item[name], str):
                anomalies.append(f"nr {number} ({origin}): {name} ma typ {type(item[name]).__name__}")
        entries.append(
            Entry(number, item.get("title"), item.get("content"), item.get("favorite"), origin)
        )
    return Source(key, path, entries, anomalies, meta)


def load_sources(src_dir: Path) -> Dict[str, Source]:
    missing = [name for _, name, _ in SOURCE_SPECS if not (src_dir / name).is_file()]
    if missing:
        lines = [f"Brak plików źródłowych w {src_dir}: {', '.join(missing)}"]
        if "ios-device.sqlite" in missing:
            lines.append(
                "ios-device.sqlite jest wymagany (razem z -wal i -shm, jeśli istnieją). "
                "Żeby świadomie porównać bez niego, użyj --no-device."
            )
        raise SourceError("\n".join(lines))
    sources: Dict[str, Source] = {}
    for key, name, kind in SOURCE_SPECS:
        path = src_dir / name
        sources[key] = load_coredata(key, path) if kind == "coredata" else load_json(key, path)
    return sources


# --- Znaki niewidoczne -----------------------------------------------------

def is_invisible(ch: str) -> bool:
    """Separatory, spacje inne niż ASCII, znaki formatujące i sterujące.
    Nie obejmuje zwykłej spacji, \\n, \\t i \\r (te mają osobną obsługę)."""
    return ch not in " \n\t\r" and unicodedata.category(ch) in ("Zl", "Zp", "Zs", "Cf", "Cc")


def char_label(ch: str) -> str:
    return f"U+{ord(ch):04X} {unicodedata.name(ch, '?')}"


def invisible_counts(text: Optional[str]) -> Counter:
    return Counter(ch for ch in (text or "") if is_invisible(ch))


def strip_invisible(text: str) -> str:
    return "".join(ch for ch in text if not is_invisible(ch))


# --- Białe znaki -----------------------------------------------------------

_TRAILING_BLANKS = re.compile(r"[ \t]+(?=\n)|[ \t]+\Z")


def _eol(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n")


def ws_norm_content(text: Optional[str]) -> Optional[str]:
    """Usuwa tylko: różnice \\r\\n/\\r vs \\n, spacje i tabulatory na końcach linii,
    końcowe znaki nowej linii na końcu tekstu. Nic więcej."""
    if text is None:
        return None
    return _TRAILING_BLANKS.sub("", _eol(text)).rstrip("\n")


def ws_norm_title(text: Optional[str]) -> Optional[str]:
    """Tytuł jest jedną linią: usuwa spacje, tabulatory i znaki końca linii z brzegów."""
    if text is None:
        return None
    return _eol(text).strip(" \t\n")


def ws_kinds(a: Optional[str], b: Optional[str], is_title: bool) -> List[str]:
    """Opis różnic wyłącznie w białych znakach (zakłada, że normalizacja je zrównała)."""
    if a is None or b is None or a == b:
        return []
    kinds = []
    a_eol, b_eol = _eol(a), _eol(b)
    if a.count("\r") != b.count("\r") or (a_eol == b_eol and a != b):
        kinds.append("\\r\\n / \\r vs \\n")
    if a_eol == b_eol:
        return kinds
    if is_title:
        kinds.append("białe znaki na brzegach tytułu")
        return kinds
    if a_eol.rstrip("\n") != b_eol.rstrip("\n"):
        kinds.append("spacje/tabulatory na końcach linii")
    if len(a_eol) - len(a_eol.rstrip("\n")) != len(b_eol) - len(b_eol.rstrip("\n")):
        kinds.append("końcowe znaki nowej linii")
    return kinds


# --- Porównanie -------------------------------------------------------------

SAME, WS, DIFF, NA = "identyczne", "tylko białe znaki", "różnica", "n/d"


def field_state(values: List[Optional[str]], is_title: bool) -> str:
    if all(v == values[0] for v in values):
        return SAME
    norm = ws_norm_title if is_title else ws_norm_content
    normalized = [norm(v) for v in values]
    if all(v == normalized[0] for v in normalized):
        return WS
    return DIFF


@dataclass
class SongComparison:
    number: int
    present: Dict[str, int]  # liczba wpisów z tym numerem w każdym źródle
    entries: Dict[str, List[Entry]]
    title_state: str
    content_state: str
    pair_states: Dict[Tuple[str, str], Tuple[str, str]]  # (tytuł, treść)

    @property
    def structural(self) -> List[str]:
        problems = []
        for key in SOURCE_KEYS:
            count = self.present.get(key, 0)
            if count == 0:
                problems.append(f"brak w {key}")
            elif count > 1:
                problems.append(f"duplikat w {key} ({count}×)")
        return problems

    @property
    def needs_decision(self) -> bool:
        return bool(self.structural) or self.title_state != SAME or self.content_state != SAME

    @property
    def auto_whitespace(self) -> bool:
        return (
            not self.structural
            and DIFF not in (self.title_state, self.content_state)
            and WS in (self.title_state, self.content_state)
        )

    @property
    def kind(self) -> str:
        if self.structural:
            return "struktura: " + ", ".join(self.structural)
        if self.auto_whitespace:
            return "auto-whitespace"
        parts = []
        if self.title_state == DIFF:
            parts.append("tytuł")
        if self.content_state == DIFF:
            contents = [self.value(key, "content") or "" for key in SOURCE_KEYS]
            stripped = [strip_invisible(ws_norm_content(c)) for c in contents]
            if all(s == stripped[0] for s in stripped):
                loose = any(
                    is_invisible(text[i]) and i + 1 < len(text) and text[i + 1] != "\n" and not is_invisible(text[i + 1])
                    for text in contents
                    for i in range(len(text))
                )
                if loose:
                    parts.append("treść: tylko znaki niewidoczne, także w środku tekstu")
                else:
                    parts.append("treść: tylko znaki niewidoczne przed końcem linii")
            else:
                parts.append("treść")
        extra = []
        if self.title_state == WS:
            extra.append("białe znaki w tytule")
        if self.content_state == WS:
            extra.append("białe znaki w treści")
        label = " + ".join(parts)
        return f"{label} (+ {', '.join(extra)})" if extra else label

    def value(self, key: str, field_name: str) -> Optional[str]:
        """Wartość z danego źródła albo None, gdy brak/duplikat."""
        items = self.entries.get(key, [])
        if len(items) != 1:
            return None
        return getattr(items[0], field_name)

    def display_title(self) -> str:
        for key in SOURCE_KEYS:
            items = self.entries.get(key, [])
            if items and items[0].title:
                return items[0].title
        return ""


def compare_sources(sources: Dict[str, Source]) -> Dict[int, SongComparison]:
    grouped = {key: sources[key].by_number() for key in SOURCE_KEYS}
    numbers = sorted(set().union(*[set(g) for g in grouped.values()]))
    result: Dict[int, SongComparison] = {}
    for number in numbers:
        entries = {key: grouped[key].get(number, []) for key in SOURCE_KEYS}
        present = {key: len(entries[key]) for key in SOURCE_KEYS}
        unique = [key for key in SOURCE_KEYS if present[key] == 1]

        def state_for(keys: List[str], field_name: str) -> str:
            if len(keys) < 2:
                return NA
            return field_state([getattr(entries[k][0], field_name) for k in keys], field_name == "title")

        full = len(unique) == len(SOURCE_KEYS)
        title_state = state_for(unique, "title") if full else NA
        content_state = state_for(unique, "content") if full else NA
        pair_states = {}
        for a, b in PAIRS:
            if a in unique and b in unique:
                pair_states[(a, b)] = (state_for([a, b], "title"), state_for([a, b], "content"))
        result[number] = SongComparison(number, present, entries, title_state, content_state, pair_states)
    return result


# --- Format decyzji w diffs/NNNN.md ----------------------------------------

DECISION_HEADER = "## DECYZJA"
MANUAL_TITLE_HEADER = "## MANUAL-TYTUŁ"
MANUAL_CONTENT_HEADER = "## MANUAL-TREŚĆ"
MANUAL_TITLE_PLACEHOLDER = "(wypełnij tylko gdy tytuł: manual)"
MANUAL_CONTENT_PLACEHOLDER = "(wypełnij tylko gdy treść: manual)"


def diff_filename(number: int) -> str:
    return f"{number:04d}.md"


def render_decision_block(title: str = "", content: str = "", notes: str = "") -> str:
    def line(label: str, value: str) -> str:
        return f"{label}: {value}".rstrip() if value else f"{label}:"

    return "\n".join(
        [
            DECISION_HEADER,
            line("tytuł", title),
            line("treść", content),
            line("uwagi", notes),
            "",
            MANUAL_TITLE_HEADER,
            MANUAL_TITLE_PLACEHOLDER,
            "",
            MANUAL_CONTENT_HEADER,
            MANUAL_CONTENT_PLACEHOLDER,
            "",
        ]
    )


def render_index_decision(title: str, content: str) -> str:
    """Postać decyzji w kolumnie DECISIONS.md. Pusta, gdy nic nie wybrano."""
    if not title and not content:
        return ""
    return f"tytuł: {title or '?'}; treść: {content or '?'}"
