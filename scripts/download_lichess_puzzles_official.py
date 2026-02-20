#!/usr/bin/env python3
"""
Download REAL verified puzzles from the official Lichess puzzle database.
This downloads the actual CSV file from database.lichess.org and extracts
10,000 puzzles distributed across rating ranges.

Source: https://database.lichess.org/#puzzles
Format: CSV with fields: PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags
"""

import requests
import csv
import json
import zstandard as zstd
import io
from collections import defaultdict

# URL for the official Lichess puzzle database
PUZZLE_DB_URL = "https://database.lichess.org/lichess_db_puzzle.csv.zst"

def download_and_decompress_puzzles(url, max_puzzles=10000):
    """
    Download and stream-decompress the Lichess puzzle database.
    We'll process the stream until we have enough puzzles.
    
    Args:
        url: URL to the .zst compressed CSV file
        max_puzzles: Maximum puzzles to collect before stopping
    
    Returns:
        List of CSV rows as strings
    """
    print(f"Downloading and streaming puzzles from {url}...")
    print(f"(Will stop after collecting ~{max_puzzles} puzzles)")
    
    # Stream download and decompress on-the-fly
    response = requests.get(url, stream=True)
    response.raise_for_status()
    
    dctx = zstd.ZstdDecompressor()
    stream_reader = dctx.stream_reader(response.raw)
    text_stream = io.TextIOWrapper(stream_reader, encoding='utf-8')
    
    csv_lines = []
    downloaded_mb = 0
    
    try:
        for i, line in enumerate(text_stream):
            csv_lines.append(line)
            
            if i % 10000 == 0 and i > 0:
                print(f"  Processed {i} lines...")
            
            # Stop after we have enough lines (header + puzzles)
            # We'll collect more than needed to ensure good distribution
            if i > max_puzzles * 2:
                print(f"  Collected {i} lines, stopping download...")
                break
                
    except Exception as e:
        print(f"  Stream ended or stopped: {e}")
    
    print(f"Downloaded {len(csv_lines)} lines")
    return ''.join(csv_lines)

def parse_puzzles_from_csv(csv_content, target_count=10000):
    """
    Parse puzzles from CSV content and select a diverse set.
    
    Args:
        csv_content: Decompressed CSV content as string
        target_count: Number of puzzles to extract (default 10,000)
    
    Returns:
        List of puzzle dictionaries
    """
    print(f"\nParsing CSV to extract {target_count} puzzles...")
    
    # Define rating buckets for distribution
    rating_buckets = {
        'beginner': (600, 1200),      # 2000 puzzles
        'intermediate': (1200, 1600), # 2500 puzzles
        'advanced': (1600, 2000),     # 2500 puzzles
        'expert': (2000, 2400),       # 2000 puzzles
        'master': (2400, 3000),       # 1000 puzzles
    }
    
    target_per_bucket = {
        'beginner': 2000,
        'intermediate': 2500,
        'advanced': 2500,
        'expert': 2000,
        'master': 1000,
    }
    
    puzzles_by_bucket = defaultdict(list)
    
    # Parse CSV
    csv_file = io.StringIO(csv_content)
    reader = csv.DictReader(csv_file)
    
    total_parsed = 0
    for row in reader:
        total_parsed += 1
        
        if total_parsed % 10000 == 0:
            print(f"  Parsed {total_parsed} puzzles...")
        
        try:
            rating = int(row['Rating'])
            popularity = int(row['Popularity'])
            nb_plays = int(row['NbPlays'])
            
            # Only include puzzles with good popularity and enough plays
            if popularity < 50 or nb_plays < 50:
                continue
            
            # Determine bucket
            bucket = None
            for bucket_name, (min_rating, max_rating) in rating_buckets.items():
                if min_rating <= rating < max_rating:
                    bucket = bucket_name
                    break
            
            if bucket and len(puzzles_by_bucket[bucket]) < target_per_bucket[bucket]:
                # Convert Lichess puzzle ID to numeric ID (hash it to get a number)
                puzzle_id_hash = abs(hash(row['PuzzleId'])) % (10**9)  # Keep it under 1 billion
                
                puzzle = {
                    'id': puzzle_id_hash,
                    'fen': row['FEN'],
                    'moves': row['Moves'],
                    'rating': rating,
                    'themes': row['Themes'],
                    'popularity': popularity
                }
                puzzles_by_bucket[bucket].append(puzzle)
        
        except (ValueError, KeyError) as e:
            continue
        
        # Check if we have enough puzzles
        total_collected = sum(len(puzzles) for puzzles in puzzles_by_bucket.values())
        if total_collected >= target_count:
            break
    
    print(f"\nParsed {total_parsed} total puzzles from CSV")
    
    # Combine all buckets
    all_puzzles = []
    for bucket_name in ['beginner', 'intermediate', 'advanced', 'expert', 'master']:
        bucket_puzzles = puzzles_by_bucket[bucket_name]
        all_puzzles.extend(bucket_puzzles)
        print(f"  {bucket_name}: {len(bucket_puzzles)} puzzles")
    
    return all_puzzles

def save_puzzles_json(puzzles, output_file='assets/puzzles/puzzles.json'):
    """Save puzzles to JSON file."""
    print(f"\nSaving {len(puzzles)} puzzles to {output_file}...")
    
    # Sort by rating
    puzzles.sort(key=lambda p: p['rating'])
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(puzzles, f, indent=2, ensure_ascii=False)
    
    print(f"✓ Successfully saved {len(puzzles)} verified puzzles")
    
    # Print statistics
    print("\nPuzzle Statistics:")
    print(f"  Total puzzles: {len(puzzles)}")
    
    ratings = [p['rating'] for p in puzzles]
    print(f"  Rating range: {min(ratings)} - {max(ratings)}")
    print(f"  Average rating: {sum(ratings) // len(ratings)}")
    
    # Count themes
    theme_counts = defaultdict(int)
    for puzzle in puzzles:
        for theme in puzzle['themes'].split():
            if theme:
                theme_counts[theme] += 1
    
    print(f"  Unique themes: {len(theme_counts)}")
    top_themes = sorted(theme_counts.items(), key=lambda x: x[1], reverse=True)[:10]
    print(f"  Top themes: {', '.join(f'{t}({c})' for t, c in top_themes)}")

def main():
    print("=" * 70)
    print("ChessMaster Official Lichess Puzzle Downloader")
    print("=" * 70)
    print("\nDownloading from official Lichess puzzle database...")
    print("Source: https://database.lichess.org/#puzzles")
    print("License: Creative Commons CC0 (Public Domain)")
    print("\nThis will download REAL, VERIFIED puzzles from Lichess.\n")
    
    try:
        # Download and decompress (streaming)
        csv_content = download_and_decompress_puzzles(PUZZLE_DB_URL, max_puzzles=10000)
        
        # Parse and select puzzles
        puzzles = parse_puzzles_from_csv(csv_content, target_count=10000)
        
        # Save to JSON
        save_puzzles_json(puzzles)
        
        print("\n" + "=" * 70)
        print("✓ Puzzle download complete!")
        print("=" * 70)
        print("\nNext steps:")
        print("1. Review assets/puzzles/puzzles.json")
        print("2. Rebuild: flutter clean && flutter build apk --release")
        print("3. Install: adb install -r build/app/outputs/flutter-apk/app-release.apk")
        print("4. Test puzzles - they are now REAL verified puzzles from Lichess!")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nTroubleshooting:")
        print("1. Install zstandard: pip install zstandard")
        print("2. Install requests: pip install requests")
        print("3. Check internet connection")
        return 1
    
    return 0

if __name__ == '__main__':
    exit(main())
