#!/usr/bin/env python3
"""
Quick CLI tool to check, inspect, and auto-fix user-reported timing issues.
Usage:
    python3 scripts/fix_reported_ayahs.py --list
    python3 scripts/fix_reported_ayahs.py --fix-all
    python3 scripts/fix_reported_ayahs.py --fix 2:187
"""
import sys
import argparse
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from batch_precompute_segments import BatchPipeline

def main():
    parser = argparse.ArgumentParser(description="Manage and auto-fix user-reported timing issues.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--list", action="store_true", help="List all pending user-reported timing issues")
    group.add_argument("--fix-all", action="store_true", help="Automatically re-align and resolve all reported ayahs")
    group.add_argument("--fix", type=str, help="Fix a specific reported ayah (e.g. 2:187)")

    parser.add_argument("--dry-run", action="store_true", help="Run without writing changes to Supabase")

    args = parser.parse_args()
    pipeline = BatchPipeline(dry_run=args.dry_run, concurrency=2)

    if args.list:
        pipeline.supabase_ingester.list_reports(status="pending")
    elif args.fix_all:
        pipeline.fix_reports()
    elif args.fix:
        parts = args.fix.split(":")
        if len(parts) == 2 and parts[0].isdigit() and parts[1].isdigit():
            pipeline.fix_reports(target_verse=(int(parts[0]), int(parts[1])))
        else:
            print("❌ Invalid format for --fix. Use SURAH:AYAH (e.g. 2:187)")

if __name__ == "__main__":
    main()
