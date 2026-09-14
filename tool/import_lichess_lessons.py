"""
Lichess Lesson & Opening Import Tool (v2 — zero hardcoded content).

Sources (all official Lichess databases, fetched live):
  Openings: https://github.com/lichess-org/chess-openings  (a.tsv .. e.tsv)
            Canonical ECO code / name / PGN. FEN + SAN are RECOMPUTED locally
            with python-chess and verified by replay — never trusted blindly.
  Lessons:  https://database.lichess.org/lichess_db_puzzle.csv.zst
            The official Lichess puzzle database (PuzzleId, FEN, Moves, Rating,
            NbPlays, Themes...). Every lesson below is a REAL Lichess puzzle:
            the opponent's first move is baked into the starting FEN so the
            player moves first (matching LessonPlayerScreen semantics), and the
            remaining line is replay-verified legal with python-chess.
            Explanations reuse the official theme descriptions from lila:
            https://github.com/lichess-org/lila/blob/master/translation/source/puzzleTheme.xml

Generates:
  - assets/lessons/curriculum.json  (5 sections, 30+ categories — mirrors Lichess Practice)
  - assets/lessons/lessons_data.json (one verified Lichess puzzle per chapter slot)
  - assets/lessons/openings.json    (canonical ECO openings across e4 / d4 / flank)

Validation gate: the script FAILS (non-zero exit) unless 100% of lessons replay
legally, every mate lesson ends in checkmate, and every opening replays exactly
to its stored FEN. Broken/AI-invented positions can never be written.
"""

import csv
import io
import json
import os
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET

import chess

OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets",
    "lessons",
)

CHESS_OPENINGS_RAW = (
    "https://raw.githubusercontent.com/lichess-org/chess-openings/master/{}.tsv"
)
PUZZLE_DB_URL = "https://database.lichess.org/lichess_db_puzzle.csv.zst"
PUZZLE_THEMES_XML = (
    "https://raw.githubusercontent.com/lichess-org/lila/master/"
    "translation/source/puzzleTheme.xml"
)

# Stream at most this many raw bytes from the (304MB) puzzle DB, in chunks.
# Common themes fill their quotas within the first tens of MB, so this cap
# keeps the import fast while overflow pools guarantee 100% slot fill.
PUZZLE_BYTE_BUDGET = 220 * 1024 * 1024
HTTP_CHUNK = 4 * 1024 * 1024


def http_get(url, timeout=60):
    req = urllib.request.Request(
        url, headers={"User-Agent": "ChessMaster-Importer/2.0"}
    )
    return urllib.request.urlopen(req, timeout=timeout)


# ══════════════════════════════════════════════════════════════════════════════
# CURRICULUM SKELETON (mirrors Lichess Practice structure; content is fetched)
# kind: mate | tactic | endgame | strategy  — drives verification + wording.
# themes: preferred Lichess puzzle themes, in order (official theme names).
# ══════════════════════════════════════════════════════════════════════════════
SECTIONS = [
    {
        "id": "checkmates",
        "title": "Checkmate Mastery",
        "description": "Essential mating patterns and execution techniques",
        "icon": "flag",
        "categories": [
            {
                "id": "piece_checkmates_1",
                "title": "Piece Checkmates I",
                "subtitle": "Basic checkmates with major pieces",
                "difficulty": "Beginner",
                "icon": "shield",
                "kind": "mate",
                "themes": ["mateIn1", "mateIn2"],
                "chapterIds": [
                    "cm_queen_1",
                    "cm_queen_2",
                    "cm_two_rooks_1",
                    "cm_rook_1",
                    "cm_rook_2",
                ],
            },
            {
                "id": "checkmate_patterns_1",
                "title": "Checkmate Patterns I",
                "subtitle": "Back-rank and corridor mates",
                "difficulty": "Beginner",
                "icon": "bolt",
                "kind": "mate",
                "themes": ["backRankMate", "mateIn1", "mateIn2"],
                "chapterIds": [
                    "cm_backrank_1",
                    "cm_backrank_2",
                    "cm_backrank_3",
                    "cm_opera_1",
                ],
            },
            {
                "id": "checkmate_patterns_2",
                "title": "Checkmate Patterns II",
                "subtitle": "Anastasia, Arabian, and Hook mates",
                "difficulty": "Intermediate",
                "icon": "crosshair",
                "kind": "mate",
                "themes": [
                    "anastasiaMate",
                    "arabianMate",
                    "hookMate",
                    "cornerMate",
                    "mateIn2",
                ],
                "chapterIds": [
                    "cm_anastasia_1",
                    "cm_anastasia_2",
                    "cm_arabian_1",
                    "cm_arabian_2",
                ],
            },
            {
                "id": "checkmate_patterns_3",
                "title": "Checkmate Patterns III",
                "subtitle": "Smothered mate and variations",
                "difficulty": "Intermediate",
                "icon": "lock",
                "kind": "mate",
                "themes": ["smotheredMate", "mateIn2", "mateIn3"],
                "chapterIds": ["cm_smothered_1", "cm_smothered_2", "cm_smothered_3"],
            },
            {
                "id": "checkmate_patterns_4",
                "title": "Checkmate Patterns IV",
                "subtitle": "Boden's, Balestra, and double bishop mates",
                "difficulty": "Advanced",
                "icon": "star",
                "kind": "mate",
                "themes": [
                    "bodenMate",
                    "balestraMate",
                    "doubleBishopMate",
                    "dovetailMate",
                    "mateIn2",
                ],
                "chapterIds": ["cm_boden_1", "cm_boden_2", "cm_double_bishop_1"],
            },
            {
                "id": "piece_checkmates_2",
                "title": "Piece Checkmates II",
                "subtitle": "Two bishops and bishop with knight setup",
                "difficulty": "Advanced",
                "icon": "award",
                "kind": "mate",
                "themes": ["doubleBishopMate", "mateIn2", "mateIn3"],
                "chapterIds": ["cm_two_bishops_1", "cm_two_bishops_2"],
            },
            {
                "id": "knight_bishop_mate",
                "title": "Knight & Bishop Mate",
                "subtitle": "The ultimate test of coordination and corner driving",
                "difficulty": "Expert",
                "icon": "crown",
                "kind": "mate",
                "themes": ["mateIn3", "mateIn4", "mateIn2"],
                "chapterIds": ["cm_kb_1", "cm_kb_2"],
            },
        ],
    },
    {
        "id": "fundamental_tactics",
        "title": "Fundamental Tactics",
        "description": "The building blocks of tactical chess vision",
        "icon": "swords",
        "categories": [
            {
                "id": "the_pin",
                "title": "The Pin",
                "subtitle": "Pin pieces to more valuable targets",
                "difficulty": "Beginner",
                "icon": "pin",
                "kind": "tactic",
                "themes": ["pin"],
                "chapterIds": ["tac_pin_1", "tac_pin_2", "tac_pin_3", "tac_pin_4"],
            },
            {
                "id": "the_skewer",
                "title": "The Skewer",
                "subtitle": "Attack a high-value piece to win what lies behind",
                "difficulty": "Beginner",
                "icon": "arrow_right",
                "kind": "tactic",
                "themes": ["skewer"],
                "chapterIds": ["tac_skewer_1", "tac_skewer_2", "tac_skewer_3"],
            },
            {
                "id": "the_fork",
                "title": "The Fork",
                "subtitle": "Double attacks with knights, pawns, and pieces",
                "difficulty": "Beginner",
                "icon": "fork",
                "kind": "tactic",
                "themes": ["fork", "doubleAttack"],
                "chapterIds": ["tac_fork_1", "tac_fork_2", "tac_fork_3", "tac_fork_4"],
            },
            {
                "id": "discovered_attacks",
                "title": "Discovered Attacks",
                "subtitle": "Unleash devastating hidden line attacks",
                "difficulty": "Intermediate",
                "icon": "eye",
                "kind": "tactic",
                "themes": ["discoveredAttack", "discoveredCheck"],
                "chapterIds": ["tac_disc_1", "tac_disc_2", "tac_disc_3"],
            },
            {
                "id": "double_check",
                "title": "Double Check",
                "subtitle": "The most forcing tactical weapon in chess",
                "difficulty": "Intermediate",
                "icon": "zap",
                "kind": "tactic",
                "themes": ["doubleCheck"],
                "chapterIds": ["tac_dcheck_1", "tac_dcheck_2"],
            },
            {
                "id": "overloaded_pieces",
                "title": "Overloaded Pieces",
                "subtitle": "Exploiting defenders tasked with multiple jobs",
                "difficulty": "Intermediate",
                "icon": "layers",
                "kind": "tactic",
                "themes": ["deflection", "capturingDefender", "hangingPiece"],
                "chapterIds": ["tac_overload_1", "tac_overload_2"],
            },
            {
                "id": "zwischenzug",
                "title": "Zwischenzug",
                "subtitle": "In-between moves that disrupt calculation",
                "difficulty": "Advanced",
                "icon": "clock",
                "kind": "tactic",
                "themes": ["intermezzo", "quietMove"],
                "chapterIds": ["tac_zwischen_1", "tac_zwischen_2"],
            },
            {
                "id": "x_ray",
                "title": "X-Ray Attack",
                "subtitle": "Attacking or defending through enemy pieces",
                "difficulty": "Intermediate",
                "icon": "maximize",
                "kind": "tactic",
                "themes": ["xRayAttack", "pin"],
                "chapterIds": ["tac_xray_1", "tac_xray_2"],
            },
        ],
    },
    {
        "id": "advanced_tactics",
        "title": "Advanced Tactics",
        "description": "Combinations, sacrifices, and positional geometry",
        "icon": "flame",
        "categories": [
            {
                "id": "zugzwang",
                "title": "Zugzwang",
                "subtitle": "When any legal move ruins the position",
                "difficulty": "Advanced",
                "icon": "hand",
                "kind": "tactic",
                "themes": ["zugzwang", "quietMove"],
                "chapterIds": ["adv_zug_1", "adv_zug_2"],
            },
            {
                "id": "interference",
                "title": "Interference",
                "subtitle": "Severing the line between defending pieces",
                "difficulty": "Advanced",
                "icon": "scissors",
                "kind": "tactic",
                "themes": ["interference", "deflection"],
                "chapterIds": ["adv_interfere_1", "adv_interfere_2"],
            },
            {
                "id": "greek_gift",
                "title": "Greek Gift Sacrifice",
                "subtitle": "The classical Bxh7+ bishop sacrifice on kingside",
                "difficulty": "Advanced",
                "icon": "gift",
                "kind": "tactic",
                "themes": ["sacrifice", "kingsideAttack", "attackingF2F7"],
                "chapterIds": ["adv_greekgift_1", "adv_greekgift_2"],
            },
            {
                "id": "deflection",
                "title": "Deflection",
                "subtitle": "Forcing key defenders away from critical squares",
                "difficulty": "Intermediate",
                "icon": "shuffle",
                "kind": "tactic",
                "themes": ["deflection", "attraction"],
                "chapterIds": ["adv_deflect_1", "adv_deflect_2", "adv_deflect_3"],
            },
            {
                "id": "attraction",
                "title": "Attraction & Decoy",
                "subtitle": "Luring enemy king or queen to lethal squares",
                "difficulty": "Intermediate",
                "icon": "magnet",
                "kind": "tactic",
                "themes": ["attraction", "deflection"],
                "chapterIds": ["adv_attract_1", "adv_attract_2"],
            },
            {
                "id": "underpromotion",
                "title": "Underpromotion",
                "subtitle": "Promoting to Knight, Rook, or Bishop to win",
                "difficulty": "Intermediate",
                "icon": "chevrons_up",
                "kind": "tactic",
                "themes": ["underPromotion", "promotion", "advancedPawn"],
                "chapterIds": ["adv_underprom_1", "adv_underprom_2"],
            },
            {
                "id": "desperado",
                "title": "Desperado",
                "subtitle": "Inflicting maximum collateral before piece demise",
                "difficulty": "Advanced",
                "icon": "skull",
                "kind": "tactic",
                "themes": ["trappedPiece", "sacrifice", "hangingPiece"],
                "chapterIds": ["adv_desperado_1", "adv_desperado_2"],
            },
            {
                "id": "counter_check",
                "title": "Counter Check",
                "subtitle": "Parrying check with an even stronger check",
                "difficulty": "Advanced",
                "icon": "shield_alert",
                "kind": "tactic",
                "themes": ["discoveredCheck", "doubleCheck", "defensiveMove"],
                "chapterIds": ["adv_ccheck_1", "adv_ccheck_2"],
            },
            {
                "id": "undermining",
                "title": "Undermining",
                "subtitle": "Removing the foundation of an enemy structure",
                "difficulty": "Intermediate",
                "icon": "hammer",
                "kind": "tactic",
                "themes": ["capturingDefender", "deflection", "hangingPiece"],
                "chapterIds": ["adv_undermine_1", "adv_undermine_2"],
            },
            {
                "id": "clearance",
                "title": "Clearance Sacrifice",
                "subtitle": "Vacating squares or diagonals for a winning piece",
                "difficulty": "Advanced",
                "icon": "wind",
                "kind": "tactic",
                "themes": ["clearance", "sacrifice"],
                "chapterIds": ["adv_clear_1", "adv_clear_2"],
            },
        ],
    },
    {
        "id": "endgames",
        "title": "Endgame Essentials",
        "description": "Theoretical pawn and rook endgame techniques",
        "icon": "anchor",
        "categories": [
            {
                "id": "key_squares",
                "title": "Key Squares",
                "subtitle": "King position rules in king and pawn endings",
                "difficulty": "Beginner",
                "icon": "key",
                "kind": "endgame",
                "themes": ["pawnEndgame", "endgame"],
                "chapterIds": ["end_key_1", "end_key_2", "end_key_3"],
            },
            {
                "id": "the_opposition",
                "title": "The Opposition",
                "subtitle": "Direct, diagonal, and distant opposition",
                "difficulty": "Intermediate",
                "icon": "users",
                "kind": "endgame",
                "themes": ["pawnEndgame", "endgame"],
                "chapterIds": ["end_opp_1", "end_opp_2"],
            },
            {
                "id": "pawn_7th_rank",
                "title": "7th-Rank Rook Pawn",
                "subtitle": "Defending against queen with a-pawn or h-pawn",
                "difficulty": "Intermediate",
                "icon": "shield",
                "kind": "endgame",
                "themes": ["pawnEndgame", "queenEndgame", "endgame"],
                "chapterIds": ["end_pawn7_1", "end_pawn7_2"],
            },
            {
                "id": "basic_rook_endgames",
                "title": "Lucena & Philidor",
                "subtitle": "The two cornerstone rook endgame techniques",
                "difficulty": "Intermediate",
                "icon": "castle",
                "kind": "endgame",
                "titleOverrides": {
                    0: "Lucena Ideas in Rook Endgames",
                    1: "Philidor Ideas: Third-Rank Defense",
                },
                "themes": ["rookEndgame", "endgame"],
                "chapterIds": ["end_lucena_1", "end_philidor_1"],
            },
            {
                "id": "intermediate_rook_endings",
                "title": "Intermediate Rook Endings",
                "subtitle": "Cutting the king and active rook defense",
                "difficulty": "Advanced",
                "icon": "crosshair",
                "kind": "endgame",
                "themes": ["rookEndgame", "endgame"],
                "chapterIds": ["end_rook_cut_1", "end_rook_active_1"],
            },
            {
                "id": "practical_rook_endings",
                "title": "Practical Rook Endings",
                "subtitle": "Managing passed pawns and rooks behind pawns",
                "difficulty": "Advanced",
                "icon": "trending_up",
                "kind": "endgame",
                "themes": ["rookEndgame", "advancedPawn", "endgame"],
                "chapterIds": ["end_tarrasch_rule_1", "end_passer_race_1"],
            },
        ],
    },
    {
        "id": "middlegame_strategy",
        "title": "Middlegame & Strategy",
        "description": "Strategic planning, pawn structures, and piece placement",
        "icon": "compass",
        "categories": [
            {
                "id": "outposts",
                "title": "Knight Outposts",
                "subtitle": "Anchoring pieces on unshakeable central holes",
                "difficulty": "Intermediate",
                "icon": "target",
                "kind": "strategy",
                "themes": ["advantage", "middlegame", "crushing"],
                "chapterIds": ["mid_outpost_1", "mid_outpost_2"],
            },
            {
                "id": "open_files",
                "title": "Open Files & 7th Rank",
                "subtitle": "Controlling open avenues and pigs on the seventh",
                "difficulty": "Intermediate",
                "icon": "columns",
                "kind": "strategy",
                "themes": ["advantage", "middlegame", "backRankMate"],
                "chapterIds": ["mid_files_1", "mid_files_2"],
            },
            {
                "id": "pawn_levers",
                "title": "Pawn Levers & Weaknesses",
                "subtitle": "Pry open closed positions and target backward pawns",
                "difficulty": "Advanced",
                "icon": "activity",
                "kind": "strategy",
                "themes": ["advantage", "hangingPiece", "middlegame"],
                "chapterIds": ["mid_lever_1", "mid_lever_2"],
            },
            {
                "id": "king_safety",
                "title": "Castling & King Attacks",
                "subtitle": "Opposite-side castling storms and piece sacrifices",
                "difficulty": "Advanced",
                "icon": "zap",
                "kind": "strategy",
                "themes": ["kingsideAttack", "attackingF2F7", "sacrifice"],
                "chapterIds": ["mid_kingsafety_1", "mid_kingsafety_2"],
            },
        ],
    },
]

# Required canonical openings (ECO → required SAN prefix or None).
# The SAN prefix guarantees book-move tests + real theory lines; FEN is recomputed.
REQUIRED_OPENINGS = [
    ("C50", ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5"]),
    ("C55", ["e4", "e5", "Nf3", "Nc6", "Bc4", "Nf6"]),
    ("C70", ["e4", "e5", "Nf3", "Nc6", "Bb5"]),
    ("C65", ["e4", "e5", "Nf3", "Nc6", "Bb5", "Nf6"]),
    ("B90", ["e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6"]),
    ("B70", ["e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "g6"]),
    ("B22", ["e4", "c5", "c3"]),
    ("C02", ["e4", "e6", "d4", "d5", "e5"]),
    ("C15", ["e4", "e6", "d4", "d5", "Nc3", "Bb4"]),
    ("B12", ["e4", "c6", "d4", "d5", "e5"]),
    ("B18", ["e4", "c6", "d4", "d5", "Nd2", "dxe4", "Nxe4"]),
    ("B01", ["e4", "d5", "exd5", "Qxd5", "Nc3", "Qa5"]),
    ("C45", ["e4", "e5", "Nf3", "Nc6", "d4"]),
    ("C26", ["e4", "e5", "Nc3"]),
    ("C30", ["e4", "e5", "f4"]),
    ("C42", ["e4", "e5", "Nf3", "Nf6"]),
    ("B07", ["e4", "d6", "d4", "Nf6", "Nc3", "g6"]),
    ("D30", ["d4", "d5", "c4", "e6"]),
    ("D20", ["d4", "d5", "c4", "dxc4"]),
    ("D10", ["d4", "d5", "c4", "c6"]),
    ("D43", ["d4", "d5", "c4", "c6", "Nf3", "Nf6", "Nc3", "e6"]),
    ("E60", ["d4", "Nf6", "c4", "g6"]),
    ("E20", ["d4", "Nf6", "c4", "e6", "Nc3", "Bb4"]),
    ("D85", ["d4", "Nf6", "c4", "g6", "Nc3", "d5"]),
    ("D00", ["d4", "d5", "Bf4"]),
    ("E00", ["d4", "Nf6", "c4", "e6", "g3"]),
    ("A80", ["d4", "f5"]),
    ("A60", ["d4", "Nf6", "c4", "c5", "d5"]),
    ("A45", ["d4", "Nf6", "Bg5"]),
    ("A20", ["c4", "e5"]),
    ("A30", ["c4", "c5"]),
    ("A09", ["Nf3", "d5", "c4"]),
    ("A07", ["Nf3", "d5", "g3"]),
    ("A03", ["f4", "d5"]),
    ("C53", ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "c3"]),
    ("B56", ["e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3"]),
]


# ══════════════════════════════════════════════════════════════════════════════
# Step 1 — official Lichess theme names + descriptions (lila puzzleTheme.xml)
# ══════════════════════════════════════════════════════════════════════════════
def fetch_theme_descriptions():
    print("Fetching official Lichess theme descriptions (lila puzzleTheme.xml)...")
    with http_get(PUZZLE_THEMES_XML) as resp:
        xml_text = resp.read().decode("utf-8")
    root = ET.fromstring(xml_text)
    strings = {}
    for s in root.findall("string"):
        name = s.get("name", "")
        if name and not name.endswith("Description") and (s.text or "").strip():
            strings[name] = (s.text or "").strip()
    desc = {}
    for s in root.findall("string"):
        name = s.get("name", "")
        if name.endswith("Description"):
            base = name[: -len("Description")]
            if base in strings and (s.text or "").strip():
                desc[base] = (s.text or "").strip()
    print(f"  {len(desc)} official theme descriptions loaded.")
    return desc


# ══════════════════════════════════════════════════════════════════════════════
# Step 2 — stream the official Lichess puzzle DB, verify with python-chess
# ══════════════════════════════════════════════════════════════════════════════
def stream_puzzles(slots, overflow_kinds):
    """Fill chapter slots from the live puzzle DB. Returns (filled, stats)."""
    import zstandard

    # slot lookup: chapterId -> slot dict
    by_id = {}
    for sec in SECTIONS:
        for cat in sec["categories"]:
            for cid in cat["chapterIds"]:
                by_id[cid] = {"cat": cat, "sec": sec["id"]}
    assert set(by_id) == set(slots), "slot/category mismatch"

    filled = {}  # chapterId -> puzzle row
    seen_ids = set()
    overflow = {k: [] for k in overflow_kinds}  # kind -> [rows]
    theme_vocabulary = set()
    scanned = 0
    used_bytes = 0

    wanted_themes = set()
    for sec in SECTIONS:
        for cat in sec["categories"]:
            wanted_themes.update(cat["themes"])

    dctx = zstandard.ZstdDecompressor()

    class CountingReader:
        """Wrap the HTTP response to count raw compressed bytes pulled."""

        def __init__(self, raw):
            self.raw = raw
            self.n = 0

        def read(self, size=-1):
            data = self.raw.read(size)
            self.n += len(data)
            return data

        def readable(self):
            return True

    req = urllib.request.Request(
        PUZZLE_DB_URL, headers={"User-Agent": "ChessMaster-Importer/2.0"}
    )
    print(
        f"Streaming {PUZZLE_DB_URL} (budget {PUZZLE_BYTE_BUDGET // 1024 // 1024}MB)..."
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        counting = CountingReader(resp)
        reader = dctx.stream_reader(counting)
        text = io.TextIOWrapper(reader, encoding="utf-8", errors="replace")
        header_checked = False
        for line in text:
            if used_bytes >= PUZZLE_BYTE_BUDGET or len(filled) >= len(slots):
                break
            used_bytes = counting.n
            line = line.rstrip("\n")
            if not header_checked:
                header_checked = True
                if not line.startswith("PuzzleId"):
                    raise RuntimeError(f"Unexpected puzzle CSV header: {line[:80]}")
                continue
            if not line:
                continue
            row = parse_puzzle_row(line)
            scanned += 1
            if row is None:
                continue
            theme_vocabulary.update(row["themes"])
            if row["pid"] in seen_ids:
                continue
            if not quality_ok(row):
                continue
            if not verify_puzzle(row):
                continue
            seen_ids.add(row["pid"])
            placed = try_place(row, slots, filled, by_id)
            if not placed:
                k = kind_of(row)
                if k in overflow and len(overflow[k]) < 25:
                    overflow[k].append(row)
            if scanned % 40000 == 0:
                print(
                    f"  ...{scanned} scanned, {len(filled)}/{len(slots)} filled, "
                    f"{used_bytes // 1024 // 1024}MB"
                )
            if all_slots_filled(slots, filled):
                break
        try:
            reader.close()
        except Exception:
            pass

    print(
        f"  scanned={scanned} filled={len(filled)}/{len(slots)} "
        f"bytes={used_bytes // 1024 // 1024}MB"
    )
    return filled, overflow, theme_vocabulary, scanned


def parse_puzzle_row(line):
    try:
        parts = next(csv.reader([line]))
    except Exception:
        return None
    if len(parts) < 8:
        return None
    try:
        return {
            "pid": parts[0].strip(),
            "fen": parts[1].strip(),
            "moves": parts[2].strip().split(),
            "rating": int(parts[3]),
            "popularity": int(parts[5]),
            "nbplays": int(parts[6]),
            "themes": parts[7].strip().split(),
            "url": parts[8].strip() if len(parts) > 8 else "",
        }
    except (ValueError, IndexError):
        return None


def quality_ok(row):
    # Realistic, well-played puzzles: mid-range rating, actually played.
    # Solution = moves[1:] must be 2..8 plies (lesson player handles any length,
    # but very long lines make poor lessons).
    if not (1200 <= row["rating"] <= 2700):
        return False
    if row["nbplays"] < 200:
        return False
    if not (3 <= len(row["moves"]) <= 9):
        return False
    return True


def verify_puzzle(row):
    """Replay the full UCI line; require every move legal."""
    try:
        board = chess.Board(row["fen"])
    except ValueError:
        return False
    for uci in row["moves"]:
        try:
            move = chess.Move.from_uci(uci)
        except ValueError:
            return False
        if move not in board.legal_moves:
            return False
        board.push(move)
    row["_end_mate"] = board.is_checkmate()
    return True


def kind_of(row):
    themes = set(row["themes"])
    if themes & {
        "mateIn1",
        "mateIn2",
        "mateIn3",
        "mateIn4",
        "mateIn5",
        "smotheredMate",
        "backRankMate",
        "anastasiaMate",
        "arabianMate",
        "bodenMate",
        "doubleBishopMate",
        "hookMate",
        "dovetailMate",
        "balestraMate",
        "cornerMate",
    }:
        return "mate"
    if "endgame" in themes or themes & {
        "rookEndgame",
        "pawnEndgame",
        "queenEndgame",
        "bishopEndgame",
        "knightEndgame",
    }:
        return "endgame"
    if "middlegame" in themes:
        return "strategy"
    return "tactic"


def try_place(row, slots, filled, by_id):
    themes = set(row["themes"])
    for cid in slots:  # slots ordered by category priority
        if cid in filled:
            continue
        cat = by_id[cid]["cat"]
        if kind_of(row) != cat["kind"] and not (
            cat["kind"] == "strategy" and kind_of(row) == "tactic"
        ):
            continue
        if themes & set(cat["themes"]):
            filled[cid] = row
            return True
    return False


def all_slots_filled(slots, filled):
    return all(cid in filled for cid in slots)


# ══════════════════════════════════════════════════════════════════════════════
# Step 3 — canonical ECO openings from lichess-org/chess-openings
# ══════════════════════════════════════════════════════════════════════════════
def parse_pgn_moves(pgn):
    """Tokenize a PGN movetext (no headers) into SAN moves."""
    tokens = pgn.replace(".", " . ").split()
    sans = []
    for tok in tokens:
        t = tok.strip()
        if (
            not t
            or t in (".", "...", "…")
            or re.fullmatch(r"\d+", t)
            or t in ("1-0", "0-1", "1/2-1/2", "*")
        ):
            continue
        if re.fullmatch(r"\d+\.+", t):
            continue
        sans.append(t)
    return sans


def fetch_openings():
    print("Fetching canonical ECO data (lichess-org/chess-openings)...")
    rows = []  # (eco, name, sans[])
    for letter in "abcde":
        url = CHESS_OPENINGS_RAW.format(letter)
        with http_get(url, timeout=60) as resp:
            text = resp.read().decode("utf-8")
        lines = text.splitlines()
        for parts in csv.reader(lines, delimiter="\t"):
            if len(parts) < 3 or parts[0] == "eco":
                continue
            eco, name, pgn = parts[0].strip(), parts[1].strip(), parts[2].strip()
            sans = parse_pgn_moves(pgn)
            if eco and name and sans:
                rows.append((eco, name, sans))
    print(f"  {len(rows)} canonical ECO lines downloaded.")
    return rows


def select_openings(rows):
    """Pick one verified canonical row per required ECO/prefix."""
    by_eco = {}
    for eco, name, sans in rows:
        by_eco.setdefault(eco, []).append((name, sans))

    selected = []
    for eco, prefix in REQUIRED_OPENINGS:
        cands = by_eco.get(eco, [])
        # Prefer rows whose line starts with the required prefix; shortest wins.
        matching = [(n, s) for n, s in cands if s[: len(prefix)] == prefix]
        if not matching:
            # fall back: any row of a sibling ECO sharing the 3-char base
            sibs = [
                (n, s)
                for e, n, s in rows
                if e[:3] == eco[:3] and s[: len(prefix)] == prefix
            ]
            matching = sibs
        if not matching:
            raise RuntimeError(
                f"ECO {eco} with prefix {prefix} not found in lichess chess-openings DB"
            )
        name, sans = sorted(matching, key=lambda ns: len(ns[1]))[0]
        selected.append((eco, name, sans))

    # Verify every line by replay + recompute canonical SAN/FEN.
    openings = []
    for eco, name, sans in selected:
        board = chess.Board()
        canon = []
        for san in sans:
            move = board.parse_san(san)
            canon.append(board.san(move))
            board.push(move)
        category = (
            "King's Pawn (1. e4)"
            if canon[0] in ("e4",)
            else "Queen's Pawn (1. d4)"
            if canon[0] == "d4"
            else "Flank & Modern"
        )
        openings.append(
            {
                "eco": eco,
                "name": f"{name}",
                "category": category,
                "movesSan": canon,
                "description": (
                    f"Official Lichess ECO {eco} — {name}. "
                    f"Main line: {' '.join(canon)}. "
                    f"Reaches this position after {len(canon)} plies."
                ),
                "keyThemes": opening_themes(name, canon),
                "fen": board.fen(),
            }
        )
    return openings


def opening_themes(name, sans):
    family = name.split(":")[0].strip()
    themes = [family, f"{len(sans)}-ply theory line"]
    joined = " ".join(sans)
    if "O-O-O" in joined:
        themes.append("Queenside castling")
    if re.search(r"(?<!-)O-O(?!-)", joined):
        themes.append("Kingside castling")
    if sum("x" in s for s in sans) >= 2:
        themes.append("Early exchanges")
    if any(
        s.startswith("B") and ("g2" in s or "b2" in s or "g7" in s or "b7" in s)
        for s in sans
    ):
        themes.append("Fianchetto bishop")
    if "gambit" in name.lower():
        themes.append("Gambit play")
    return themes[:4]


# ══════════════════════════════════════════════════════════════════════════════
# Step 4 — build lesson JSON from a verified puzzle row
# ══════════════════════════════════════════════════════════════════════════════
KIND_GOAL = {
    "mate": "Find the forced checkmate.",
    "tactic": "Find the winning tactic.",
    "endgame": "Find the correct endgame technique.",
    "strategy": "Find the strongest strategic continuation.",
}

KIND_HINT = {
    "mate": "Force checkmate — every reply must still lead to mate.",
    "tactic": "Look for the move that wins material or decides the game.",
    "endgame": "Technique first: king activity, then push your plan.",
    "strategy": "Improve your worst piece and target the key weakness.",
}


def build_lesson(chapter_id, category, row, theme_desc):
    board = chess.Board(row["fen"])
    opp_move = chess.Move.from_uci(row["moves"][0])
    opp_san = board.san(opp_move)
    board.push(opp_move)
    start_fen = board.fen()
    solution = row["moves"][1:]

    side = "White" if board.turn == chess.WHITE else "Black"
    matched = [t for t in category["themes"] if t in row["themes"]]
    anchor = matched[0] if matched else row["themes"][0]
    theme_sentence = theme_desc.get(anchor, "")
    if theme_sentence and not theme_sentence.endswith("."):
        theme_sentence += "."

    overrides = category.get("titleOverrides", {})
    idx = category["chapterIds"].index(chapter_id)
    if idx in overrides:
        title = overrides[idx]
    else:
        pretty = re.sub(r"([a-z])([A-Z])", r"\1 \2", anchor)
        pretty = pretty.replace("Mate In", "Mate in").replace("In ", "in ")
        title = f"{pretty} — Lichess #{row['pid']}"

    explanation = (
        f"Official Lichess puzzle #{row['pid']} (rating {row['rating']}, "
        f"solved {row['nbplays']} times). Themes: {', '.join(row['themes'])}. "
        f"{theme_sentence} "
        f"The {len(solution)}-move solution{' ends in checkmate' if row.get('_end_mate') else ''}."
    )
    return {
        "id": chapter_id,
        "categoryId": category["id"],
        "title": title,
        "fen": start_fen,
        "instruction": f"{side} to move. {KIND_GOAL[category['kind']]} "
        f"(After {opp_san}.)",
        "solutionMoves": solution,
        "shapes": solution[:1],
        "hints": [
            KIND_HINT[category["kind"]],
            f"Lichess themes for this position: {', '.join(row['themes'])}.",
        ],
        "explanation": explanation,
        "source": {
            "puzzleId": row["pid"],
            "rating": row["rating"],
            "url": row["url"] or f"https://lichess.org/training/{row['pid']}",
        },
    }


# ══════════════════════════════════════════════════════════════════════════════
# main
# ══════════════════════════════════════════════════════════════════════════════
def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    slots = [
        cid
        for sec in SECTIONS
        for cat in sec["categories"]
        for cid in cat["chapterIds"]
    ]
    print(
        f"{len(slots)} lesson slots across "
        f"{sum(len(s['categories']) for s in SECTIONS)} categories."
    )

    theme_desc = fetch_theme_descriptions()
    filled, overflow, vocabulary, scanned = stream_puzzles(
        slots, ["mate", "tactic", "endgame", "strategy"]
    )

    # Guarantee 100% fill from same-kind overflow pools (still verified Lichess
    # puzzles, just with a broader theme than the slot's first preference).
    for cid in slots:
        if cid not in filled:
            cat = next(
                c for s in SECTIONS for c in s["categories"] if cid in c["chapterIds"]
            )
            pool = overflow.get(cat["kind"]) or overflow["tactic"]
            if not pool:
                pool = [r for rows in overflow.values() for r in rows]
            if not pool:
                raise RuntimeError(f"No verified puzzle available for {cid}")
            filled[cid] = pool.pop(0)
            print(f"  slot {cid} filled from {cat['kind']} overflow pool")

    lessons = {}
    for sec in SECTIONS:
        for cat in sec["categories"]:
            for cid in cat["chapterIds"]:
                lessons[cid] = build_lesson(cid, cat, filled[cid], theme_desc)

    openings = select_openings(fetch_openings())

    # ── validation gate ──────────────────────────────────────────────
    errors = []
    for cid, ch in lessons.items():
        try:
            board = chess.Board(ch["fen"])
        except ValueError as e:
            errors.append(f"{cid}: bad FEN {e}")
            continue
        for i, uci in enumerate(ch["solutionMoves"]):
            try:
                move = chess.Move.from_uci(uci)
            except ValueError:
                errors.append(f"{cid}: unparsable move {uci}")
                break
            if move not in board.legal_moves:
                errors.append(f"{cid}: illegal move {uci} at ply {i}")
                break
            board.push(move)
        else:
            cat = next(
                c for s in SECTIONS for c in s["categories"] if cid in c["chapterIds"]
            )
            if cat["kind"] == "mate" and not board.is_checkmate():
                errors.append(f"{cid}: mate lesson does not end in checkmate")
            continue
    for o in openings:
        board = chess.Board()
        try:
            for san in o["movesSan"]:
                board.push_san(san)
        except ValueError as e:
            errors.append(f"{o['eco']}: illegal SAN line: {e}")
            continue
        if board.fen() != o["fen"]:
            errors.append(f"{o['eco']}: FEN mismatch after replay")
    if errors:
        print("\nVALIDATION FAILED:")
        for e in errors:
            print("  " + e)
        sys.exit(1)

    # ── write ────────────────────────────────────────────────────────
    curriculum = {
        "sections": [
            {k: sec[k] for k in ("id", "title", "description", "icon")}
            | {
                "categories": [
                    {
                        k: cat[k]
                        for k in ("id", "title", "subtitle", "difficulty", "icon")
                    }
                    | {"chapterIds": cat["chapterIds"]}
                    for cat in sec["categories"]
                ]
            }
            for sec in SECTIONS
        ]
    }
    with open(os.path.join(OUTPUT_DIR, "curriculum.json"), "w", encoding="utf-8") as f:
        json.dump(curriculum, f, indent=2)
    with open(
        os.path.join(OUTPUT_DIR, "lessons_data.json"), "w", encoding="utf-8"
    ) as f:
        json.dump(lessons, f, indent=2)
    with open(os.path.join(OUTPUT_DIR, "openings.json"), "w", encoding="utf-8") as f:
        json.dump(openings, f, indent=2)

    mates = sum(
        1
        for cid, ch in lessons.items()
        if next(c for s in SECTIONS for c in s["categories"] if cid in c["chapterIds"])[
            "kind"
        ]
        == "mate"
    )
    print(
        f"\n[OK] curriculum.json — {len(curriculum['sections'])} sections, "
        f"{sum(len(s['categories']) for s in curriculum['sections'])} categories"
    )
    print(
        f"[OK] lessons_data.json — {len(lessons)} verified Lichess puzzles "
        f"({mates} mates, all ending in checkmate)"
    )
    print(
        f"[OK] openings.json — {len(openings)} canonical ECO lines, all replay-verified"
    )
    print("All assets generated from official Lichess databases. Validation passed.")


if __name__ == "__main__":
    main()
