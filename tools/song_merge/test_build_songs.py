"""Testy walidacji wyniku build_songs.py.

Uruchomienie (z katalogu tools/song_merge):
    python3 -m unittest test_build_songs.py
"""

from __future__ import annotations

import json
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Dict, List

import songsrc
from build_songs import validate_output

SCRIPT_DIR = Path(__file__).resolve().parent


def make_songbook() -> List[Dict[str, object]]:
    return [
        {"number": n, "title": f"Pieśń {n}", "content": f"1. Zażółć gęślą jaźń {n}.\n\nRefren: Alleluja!"}
        for n in range(1, songsrc.EXPECTED_COUNT + 1)
    ]


class ValidateOutputInvisibleCharactersTest(unittest.TestCase):
    def test_accepts_newlines_spaces_and_soft_hyphen(self) -> None:
        songs = make_songbook()
        songs[117]["content"] = "1. Tam znaj­dziesz pokój swój;\n2. Druga zwrotka."

        self.assertEqual(validate_output(songs), [])

    def test_rejects_forbidden_characters_in_content_and_title(self) -> None:
        forbidden = [
            " ",  # LINE SEPARATOR (Zl)
            " ",  # PARAGRAPH SEPARATOR (Zp)
            "\r",  # CARRIAGE RETURN (Cc)
            "\t",  # CHARACTER TABULATION (Cc)
            "\x00",  # NULL (Cc)
            "",  # NEXT LINE (Cc)
            "​",  # ZERO WIDTH SPACE (Cf)
            "‍",  # ZERO WIDTH JOINER (Cf)
            "﻿",  # ZERO WIDTH NO-BREAK SPACE / BOM (Cf)
            "‮",  # RIGHT-TO-LEFT OVERRIDE (Cf)
            "⁦",  # LEFT-TO-RIGHT ISOLATE (Cf)
        ]
        for character in forbidden:
            code_point = f"U+{ord(character):04X}"
            for field in ("content", "title"):
                with self.subTest(character=code_point, field=field):
                    songs = make_songbook()
                    songs[291][field] = f"Zawładnij{character} Panie"

                    errors = validate_output(songs)

                    self.assertIn("niewidoczne znaki sterujące w 1 pieśniach: 292", errors)
                    self.assertIn(
                        True, [e.startswith(f"nr 292: {field}: {code_point} ") for e in errors], errors
                    )

    def test_lists_every_song_with_forbidden_characters_once(self) -> None:
        songs = make_songbook()
        songs[9]["content"] = "a \nb \nc"
        songs[9]["title"] = "Tytuł "
        songs[1999]["content"] = "koniec​"

        errors = validate_output(songs)

        self.assertIn("niewidoczne znaki sterujące w 2 pieśniach: 10, 2000", errors)
        self.assertIn(
            "nr 10: title: U+2029 PARAGRAPH SEPARATOR ×1; content: U+2028 LINE SEPARATOR ×2", errors
        )


class BuildRefusesInvisibleCharactersTest(unittest.TestCase):
    def test_build_stops_and_reports_song_numbers_without_writing_output(self) -> None:
        songs = make_songbook()
        songs[6]["content"] = "1. Pierwsza zwrotka. \n2. Druga zwrotka."

        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            self._write_sources(work, songs)
            songsrc.configure(with_device=False)
            (work / "DECISIONS.md").write_text(f"# DECISIONS\n\n{songsrc.mode_line()}\n", encoding="utf-8")
            songsrc.configure(with_device=True)
            output = work / "songs_data_v2.json"

            result = subprocess.run(
                [sys.executable, "-B", str(SCRIPT_DIR / "build_songs.py"),
                 "--work", str(work), "--no-device", "--out", str(output)],
                capture_output=True, text=True, cwd=SCRIPT_DIR,
            )

            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertIn("niewidoczne znaki sterujące w 1 pieśniach: 7", result.stderr)
            self.assertIn("nr 7: content: U+2029 PARAGRAPH SEPARATOR ×1", result.stderr)
            self.assertFalse(output.exists())

    @staticmethod
    def _write_sources(directory: Path, songs: List[Dict[str, object]]) -> None:
        connection = sqlite3.connect(str(directory / "ios-repo.sqlite"))
        connection.execute(
            "CREATE TABLE ZSONG (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, "
            "ZFAVORITE INTEGER, ZNUMBER INTEGER, ZCONTENT VARCHAR, ZTITLE VARCHAR)"
        )
        connection.executemany(
            "INSERT INTO ZSONG VALUES (?, 1, 1, 0, ?, ?, ?)",
            [(s["number"], s["number"], s["content"], s["title"]) for s in songs],
        )
        connection.commit()
        connection.close()
        (directory / "android.json").write_text(json.dumps({"songs": songs}, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
