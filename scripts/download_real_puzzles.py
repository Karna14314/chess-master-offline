#!/usr/bin/env python3
"""
Download REAL chess puzzles from Lichess database.
This script properly parses the Lichess puzzle CSV format.
"""

import requests
import json
import csv
import io
import zstandard as zstd
from collections import defaultdict

def download_lichess_puzzle_database():
    """
    Download the Lichess puzzle database (compressed with zstandard).
    This is a large file (~500MB compressed, ~2GB uncompressed).
    """
    print("Downloading Lichess puzzle database...")
    print("This may take a while (file is ~500MB)...")
    
    url = "https://database.lichess.org/lichess_db_puzzle.csv.zst"
    
    try:
        response = requests.get(url, stream=True, timeout=300)
        response.raise_for_status()
        
        # Decompress zstandard data
        dctx = zstd.ZstdDecompressor()
        
        # Read compressed data
        compressed_data = b''
        for chunk in response.iter_content(chunk_size=8192):
            compressed_data += chunk
        
        print("Decompressing data...")
        decompressed_data = dctx.decompress(compressed_data)
        
        return decompressed_data.decode('utf-8')
    
    except Exception as e:
        print(f"Error downloading database: {e}")
        print("\nAlternative: Download manually from:")
        print("https://database.lichess.org/lichess_db_puzzle.csv.zst")
        print("Then decompress and run: python scripts/parse_puzzles.py lichess_db_puzzle.csv")
        return None

def parse_lichess_csv(csv_data, max_puzzles=10000):
    """
    Parse Lichess puzzle CSV format.
    
    CSV Format:
    PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl
    
    Example:
    00008,r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2R1/PqP2bPP/7K b - - 0 24,e7e6 h6h7 h8g8 h7h6,1678,74,88,5140,crushing hangingPiece long middlegame,https://lichess.org/yyznGmXs/black#48
    """
    print("Parsing puzzle data...")
    
    puzzles = []
    csv_reader = csv.DictReader(io.StringIO(csv_data))
    
    # Rating ranges for balanced selection
    rating_buckets = defaultdict(list)
    
    for row in csv_reader:
        try:
            puzzle_id = int(row['PuzzleId'])
            fen = row['FEN']
            moves = row['Moves']
            rating = int(row['Rating'])
            themes = row['Themes']
            popularity = int(row['Popularity'])
            
            # Validate puzzle
            if not fen or not moves:
                continue
            
            # Create puzzle object
            puzzle = {
                'id': puzzle_id,
                'fen': fen,
                'moves': moves,  # Space-separated UCI moves
                'rating': rating,
                'themes': themes.replace(' ', ','),  # Convert spaces to commas
                'popularity': popularity
            }
            
            # Add to rating bucket
            bucket = (rating // 200) * 200  # Bucket by 200 rating intervals
            rating_buckets[bucket].append(puzzle)
            
        except (KeyError, ValueError) as e:
            continue
    
    print(f"Parsed {sum(len(b) for b in rating_buckets.values())} total puzzles")
    
    # Select puzzles evenly across rating ranges
    target_per_bucket = max_puzzles // len(rating_buckets)
    
    for bucket, bucket_puzzles in sorted(rating_buckets.items()):
        # Sort by popularity and take top puzzles
        bucket_puzzles.sort(key=lambda p: p['popularity'], reverse=True)
        selected = bucket_puzzles[:target_per_bucket]
        puzzles.extend(selected)
        print(f"  Rating {bucket}-{bucket+199}: Selected {len(selected)} puzzles")
    
    # If we need more puzzles, add from most popular
    if len(puzzles) < max_puzzles:
        all_remaining = []
        for bucket_puzzles in rating_buckets.values():
            all_remaining.extend(bucket_puzzles)
        
        all_remaining.sort(key=lambda p: p['popularity'], reverse=True)
        needed = max_puzzles - len(puzzles)
        puzzles.extend(all_remaining[:needed])
    
    return puzzles[:max_puzzles]

def save_puzzles_json(puzzles, output_file='assets/puzzles/puzzles.json'):
    """Save puzzles to JSON file."""
    print(f"\nSaving {len(puzzles)} puzzles to {output_file}...")
    
    # Sort by rating for better organization
    puzzles.sort(key=lambda p: p['rating'])
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(puzzles, f, indent=2, ensure_ascii=False)
    
    print(f"✓ Successfully saved {len(puzzles)} puzzles")
    
    # Print statistics
    print("\nPuzzle Statistics:")
    print(f"  Total puzzles: {len(puzzles)}")
    
    ratings = [p['rating'] for p in puzzles]
    print(f"  Rating range: {min(ratings)} - {max(ratings)}")
    print(f"  Average rating: {sum(ratings) // len(ratings)}")
    
    # Count themes
    theme_counts = defaultdict(int)
    for puzzle in puzzles:
        for theme in puzzle['themes'].split(','):
            if theme:
                theme_counts[theme] += 1
    
    print(f"  Unique themes: {len(theme_counts)}")
    print(f"  Top 10 themes:")
    for theme, count in sorted(theme_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f"    - {theme}: {count}")

def main():
    print("=" * 70)
    print("ChessMaster REAL Puzzle Downloader")
    print("=" * 70)
    print("\nThis script downloads REAL puzzles from Lichess database.")
    print("Requirements: pip install requests zstandard")
    print()
    
    # Check if zstandard is installed
    try:
        import zstandard
    except ImportError:
        print("ERROR: zstandard module not found!")
        print("Install it with: pip install zstandard")
        return
    
    # Download and parse puzzles
    csv_data = download_lichess_puzzle_database()
    
    if csv_data:
        puzzles = parse_lichess_csv(csv_data, max_puzzles=10000)
        
        if puzzles:
            save_puzzles_json(puzzles)
            
            print("\n" + "=" * 70)
            print("✓ Puzzle download complete!")
            print("=" * 70)
            print("\nNext steps:")
            print("1. Review the generated puzzles.json file")
            print("2. Rebuild the Flutter app: flutter build apk --release")
            print("3. Install and test puzzles in the app")
        else:
            print("\nERROR: No puzzles were parsed!")
    else:
        print("\nERROR: Failed to download puzzle database!")
        print("\nManual alternative:")
        print("1. Download: https://database.lichess.org/lichess_db_puzzle.csv.zst")
        print("2. Decompress with: unzstd lichess_db_puzzle.csv.zst")
        print("3. Run: python scripts/parse_puzzles_from_file.py lichess_db_puzzle.csv")

if __name__ == '__main__':
    main()
