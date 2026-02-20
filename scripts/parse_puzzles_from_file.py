#!/usr/bin/env python3
"""
Parse Lichess puzzle CSV file (already downloaded and decompressed).
Use this if you've manually downloaded the puzzle database.
"""

import json
import csv
import sys
from collections import defaultdict

def parse_puzzles_from_file(csv_file, max_puzzles=10000):
    """
    Parse Lichess puzzle CSV file.
    
    CSV Format:
    PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl
    """
    print(f"Reading puzzles from {csv_file}...")
    
    puzzles = []
    rating_buckets = defaultdict(list)
    
    with open(csv_file, 'r', encoding='utf-8') as f:
        csv_reader = csv.DictReader(f)
        
        for i, row in enumerate(csv_reader):
            if i % 10000 == 0:
                print(f"  Processed {i} rows...")
            
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
                
                # Skip very low popularity puzzles (likely bad quality)
                if popularity < 50:
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
    
    print(f"\nParsed {sum(len(b) for b in rating_buckets.values())} valid puzzles")
    
    # Select puzzles evenly across rating ranges
    target_per_bucket = max_puzzles // max(len(rating_buckets), 1)
    
    for bucket in sorted(rating_buckets.keys()):
        bucket_puzzles = rating_buckets[bucket]
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
        puzzles.extend([p for p in all_remaining if p not in puzzles][:needed])
    
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
    print(f"  Median rating: {sorted(ratings)[len(ratings)//2]}")
    
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
    
    # Show sample puzzles
    print(f"\nSample puzzles:")
    for i, puzzle in enumerate(puzzles[:3]):
        print(f"\n  Puzzle {i+1}:")
        print(f"    ID: {puzzle['id']}")
        print(f"    Rating: {puzzle['rating']}")
        print(f"    FEN: {puzzle['fen']}")
        print(f"    Moves: {puzzle['moves']}")
        print(f"    Themes: {puzzle['themes']}")

def main():
    print("=" * 70)
    print("ChessMaster Puzzle Parser")
    print("=" * 70)
    
    if len(sys.argv) < 2:
        print("\nUsage: python parse_puzzles_from_file.py <csv_file> [max_puzzles]")
        print("\nExample:")
        print("  python parse_puzzles_from_file.py lichess_db_puzzle.csv 10000")
        print("\nTo get the CSV file:")
        print("1. Download: https://database.lichess.org/lichess_db_puzzle.csv.zst")
        print("2. Decompress: unzstd lichess_db_puzzle.csv.zst")
        print("3. Run this script")
        return
    
    csv_file = sys.argv[1]
    max_puzzles = int(sys.argv[2]) if len(sys.argv) > 2 else 10000
    
    print(f"\nParsing up to {max_puzzles} puzzles from {csv_file}...")
    
    try:
        puzzles = parse_puzzles_from_file(csv_file, max_puzzles)
        
        if puzzles:
            save_puzzles_json(puzzles)
            
            print("\n" + "=" * 70)
            print("✓ Puzzle parsing complete!")
            print("=" * 70)
            print("\nNext steps:")
            print("1. Review the generated assets/puzzles/puzzles.json file")
            print("2. Rebuild the Flutter app: flutter build apk --release")
            print("3. Install and test puzzles in the app")
        else:
            print("\nERROR: No puzzles were parsed!")
    
    except FileNotFoundError:
        print(f"\nERROR: File not found: {csv_file}")
        print("\nMake sure you've downloaded and decompressed the Lichess puzzle database.")
    except Exception as e:
        print(f"\nERROR: {e}")

if __name__ == '__main__':
    main()
