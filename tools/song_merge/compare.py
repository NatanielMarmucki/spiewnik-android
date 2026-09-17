#!/usr/bin/env python3
"""Porównuje źródła pieśni i generuje materiał do decyzji.

Wejście (katalog --src): ios-device.sqlite (+ -wal/-shm), ios-repo.sqlite, android.json
                         (z --no-device: tylko ios-repo.sqlite i android.json)
Wyjście (katalog --out): REPORT.md, DECISIONS.md, diffs/NNNN.md

Skrypt nie rozstrzyga, która wersja jest poprawna. Jedyne wstępnie wypełnione
decyzje dotyczą pieśni różniących się wyłącznie białymi znakami (źródło bazowe,
oznaczone auto-whitespace).

Użycie:
    python3 compare.py --src KATALOG_ZE_ZRODLAMI [--out KATALOG_WYJSCIOWY] [--no-device] [--force]
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
import unicodedata
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import songsrc
from songsrc import (
    DIFF,
    EXPECTED_COUNT,
    SAME,
    WS,
    SongComparison,
    Source,
    SourceError,
    compare_sources,
    diff_filename,
    load_sources,
    render_decision_block,
    render_index_decision,
    char_label,
    invisible_counts,
    is_invisible,
    strip_invisible,
    ws_kinds,
    ws_norm_content,
    ws_norm_title,
)

# Konfiguracja źródeł; ustawiana w main() przez _configure().
BASE = songsrc.BASE
SOURCE_KEYS = songsrc.SOURCE_KEYS
PAIRS = songsrc.PAIRS
OTHERS = [key for key in SOURCE_KEYS if key != BASE]


def _configure(with_device: bool) -> None:
    global BASE, SOURCE_KEYS, PAIRS, OTHERS
    songsrc.configure(with_device)
    BASE, SOURCE_KEYS, PAIRS = songsrc.BASE, songsrc.SOURCE_KEYS, songsrc.PAIRS
    OTHERS = [key for key in SOURCE_KEYS if key != BASE]


# --- Opis różnic (reguły, bez oceny) ---------------------------------------

def _paragraphs(text: str) -> List[str]:
    return [p for p in re.split(r"\n[ \t]*\n", text.strip("\n")) if p.strip()]


def _paragraph_label(paragraph: str, index: int) -> str:
    stripped = paragraph.lstrip()
    match = re.match(r"(\d+)\.\s", stripped)
    if match:
        return f"zwrotka {match.group(1)}"
    if stripped.lower().startswith("refren"):
        return "refren"
    return f"akapit {index + 1}"


def _tokens_with_labels(text: str) -> Tuple[List[str], List[str]]:
    tokens: List[str] = []
    labels: List[str] = []
    for index, paragraph in enumerate(_paragraphs(text)):
        label = _paragraph_label(paragraph, index)
        for token in re.findall(r"\w+|[^\w\s]", paragraph):
            tokens.append(token)
            labels.append(label)
    return tokens, labels


def _short(text: str, limit: int = 40) -> str:
    text = text.replace("\n", "⏎")
    return text if len(text) <= limit else text[: limit - 1] + "…"


def _join_tokens(tokens: List[str]) -> str:
    out = ""
    for token in tokens:
        if out and re.match(r"\w", token) and not out.endswith(("(", "[", "„", "/")):
            out += " "
        out += token
    return out


def word_changes(base: str, other: str) -> List[Tuple[str, str, str]]:
    """Lista (etykieta akapitu w bazie, stary fragment, nowy fragment)."""
    a_tokens, a_labels = _tokens_with_labels(base)
    b_tokens, b_labels = _tokens_with_labels(other)
    matcher = difflib.SequenceMatcher(None, a_tokens, b_tokens, autojunk=False)
    changes = []
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        if i1 < len(a_labels):
            label = a_labels[i1]
        elif j1 < len(b_labels):
            label = b_labels[j1]
        else:
            label = a_labels[-1] if a_labels else "tekst"
        changes.append((label, _join_tokens(a_tokens[i1:i2]), _join_tokens(b_tokens[j1:j2])))
    return changes


def describe_content(base: Optional[str], other: Optional[str], other_key: str,
                     base_by_content: Dict[str, List[int]], number: int) -> str:
    if base is None or other is None:
        return "brak treści do porównania"
    if base == other:
        return "treść identyczna"
    if ws_norm_content(base) == ws_norm_content(other):
        return "treść różni się wyłącznie białymi znakami (" + ", ".join(ws_kinds(base, other, False)) + ")"

    swapped = [n for n in base_by_content.get(ws_norm_content(other), []) if n != number]
    if swapped:
        return f"treść taka jak pieśń nr {', '.join(map(str, swapped))} w {BASE}"
    if unicodedata.normalize("NFC", base) == unicodedata.normalize("NFC", other):
        return "treść różni się wyłącznie normalizacją Unicode (NFC/NFD)"

    note = ""
    inv_base, inv_other = invisible_counts(base), invisible_counts(other)
    if inv_base != inv_other:
        chars = sorted(set(inv_base) | set(inv_other))
        counts = ", ".join(f"{char_label(ch)}: {inv_base[ch]} → {inv_other[ch]}" for ch in chars)
        glue = _unanchored_invisible_note(base, other, other_key)
        stripped_base, stripped_other = strip_invisible(base), strip_invisible(other)
        if stripped_base == stripped_other:
            return f"różnica wyłącznie w niewidocznych znakach ({counts}){glue}"
        note = f"; dodatkowo różnica w niewidocznych znakach ({counts}){glue}"
        base, other = stripped_base, stripped_other
    return _describe_words(base, other) + note


def _invisible_runs(text: str) -> List[Tuple[int, int]]:
    runs, start = [], None
    for i, ch in enumerate(text):
        if is_invisible(ch):
            if start is None:
                start = i
        elif start is not None:
            runs.append((start, i))
            start = None
    if start is not None:
        runs.append((start, len(text)))
    return runs


def _unanchored_invisible_note(base: str, other: str, other_key: str) -> str:
    """Miejsca, w których niewidoczny znak nie stoi przed \\n: po jego usunięciu
    sąsiednie fragmenty nie mają między sobą żadnego separatora."""
    notes = []
    for text, key, counterpart in ((base, BASE, other_key), (other, other_key, BASE)):
        runs = [(s, e) for s, e in _invisible_runs(text) if e < len(text) and text[e] != "\n"]
        if not runs:
            continue
        s, e = runs[0]
        context = text[max(0, s - 15):e + 15]
        where = "miejscu" if len(runs) == 1 else "miejscach"
        notes.append(
            f"; w {len(runs)} {where} w {key} taki znak nie stoi przed znakiem nowej linii, "
            f"a w {counterpart} nie ma tam żadnego separatora, np. '{visible(context)}' → "
            f"'{visible(strip_invisible(context))}'"
        )
    return "".join(notes)


def _describe_words(base: str, other: str) -> str:
    base_pars, other_pars = _paragraphs(base), _paragraphs(other)
    ascii_collapse = lambda s: re.sub(r"[ \t\r\n]+", " ", s).strip()
    if ascii_collapse(base) == ascii_collapse(other):
        if len(base_pars) != len(other_pars):
            return f"inny podział na akapity ({len(base_pars)} → {len(other_pars)})"
        return "różnica w odstępach lub podziale linii wewnątrz tekstu przy tych samych słowach"
    if base.casefold() == other.casefold():
        return "treść różni się wyłącznie wielkością liter"
    if re.findall(r"\w+", base) == re.findall(r"\w+", other):
        changes = word_changes(base, other)
        if changes:
            where = sorted({label for label, _, _ in changes})
            return f"różnica wyłącznie w interpunkcji ({len(changes)} miejsc; {', '.join(where)})"
        return "te same słowa i interpunkcja, różnica w odstępach między nimi"

    norm_base = [ascii_collapse(p) for p in base_pars]
    norm_other = [ascii_collapse(p) for p in other_pars]
    matcher = difflib.SequenceMatcher(None, norm_base, norm_other, autojunk=False)
    opcodes = [op for op in matcher.get_opcodes() if op[0] != "equal"]
    if opcodes and all(op[0] in ("insert", "delete") for op in opcodes):
        parts = []
        for tag, i1, i2, j1, j2 in opcodes:
            if tag == "insert":
                labels = [_paragraph_label(other_pars[j], j) for j in range(j1, j2)]
                parts.append(f"akapit nieobecny w {BASE} ({', '.join(labels)})")
            else:
                labels = [_paragraph_label(base_pars[i], i) for i in range(i1, i2)]
                parts.append(f"brak akapitu obecnego w {BASE} ({', '.join(labels)})")
        return "; ".join(parts)

    changes = word_changes(base, other)
    where = []
    for label, _, _ in changes:
        if label not in where:
            where.append(label)
    shown = "; ".join(f"'{_short(old)}' → '{_short(new)}'" for _, old, new in changes[:3])
    suffix = ""
    if len(base_pars) != len(other_pars):
        suffix = f"; liczba akapitów {len(base_pars)} → {len(other_pars)}"
    if len(changes) <= 3:
        return f"zmienione słowa ({', '.join(where)}): {shown}{suffix}"
    return f"{len(changes)} zmian słów ({', '.join(where)}), pierwsze: {shown}{suffix}"


def describe_title(base: Optional[str], other: Optional[str], other_key: str,
                   base_by_title: Dict[str, List[int]], other_by_title: Dict[str, List[int]],
                   base_titles: Dict[int, str], number: int) -> Optional[str]:
    if base is None or other is None or base == other:
        return None
    if ws_norm_title(base) == ws_norm_title(other):
        return "tytuł różni się wyłącznie białymi znakami"
    text = f"tytuł '{_short(base, 60)}' → '{_short(other, 60)}'"
    matches = [n for n in base_by_title.get(ws_norm_title(other), []) if n != number]
    if matches:
        reciprocal = [
            m for m in matches
            if number in other_by_title.get(ws_norm_title(base_titles.get(m)), [])
        ]
        if reciprocal:
            text += f" (tytuły zamienione miejscami z pieśnią nr {', '.join(map(str, reciprocal))})"
        else:
            text += f" (taki tytuł ma pieśń nr {', '.join(map(str, matches))} w {BASE})"
    return text


# --- Pomocnicze do markdown -------------------------------------------------

def fence(text: str, lang: str = "") -> str:
    longest = max((len(m) for m in re.findall(r"`+", text)), default=0)
    ticks = "`" * max(3, longest + 1)
    return f"{ticks}{lang}\n{text}\n{ticks}"


def visible(line: str) -> str:
    """Pokazuje \\r, białe znaki na końcu linii i znaki niewidoczne. Tylko do wyświetlania."""
    line = "".join(f"⟨U+{ord(ch):04X}⟩" if is_invisible(ch) else ch for ch in line)
    line = line.replace("\r", "␍")
    match = re.search(r"[ \t]+(␍?)$", line)
    if match:
        start = match.start()
        tail = line[start:].replace(" ", "·").replace("\t", "→")
        line = line[:start] + tail
    return line


def unified(base: Optional[str], other: Optional[str], base_key: str, other_key: str) -> str:
    if base is None or other is None:
        return "(brak danych do porównania)"
    if base == other:
        return "(identyczne z bazą)"
    a = [visible(line) for line in base.split("\n")]
    b = [visible(line) for line in other.split("\n")]
    lines = list(difflib.unified_diff(a, b, fromfile=base_key, tofile=other_key, lineterm="", n=1))
    if not lines:
        # Różnica niewidoczna po zamianie znaków na symbole, np. NFC/NFD.
        lines = [f"--- {base_key}", f"+++ {other_key}", "(różnica w znakach niewidocznych w tym widoku)"]
    return fence("\n".join(lines), "diff")


def md_cell(text: Optional[str]) -> str:
    if text is None:
        return "*(brak)*"
    return visible(text).replace("|", "\\|").replace("\n", "⏎")


# --- Generowanie plików -----------------------------------------------------

def build_lookup(sources: Dict[str, Source], field_name: str, norm) -> Dict[str, Dict[str, List[int]]]:
    lookup: Dict[str, Dict[str, List[int]]] = {}
    for key, source in sources.items():
        mapping: Dict[str, List[int]] = {}
        for entry in source.entries:
            value = getattr(entry, field_name)
            if value is not None:
                mapping.setdefault(norm(value), []).append(entry.number)
        lookup[key] = mapping
    return lookup


def prefill(song: SongComparison) -> Tuple[str, str, str]:
    """Jedyne automatyczne decyzje: pieśni różniące się wyłącznie białymi znakami."""
    if song.auto_whitespace:
        return BASE, BASE, "auto-whitespace"
    return "", "", ""


def summary_sentence(song: SongComparison, titles_lookup, contents_lookup, base_titles) -> str:
    if song.structural:
        return "Problem strukturalny: " + ", ".join(song.structural) + "."
    parts = []
    for key in OTHERS:
        base_title, other_title = song.value(BASE, "title"), song.value(key, "title")
        base_content, other_content = song.value(BASE, "content"), song.value(key, "content")
        if base_title == other_title and base_content == other_content:
            parts.append(f"{key}: identyczna")
            continue
        bits = []
        title_desc = describe_title(
            base_title, other_title, key, titles_lookup[BASE], titles_lookup[key], base_titles, song.number
        )
        if title_desc:
            bits.append(title_desc)
        if base_content != other_content:
            bits.append(describe_content(base_content, other_content, key, contents_lookup[BASE], song.number))
        else:
            bits.append("treść identyczna")
        parts.append(f"{key}: " + ", ".join(bits))
    return f"Względem {BASE} — " + "; ".join(parts) + "."


def write_diff_file(path: Path, song: SongComparison, titles_lookup, contents_lookup, base_titles) -> None:
    out: List[str] = [f"# Pieśń {song.number:04d}", ""]
    out.append(f"**Rodzaj różnicy:** {song.kind}  ")
    out.append(f"**Podsumowanie:** {summary_sentence(song, titles_lookup, contents_lookup, base_titles)}")
    out.append("")
    out.append("Legenda w diffach i tabelach: `·` spacja na końcu linii, `→` tabulator na końcu linii, "
               "`␍` znak \\r, `⟨U+XXXX⟩` znak niewidoczny (np. `⟨U+2028⟩` LINE SEPARATOR), "
               "`⏎` znak nowej linii w komórce tabeli. Symbole są tylko w podglądzie, nie w danych. "
               "Sekcja „Pełne treści” pokazuje tekst surowy, bez symboli.")
    out.append("")

    out.append("## Tytuły")
    out.append("")
    out.append("| źródło | tytuł | pochodzenie |")
    out.append("|---|---|---|")
    for key in SOURCE_KEYS:
        items = song.entries.get(key, [])
        if not items:
            out.append(f"| {key} | *(brak pieśni)* | |")
        for entry in items:
            out.append(f"| {key} | {md_cell(entry.title)} | `{entry.origin}` |")
    out.append("")

    if song.structural:
        out.append("## Wszystkie warianty treści")
        out.append("")
        for key in SOURCE_KEYS:
            for entry in song.entries.get(key, []):
                out.append(f"### {key} (`{entry.origin}`)")
                out.append("")
                out.append(fence(entry.content if entry.content is not None else "(NULL)", "text"))
                out.append("")
    else:
        base_content = song.value(BASE, "content")
        out.append(f"## Treść — unified diff (baza: {BASE})")
        out.append("")
        for key in OTHERS:
            out.append(f"### {BASE} → {key}")
            out.append("")
            out.append(unified(base_content, song.value(key, "content"), BASE, key))
            out.append("")
            other = song.value(key, "content")
            if base_content is not None and other is not None and base_content != other \
                    and unicodedata.normalize("NFC", base_content) == unicodedata.normalize("NFC", other):
                out.append("*Linie wyglądają identycznie: różnią się zapisem znaków diakrytycznych "
                           "(normalizacja Unicode NFC vs NFD), nie literami.*")
                out.append("")
            inv_base, inv_other = invisible_counts(base_content), invisible_counts(other)
            if inv_base != inv_other:
                out.append(f"Znaki niewidoczne ({BASE} → {key}):")
                out.append("")
                for ch in sorted(set(inv_base) | set(inv_other)):
                    out.append(f"- `{char_label(ch)}`: {inv_base[ch]} → {inv_other[ch]}")
                out.append("")
            if base_content is not None and other is not None and ws_norm_content(base_content) != ws_norm_content(other):
                changes = word_changes(base_content, other)
                if changes:
                    out.append(f"Zmiany na poziomie słów ({BASE} → {key}):")
                    out.append("")
                    for label, old, new in changes:
                        out.append(f"- {label}: `{old or '∅'}` → `{new or '∅'}`")
                    out.append("")

        out.append("## Pełne treści")
        out.append("")
        shown: List[Tuple[str, str]] = []
        for key in SOURCE_KEYS:
            text = song.value(key, "content")
            same_as = next((k for k, t in shown if t == text), None)
            if same_as:
                out.append(f"- {key}: identyczna jak {same_as}")
                continue
            shown.append((key, text))
        out.append("")
        for key, text in shown:
            out.append(f"<details><summary>{key}</summary>")
            out.append("")
            out.append(fence(text if text is not None else "(NULL)", "text"))
            out.append("")
            out.append("</details>")
            out.append("")

    title, content, notes = prefill(song)
    if song.auto_whitespace:
        out.append(f"*auto-whitespace: różnice wyłącznie w białych znakach, wstępnie ustawiono `{BASE}`.*")
        out.append("")
    elif not song.structural:
        hints = []
        if song.title_state == SAME:
            hints.append("tytuł identyczny we wszystkich źródłach")
        elif song.title_state == WS:
            hints.append("tytuł różni się tylko białymi znakami")
        if song.content_state == SAME:
            hints.append("treść identyczna we wszystkich źródłach")
        elif song.content_state == WS:
            hints.append("treść różni się tylko białymi znakami")
        if hints:
            out.append(f"*Informacja (bez wstępnej decyzji): {'; '.join(hints)}.*")
            out.append("")
    out.append(render_decision_block(title, content, notes))
    path.write_text("\n".join(out), encoding="utf-8")


def write_decisions(path: Path, songs: List[SongComparison], sources: Dict[str, Source]) -> None:
    out = [
        "# DECISIONS",
        "",
        f"Wygenerowano: {datetime.now().isoformat(timespec='seconds')} przez `compare.py`.",
        "",
        songsrc.mode_line(),
        "",
        "Decyzje wpisuje się w plikach `diffs/NNNN.md` (sekcje `## DECYZJA`, `## MANUAL-TYTUŁ`, "
        "`## MANUAL-TREŚĆ`). Ta tabela jest indeksem do odhaczania: `build_songs.py` sprawdza, czy "
        "kolumna „decyzja” zgadza się z plikami, i przerywa przy rozjeździe. "
        "`python3 build_songs.py --sync-index` przepisuje kolumnę z plików.",
        "",
        "Wiersze z rodzajem `auto-whitespace` różnią się wyłącznie białymi znakami lub końcami linii "
        f"i mają wstępnie decyzję `{BASE}`.",
        "",
        "Źródła (sha256):",
        "",
    ]
    for key in SOURCE_KEYS:
        out.append(f"- `{key}`: `{sources[key].meta['sha256']}`")
    out += ["", "| numer | tytuł | rodzaj różnicy | plik diffa | decyzja |", "|---|---|---|---|---|"]
    for song in songs:
        title, content, _ = prefill(song)
        name = diff_filename(song.number)
        out.append(
            f"| {song.number} | {md_cell(song.display_title())} | {song.kind} | "
            f"[diffs/{name}](diffs/{name}) | {render_index_decision(title, content)} |"
        )
    out.append("")
    path.write_text("\n".join(out), encoding="utf-8")


def write_report(path: Path, sources: Dict[str, Source], songs: Dict[int, SongComparison]) -> None:
    out = [
        "# REPORT — porównanie źródeł pieśni",
        "",
        f"Wygenerowano: {datetime.now().isoformat(timespec='seconds')} przez `compare.py`.",
        "",
        songsrc.mode_line(),
        "",
    ]
    if "ios-device" not in SOURCE_KEYS:
        out += [
            "> **Porównanie bez `ios-device.sqlite`.** Raport nie pokazuje poprawek wprowadzonych "
            "u użytkowników poza repozytorium (brak pary ios-repo vs ios-device).",
            "",
        ]
    out += [
        "Zasady porównania:",
        "",
        "- **różnica** — stringi nie są identyczne bajt w bajt i nie zrównują się po normalizacji białych znaków;",
        "- **tylko białe znaki** — teksty zrównują się po wyłącznie: zamianie `\\r\\n`/`\\r` na `\\n`, usunięciu "
        "spacji i tabulatorów z końców linii, usunięciu końcowych `\\n` z końca treści; w tytule — usunięciu "
        "spacji, tabulatorów i znaków końca linii z brzegów;",
        "- inne różnice (NBSP, NFC/NFD, wielkość liter, interpunkcja) liczą się jako **różnica**;",
        "- pole `favorite` / `ZFAVORITE` nie jest porównywane.",
        "",
        "## 1. Źródła",
        "",
        "| źródło | plik | rozmiar | sha256 | wpisów | ulubionych | -wal | -shm | tryb WAL (nagłówek) |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for key in SOURCE_KEYS:
        source = sources[key]
        favorites = sum(1 for e in source.entries if e.favorite in (1, True))
        meta = source.meta
        wal = lambda name: ("tak" if meta.get(name) else "nie") if name in meta else "n/d"
        wal_header = ("tak" if meta.get("wal_mode_header") else "nie") if "wal_mode_header" in meta else "n/d"
        out.append(
            f"| {key} | `{source.path}` | {meta['size']} | `{meta['sha256'][:16]}…` | {len(source.entries)} | "
            f"{favorites} | {wal('wal_file')} | {wal('shm_file')} | {wal_header} |"
        )
    out.append("")
    for key in SOURCE_KEYS:
        if sources[key].anomalies:
            out.append(f"**Anomalie w {key}:**")
            out.append("")
            out += [f"- {a}" for a in sources[key].anomalies]
            out.append("")

    out += ["### Znaki niewidoczne w tytułach i treściach", ""]
    rows = []
    for key in SOURCE_KEYS:
        per_char: Dict[str, Dict[str, object]] = {}
        for entry in sources[key].entries:
            for field_name in ("title", "content"):
                text = getattr(entry, field_name) or ""
                for start, end in _invisible_runs(text):
                    anchored = end == len(text) or text[end] == "\n"
                    for ch in text[start:end]:
                        stats = per_char.setdefault(ch, {"count": 0, "songs": set(), "anchored": 0, "loose": 0})
                        stats["count"] += 1
                        stats["songs"].add(entry.number)
                        stats["anchored" if anchored else "loose"] += 1
        for ch, stats in sorted(per_char.items()):
            rows.append(
                f"| {key} | `{char_label(ch)}` | {stats['count']} | {len(stats['songs'])} | "
                f"{stats['anchored']} | {stats['loose']} |"
            )
    if rows:
        out.append("Znaki spoza zwykłej spacji, `\\n`, `\\t` i `\\r`, należące do kategorii Unicode "
                   "Zl/Zp/Zs/Cf/Cc. „Przed \\n” = ciąg takich znaków kończy się tuż przed znakiem nowej "
                   "linii lub końcem tekstu.")
        out.append("")
        out.append("| źródło | znak | wystąpień | pieśni | przed \\n / na końcu | w środku tekstu |")
        out.append("|---|---|---|---|---|---|")
        out += rows
    else:
        out.append("Brak.")
    out.append("")

    out += ["## 2. Liczba pieśni i numery", ""]
    out.append("| źródło | wpisów | unikalnych numerów | min | max | numery spoza 1–2000 | puste/NULL tytuły | puste/NULL treści |")
    out.append("|---|---|---|---|---|---|---|---|")
    for key in SOURCE_KEYS:
        entries = sources[key].entries
        numbers = [e.number for e in entries]
        outside = sorted({n for n in numbers if not 1 <= n <= EXPECTED_COUNT})
        empty_titles = sum(1 for e in entries if not e.title)
        empty_contents = sum(1 for e in entries if not e.content)
        out.append(
            f"| {key} | {len(entries)} | {len(set(numbers))} | {min(numbers, default='—')} | "
            f"{max(numbers, default='—')} | {', '.join(map(str, outside)) or '—'} | {empty_titles} | {empty_contents} |"
        )
    out.append("")

    out += ["### Numery obecne tylko w części źródeł", ""]
    partial = [s for s in songs.values() if 0 < sum(1 for k in SOURCE_KEYS if s.present[k]) < len(SOURCE_KEYS)]
    if not partial:
        out.append("Brak — każdy numer występuje we wszystkich źródłach.")
    else:
        out.append("| numer | obecny w | brak w |")
        out.append("|---|---|---|")
        for song in partial:
            present = [k for k in SOURCE_KEYS if song.present[k]]
            absent = [k for k in SOURCE_KEYS if not song.present[k]]
            out.append(f"| {song.number} | {', '.join(present)} | {', '.join(absent)} |")
    out.append("")

    out += ["### Duplikaty numerów", ""]
    duplicates = [(k, s) for s in songs.values() for k in SOURCE_KEYS if s.present[k] > 1]
    if not duplicates:
        out.append("Brak.")
    else:
        out.append("| źródło | numer | wystąpień | pochodzenie |")
        out.append("|---|---|---|---|")
        for key, song in duplicates:
            origins = ", ".join(f"`{e.origin}`" for e in song.entries[key])
            out.append(f"| {key} | {song.number} | {song.present[key]} | {origins} |")
    out.append("")

    out += ["## 3. Rozbieżności w parach źródeł", ""]
    out.append("Liczone dla numerów obecnych dokładnie raz w obu źródłach pary.")
    out.append("")
    out.append("| para | porównanych | tytuł: różnica | tytuł: tylko białe znaki | treść: różnica | treść: tylko białe znaki | pieśni z jakąkolwiek różnicą |")
    out.append("|---|---|---|---|---|---|---|")
    pair_numbers: Dict[Tuple[str, str], Dict[str, List[int]]] = {}
    for pair in PAIRS:
        buckets: Dict[str, List[int]] = {"t_diff": [], "t_ws": [], "c_diff": [], "c_ws": [], "any": []}
        compared = 0
        for song in songs.values():
            if pair not in song.pair_states:
                continue
            compared += 1
            title_state, content_state = song.pair_states[pair]
            if title_state == DIFF:
                buckets["t_diff"].append(song.number)
            if title_state == WS:
                buckets["t_ws"].append(song.number)
            if content_state == DIFF:
                buckets["c_diff"].append(song.number)
            if content_state == WS:
                buckets["c_ws"].append(song.number)
            if title_state != SAME or content_state != SAME:
                buckets["any"].append(song.number)
        pair_numbers[pair] = buckets
        name = f"{pair[0]} vs {pair[1]}"
        if pair == ("ios-repo", "ios-device"):
            name = f"**{name}**"
        out.append(
            f"| {name} | {compared} | {len(buckets['t_diff'])} | {len(buckets['t_ws'])} | "
            f"{len(buckets['c_diff'])} | {len(buckets['c_ws'])} | {len(buckets['any'])} |"
        )
    out.append("")

    def number_list(numbers: List[int]) -> str:
        return ", ".join(str(n) for n in numbers) if numbers else "—"

    for pair in PAIRS:
        buckets = pair_numbers[pair]
        heading = f"### {pair[0]} vs {pair[1]}"
        if pair == ("ios-repo", "ios-device"):
            heading += " — poprawki obecne u użytkownika, a nieobecne w repozytorium (lub odwrotnie)"
        out += [heading, ""]
        out.append(f"- tytuł, różnica ({len(buckets['t_diff'])}): {number_list(buckets['t_diff'])}")
        out.append(f"- tytuł, tylko białe znaki ({len(buckets['t_ws'])}): {number_list(buckets['t_ws'])}")
        out.append(f"- treść, różnica ({len(buckets['c_diff'])}): {number_list(buckets['c_diff'])}")
        out.append(f"- treść, tylko białe znaki ({len(buckets['c_ws'])}): {number_list(buckets['c_ws'])}")
        out.append("")

    out += ["## 4. Pieśni różniące się WYŁĄCZNIE białymi znakami lub końcami linii", ""]
    ws_only = [s for s in songs.values() if s.auto_whitespace]
    if not ws_only:
        out.append("Brak.")
    else:
        out.append("| numer | tytuł | pole | rodzaje (per para) |")
        out.append("|---|---|---|---|")
        for song in ws_only:
            fields = []
            if song.title_state == WS:
                fields.append("tytuł")
            if song.content_state == WS:
                fields.append("treść")
            kinds = []
            for a, b in PAIRS:
                found = set()
                for name, is_title in (("title", True), ("content", False)):
                    found.update(ws_kinds(song.value(a, name), song.value(b, name), is_title))
                if found:
                    kinds.append(f"{a}/{b}: {', '.join(sorted(found))}")
            out.append(f"| {song.number} | {md_cell(song.display_title())} | {', '.join(fields)} | {'; '.join(kinds)} |")
    out.append("")

    out += ["## 5. Rozkład zgodności (pieśni obecne dokładnie raz we wszystkich źródłach)", ""]
    complete = [s for s in songs.values() if not s.structural]
    identical_label = "identyczne we wszystkich źródłach (bajt w bajt)"
    ws_label = "identyczne po pominięciu białych znaków"
    all_differ_label = "wszystkie trzy różne" if len(SOURCE_KEYS) == 3 else "różne"
    distribution: Counter = Counter()
    for song in complete:
        if song.title_state == SAME and song.content_state == SAME:
            distribution[identical_label] += 1
            continue
        if song.auto_whitespace:
            distribution[ws_label] += 1
            continue
        normalized = {
            key: (ws_norm_title(song.value(key, "title")), ws_norm_content(song.value(key, "content")))
            for key in SOURCE_KEYS
        }
        groups: Dict[Tuple, List[str]] = {}
        for key in SOURCE_KEYS:
            groups.setdefault(normalized[key], []).append(key)
        agreeing = [g for g in groups.values() if len(g) == 2] if len(SOURCE_KEYS) == 3 else []
        if agreeing:
            outlier = [k for k in SOURCE_KEYS if k not in agreeing[0]][0]
            distribution[f"zgodne {' = '.join(agreeing[0])}, inne {outlier}"] += 1
        else:
            distribution[all_differ_label] += 1
    out.append("| kategoria | pieśni |")
    out.append("|---|---|")
    order = [identical_label, ws_label]
    if len(SOURCE_KEYS) == 3:
        for outlier in SOURCE_KEYS:
            agreeing_keys = [k for k in SOURCE_KEYS if k != outlier]
            order.append(f"zgodne {' = '.join(agreeing_keys)}, inne {outlier}")
    order.append(all_differ_label)
    for label in order:
        out.append(f"| {label} | {distribution.get(label, 0)} |")
    out.append(f"| **razem** | **{len(complete)}** |")
    structural = len(songs) - len(complete)
    if structural:
        out.append("")
        out.append(f"Pominięte w rozkładzie (brak w źródle lub duplikat): {structural}.")
    out.append("")

    needs = [s for s in songs.values() if s.needs_decision]
    out += [
        "## 6. Do decyzji",
        "",
        f"- pieśni w `DECISIONS.md`: {len(needs)}",
        f"- w tym `auto-whitespace` (wstępnie `{BASE}`): {sum(1 for s in needs if s.auto_whitespace)}",
        f"- w tym problemy strukturalne: {sum(1 for s in needs if s.structural)}",
        f"- do ręcznego przejrzenia: {sum(1 for s in needs if not s.auto_whitespace)}",
        "",
    ]
    path.write_text("\n".join(out), encoding="utf-8")


def has_manual_work(diffs_dir: Path, decisions_path: Path) -> List[str]:
    """Zwraca listę plików, których nadpisanie zniszczyłoby wpisane decyzje."""
    from songsrc import DECISION_HEADER

    touched = []
    if decisions_path.exists():
        touched.append(str(decisions_path))
    if diffs_dir.is_dir():
        for path in sorted(diffs_dir.glob("[0-9][0-9][0-9][0-9].md")):
            text = path.read_text(encoding="utf-8")
            block = text.rsplit(DECISION_HEADER, 1)[-1]
            if re.search(r"^(tytuł|treść):[ \t]*(ios-repo|android|manual)", block, re.M) or \
               re.search(r"^uwagi:[ \t]*(?!auto-whitespace[ \t]*$)\S", block, re.M):
                touched.append(str(path))
    return touched


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--src", type=Path, default=Path.cwd(), help="katalog z plikami źródłowymi")
    parser.add_argument("--out", type=Path, default=None, help="katalog wyjściowy (domyślnie = --src)")
    parser.add_argument("--force", action="store_true",
                        help="nadpisz istniejące DECISIONS.md i diffs/ (niszczy wpisane decyzje)")
    parser.add_argument("--no-device", action="store_true",
                        help="porównaj bez ios-device.sqlite (bazą jest ios-repo)")
    args = parser.parse_args()
    _configure(with_device=not args.no_device)
    src = args.src.resolve()
    out_dir = (args.out or args.src).resolve()

    try:
        sources = load_sources(src)
    except SourceError as exc:
        print(f"BŁĄD: {exc}", file=sys.stderr)
        return 2

    diffs_dir = out_dir / "diffs"
    decisions_path = out_dir / "DECISIONS.md"
    existing = has_manual_work(diffs_dir, decisions_path)
    if existing and not args.force:
        print("BŁĄD: w katalogu wyjściowym są już wyniki (możliwe wpisane decyzje):", file=sys.stderr)
        for item in existing[:20]:
            print(f"  {item}", file=sys.stderr)
        if len(existing) > 20:
            print(f"  … i {len(existing) - 20} więcej", file=sys.stderr)
        print("Uruchom z --force, żeby je nadpisać, albo wskaż inny --out.", file=sys.stderr)
        return 3

    songs = compare_sources(sources)
    needs = [song for song in songs.values() if song.needs_decision]

    out_dir.mkdir(parents=True, exist_ok=True)
    diffs_dir.mkdir(exist_ok=True)
    for stale in diffs_dir.glob("[0-9][0-9][0-9][0-9].md"):
        stale.unlink()

    titles_lookup = build_lookup(sources, "title", ws_norm_title)
    contents_lookup = build_lookup(sources, "content", ws_norm_content)
    base_titles = {
        n: s.value(BASE, "title") for n, s in songs.items() if s.value(BASE, "title") is not None
    }
    for song in needs:
        write_diff_file(diffs_dir / diff_filename(song.number), song, titles_lookup, contents_lookup, base_titles)
    write_decisions(decisions_path, needs, sources)
    write_report(out_dir / "REPORT.md", sources, songs)

    print(f"Źródła: {', '.join(f'{k}={len(sources[k].entries)}' for k in SOURCE_KEYS)}")
    print(f"Do decyzji: {len(needs)} (auto-whitespace: {sum(1 for s in needs if s.auto_whitespace)})")
    print(f"Zapisano: {out_dir / 'REPORT.md'}, {decisions_path}, {diffs_dir}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
