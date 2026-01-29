import json
import csv
import io
import sys
import random
import os

try:
    import requests
    import zstandard as zstd
except ImportError:
    requests = None
    zstd = None

# Configuration
OUTPUT_FILE = 'assets/puzzles/puzzles.json'
TARGET_TOTAL_COUNT = 5500 # Aim for a bit more than 5000
MIN_POPULARITY = 80
MAX_RATING_DEVIATION = 100
LICHESS_DB_URL = 'https://database.lichess.org/lichess_db_puzzle.csv.zst'

def main():
    print(f"Starting puzzle import script...")

    # 1. Load existing puzzles
    existing_puzzles = []
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, 'r') as f:
                existing_puzzles = json.load(f)
            print(f"Loaded {len(existing_puzzles)} existing puzzles.")
        except json.JSONDecodeError:
            print("Error reading existing puzzles file. Starting fresh.")

    current_count = len(existing_puzzles)
    if current_count >= TARGET_TOTAL_COUNT:
        print(f"Already have {current_count} puzzles (target {TARGET_TOTAL_COUNT}). Exiting.")
        return

    # 2. Check dependencies
    if requests is None or zstd is None:
        print("requests or zstandard library NOT found.")
        print("Cannot download new puzzles. Please run: pip install requests zstandard")
        return

    # 3. Download and process
    try:
        download_and_process_puzzles(existing_puzzles)
    except Exception as e:
        print(f"Error downloading/processing puzzles: {e}")

def download_and_process_puzzles(existing_puzzles):
    print(f"Downloading stream from {LICHESS_DB_URL}...")
    response = requests.get(LICHESS_DB_URL, stream=True)
    response.raise_for_status()

    dctx = zstd.ZstdDecompressor()
    reader = dctx.stream_reader(response.raw)
    text_reader = io.TextIOWrapper(reader, encoding='utf-8')
    csv_reader = csv.reader(text_reader)

    # Skip header
    header = next(csv_reader, None)

    # Create a set of existing FENs to avoid duplicates (approximate check)
    existing_fens = {p.get('fen', '') for p in existing_puzzles}

    new_puzzles = []
    needed = TARGET_TOTAL_COUNT - len(existing_puzzles)
    processed = 0

    print(f"Need {needed} more puzzles...")

    for row in csv_reader:
        if len(new_puzzles) >= needed:
            break

        if not row or len(row) < 9:
            continue

        # Parse fields
        # PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags
        puzzle_id_str = row[0]
        fen = row[1]
        moves = row[2]
        try:
            rating = int(row[3])
            rating_deviation = int(row[4])
            popularity = int(row[5])
        except ValueError:
            continue

        themes = row[7]

        # Filter
        if popularity < MIN_POPULARITY or rating_deviation > MAX_RATING_DEVIATION:
            continue

        if fen in existing_fens:
            continue

        # Add to list
        # We need a unique ID. We can use the row ID or generate one.
        # The existing file uses incremental ints. Let's continue that.
        next_id = len(existing_puzzles) + len(new_puzzles) + 1

        puzzle = {
            "id": next_id,
            "fen": fen,
            "moves": moves,
            "rating": rating,
            "themes": themes,
            "popularity": popularity,
            "lichess_id": puzzle_id_str # Store original ID for reference
        }

        new_puzzles.append(puzzle)
        processed += 1

        if processed % 1000 == 0:
            print(f"Found {len(new_puzzles)} valid puzzles (scanned {processed})...", end='\r')

    print(f"\nCollected {len(new_puzzles)} new puzzles.")

    # Merge and Save
    combined_puzzles = existing_puzzles + new_puzzles
    save_puzzles(combined_puzzles)

def save_puzzles(puzzles):
    # Ensure directory exists
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

    with open(OUTPUT_FILE, 'w') as f:
        json.dump(puzzles, f, indent=2)

    print(f"Saved total {len(puzzles)} puzzles to {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
