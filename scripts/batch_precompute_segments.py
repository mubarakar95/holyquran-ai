#!/usr/bin/env python3
"""
scripts/batch_precompute_segments.py

High-performance, crash-resilient batch pipeline to pre-compute clause-by-clause
audio timestamps (ml_word_timestamps) and phrase-to-word alignments (ar_ml_alignments)
for the Holy Quran and store them permanently in Supabase.
"""

import argparse
import base64
import io
import json
import os
import random
import re
import sqlite3
import sys
import time
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import httpx
import mutagen.mp3
from tqdm import tqdm

# ── Configuration & Constants ──────────────────────────────────────────────────

SUPABASE_URL = "https://ktgbycvwpaspwusphmap.supabase.co"
SUPABASE_KEY = "sb_publishable_JpRABmZi52XJChQX9t-gBw_kicbkn8p"
DEFAULT_GEMINI_KEY = os.environ.get("GEMINI_API_KEY") or "AQ.Ab8RN6Ic7DWosMJhV5awpM4VgXic15QMI6Df49iN7VYBMTMZ7g"

DEFAULT_MODELS = [
    "gemini-3-flash-preview",
    "gemini-3.1-flash-lite",
    "gemini-3.5-flash-lite",
    "gemini-3.5-flash",
    "gemini-flash-lite-latest",
    "gemini-flash-latest",
    "gemini-3.8-flash",
]

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCRATCH_DIR = PROJECT_ROOT / "scratch"
AUDIO_CACHE_DIR = SCRATCH_DIR / "audio_cache"
CHECKPOINT_DB_PATH = SCRATCH_DIR / "checkpoint.db"
TRANSLATION_CACHE_PATH = SCRATCH_DIR / "ml_karakunnu.json"

QURAN_TEXT_PATH = PROJECT_ROOT / "assets" / "data" / "quran-text.json"
MALAYALAM_WBW_PATH = PROJECT_ROOT / "assets" / "data" / "malayalam-wbw.json"
VERSE_PAGE_MAP_PATH = PROJECT_ROOT / "assets" / "data" / "verse-page-map.json"

JUZ_START_PAGES = [
    1, 22, 42, 62, 82, 102, 122, 142, 162, 182,
    202, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
]

# ── SQLite Checkpoint Storage ─────────────────────────────────────────────────

class CheckpointManager:
    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(str(self.db_path), timeout=60)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self):
        with self._get_connection() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS checkpoints (
                    surah_number INTEGER,
                    ayah_number INTEGER,
                    status TEXT,
                    clauses_json TEXT,
                    alignments_json TEXT,
                    audio_duration_ms INTEGER,
                    error_message TEXT,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (surah_number, ayah_number)
                )
            """)
            conn.commit()

    def get_status(self, surah: int, ayah: int) -> Optional[sqlite3.Row]:
        with self._get_connection() as conn:
            cursor = conn.execute(
                "SELECT * FROM checkpoints WHERE surah_number = ? AND ayah_number = ?",
                (surah, ayah),
            )
            return cursor.fetchone()

    def save_result(
        self,
        surah: int,
        ayah: int,
        status: str,
        clauses: Optional[List[Dict[str, Any]]] = None,
        alignments: Optional[List[Dict[str, Any]]] = None,
        audio_duration_ms: Optional[int] = None,
        error_message: Optional[str] = None,
    ):
        clauses_json = json.dumps(clauses, ensure_ascii=False) if clauses is not None else None
        alignments_json = json.dumps(alignments, ensure_ascii=False) if alignments is not None else None

        with self._get_connection() as conn:
            conn.execute("""
                INSERT INTO checkpoints (
                    surah_number, ayah_number, status, clauses_json, alignments_json,
                    audio_duration_ms, error_message, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(surah_number, ayah_number) DO UPDATE SET
                    status = excluded.status,
                    clauses_json = coalesce(excluded.clauses_json, checkpoints.clauses_json),
                    alignments_json = coalesce(excluded.alignments_json, checkpoints.alignments_json),
                    audio_duration_ms = coalesce(excluded.audio_duration_ms, checkpoints.audio_duration_ms),
                    error_message = excluded.error_message,
                    updated_at = CURRENT_TIMESTAMP
            """, (surah, ayah, status, clauses_json, alignments_json, audio_duration_ms, error_message))
            conn.commit()

# ── Reference Data Loader ─────────────────────────────────────────────────────

class QuranDataLoader:
    def __init__(self):
        self.quran_text: List[Dict[str, Any]] = []
        self.malayalam_wbw: Dict[str, List[str]] = {}
        self.verse_page_map: Dict[str, int] = {}
        self.ml_karakunnu: Dict[str, str] = {}
        self.surah_verse_counts: Dict[int, int] = {}
        self._load_all()

    def _load_all(self):
        # 1. Quran text
        with open(QURAN_TEXT_PATH, "r", encoding="utf-8") as f:
            self.quran_text = json.load(f)
            for s in self.quran_text:
                self.surah_verse_counts[s["id"]] = len(s["verses"])

        # 2. Malayalam WBW
        with open(MALAYALAM_WBW_PATH, "r", encoding="utf-8") as f:
            self.malayalam_wbw = json.load(f)

        # 3. Verse-Page map
        with open(VERSE_PAGE_MAP_PATH, "r", encoding="utf-8") as f:
            self.verse_page_map = json.load(f)

        # 4. Translation text (cached or fetch once)
        self._load_or_fetch_karakunnu()

    def _load_or_fetch_karakunnu(self):
        if not TRANSLATION_CACHE_PATH.exists():
            print("[DataLoader] Fetching ml.karakunnu full translation text...")
            SCRATCH_DIR.mkdir(parents=True, exist_ok=True)
            url = "https://api.alquran.cloud/v1/quran/ml.karakunnu"
            headers = {"User-Agent": "QuranEasyMalayalam/1.0"}
            with httpx.Client(timeout=45.0) as client:
                resp = client.get(url, headers=headers)
                resp.raise_for_status()
                with open(TRANSLATION_CACHE_PATH, "wb") as f:
                    f.write(resp.content)
            print("[DataLoader] Cached ml.karakunnu to scratch/ml_karakunnu.json")

        with open(TRANSLATION_CACHE_PATH, "r", encoding="utf-8") as f:
            raw = json.load(f)
            for surah in raw["data"]["surahs"]:
                s_num = surah["number"]
                for ayah in surah["ayahs"]:
                    a_num = ayah["numberInSurah"]
                    self.ml_karakunnu[f"{s_num}:{a_num}"] = ayah["text"].strip()

    def get_ayah_arabic_words(self, surah: int, ayah: int) -> List[str]:
        s_obj = next((s for s in self.quran_text if s["id"] == surah), None)
        if not s_obj:
            return []
        a_obj = next((a for a in s_obj["verses"] if a["id"] == ayah), None)
        if not a_obj:
            return []
        return [w for w in a_obj["text"].strip().split() if w]

    def get_ayah_wbw(self, surah: int, ayah: int) -> List[str]:
        return self.malayalam_wbw.get(f"{surah}:{ayah}", [])

    def get_ayah_translation(self, surah: int, ayah: int) -> str:
        return self.ml_karakunnu.get(f"{surah}:{ayah}", "")

    def get_juz_verses(self, juz: int) -> List[Tuple[int, int]]:
        if not (1 <= juz <= 30):
            raise ValueError(f"Juz must be between 1 and 30, got {juz}")
        sp = JUZ_START_PAGES[juz - 1]
        ep = JUZ_START_PAGES[juz] if juz < 30 else 605

        verses: List[Tuple[int, int]] = []
        for vk, page in self.verse_page_map.items():
            if sp <= page < ep:
                s, a = map(int, vk.split(":"))
                verses.append((s, a))
        verses.sort(key=lambda x: (x[0], x[1]))
        return verses

# ── Audio Downloader & Duration Reader ────────────────────────────────────────

class AudioService:
    def __init__(self):
        AUDIO_CACHE_DIR.mkdir(parents=True, exist_ok=True)
        self.headers = {"User-Agent": "QuranEasyMalayalam/1.0"}

    def get_audio(self, surah: int, ayah: int) -> Tuple[bytes, int]:
        """
        Returns (audio_bytes, duration_ms).
        Caches file locally in scratch/audio_cache.
        """
        cache_file = AUDIO_CACHE_DIR / f"{surah:03d}_{ayah:03d}.mp3"
        if cache_file.exists() and cache_file.stat().st_size > 0:
            audio_bytes = cache_file.read_bytes()
        else:
            url = f"https://lalithasaram.net/audio/qtaud/transl/{surah:03d}_{ayah:03d}.mp3"
            with httpx.Client(timeout=30.0) as client:
                resp = client.get(url, headers=self.headers)
                if resp.status_code != 200:
                    raise RuntimeError(f"HTTP {resp.status_code} fetching audio: {url}")
                audio_bytes = resp.content
                cache_file.write_bytes(audio_bytes)

        duration_ms = 0
        try:
            mp3 = mutagen.mp3.MP3(io.BytesIO(audio_bytes))
            duration_ms = int(mp3.info.length * 1000)
        except Exception:
            # Fallback estimation if mutagen header parsing fails
            duration_ms = max(int(len(audio_bytes) * 8 / 64), 1000)

        return audio_bytes, duration_ms

# ── Gemini Dual Generator ─────────────────────────────────────────────────────

class GeminiGenerator:
    def __init__(self, api_key: str, models: Optional[List[str]] = None):
        self.api_key = api_key
        self.models = models or DEFAULT_MODELS

    def generate_ayah_data(
        self,
        surah: int,
        ayah: int,
        arabic_words: List[str],
        wbw_meanings: List[str],
        translation_text: str,
        audio_bytes: bytes,
        audio_duration_ms: int,
    ) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        """
        Single-call multimodal inference extracting both spoken clauses and phrase alignments.
        """
        num_words = len(arabic_words)
        b64_audio = base64.b64encode(audio_bytes).decode("utf-8")

        word_gloss_lines = []
        for idx, w in enumerate(arabic_words):
            gloss = wbw_meanings[idx] if idx < len(wbw_meanings) else ""
            word_gloss_lines.append(f"{idx}: {w} (meaning: {gloss})")
        word_gloss = "\n".join(word_gloss_lines)

        prompt = f"""You are an expert Quran linguist and audio analyst for Malayalam translation audio (Lalithasaram narration).
Ayah: {surah}:{ayah} ({num_words} Arabic words)
Exact Audio Duration: {audio_duration_ms} ms

Malayalam spoken translation text:
{translation_text}

Arabic words (0-indexed) with word-by-word gloss:
{word_gloss}

Your task is to produce synchronized audio clauses and phrase alignments in one step.

1. Listen to the Malayalam audio narration and identify the natural spoken clauses across the entire {audio_duration_ms} ms duration.
Segment the audio at semantic pauses, punctuation marks (such as commas, semicolons, and conjunction breaks), and breath pauses.
IMPORTANT CLAUSE RULES:
- The narrator speaks the translation across the full {audio_duration_ms} ms.
- If this ayah contains multiple phrases, sentences, or natural pauses, you MUST divide it into multiple clauses. Do NOT combine the entire verse into a single clause unless it is extremely short (< 5 words) and spoken in a single breath.
- The first clause must start near 0 ms, and the final clause must end near {audio_duration_ms} ms.
- The wordIndices for each clause must be contiguous sequential 0-based Arabic word indices, covering all words from 0 to {num_words - 1} without gaps.

2. Segment the Malayalam translation text into ordered phrases matching the Arabic word positions.
For each phrase:
- "phrase": exact Malayalam substring from the translation
- "arabicPositions": array of 1-based Arabic word positions (1 to {num_words})
- Every word position from 1 to {num_words} must be covered across the phrases.

Return ONLY valid JSON matching this schema:
{{
  "clauses": [
    {{ "startMs": 0, "endMs": {min(4500, max(audio_duration_ms // 2, 1000))}, "wordIndices": [0, 1] }},
    {{ "startMs": {min(4500, max(audio_duration_ms // 2, 1000))}, "endMs": {audio_duration_ms}, "wordIndices": [2, 3] }}
  ],
  "phraseAlignments": [
    {{ "phrase": "...", "arabicPositions": [1, 2] }},
    {{ "phrase": "...", "arabicPositions": [3, 4] }}
  ]
}}"""

        payload = {
            "contents": [
                {
                    "parts": [
                        {"inline_data": {"mime_type": "audio/mp3", "data": b64_audio}},
                        {"text": prompt},
                    ]
                }
            ],
            "generationConfig": {
                "response_mime_type": "application/json",
                "temperature": 0.1,
            },
        }

        last_error = None
        for model in self.models:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={self.api_key}"
            for attempt in range(4):
                try:
                    req_timeout = max(60.0, (audio_duration_ms / 1000.0) * 2.0)
                    with httpx.Client(timeout=req_timeout) as client:
                        resp = client.post(url, json=payload, headers={"Content-Type": "application/json"})
                        if resp.status_code == 200:
                            data = resp.json()
                            text = data["candidates"][0]["content"]["parts"][0]["text"]
                            clauses, alignments = self._parse_and_validate(
                                text, num_words, audio_duration_ms, translation_text, surah, ayah
                            )
                            return clauses, alignments
                        elif resp.status_code in (429, 503):
                            last_error = f"Model {model} returned HTTP {resp.status_code}: {resp.text[:200]}"
                            # Backoff and retry with jitter
                            wait_time = (2 ** (attempt + 1)) * 2.0 + random.uniform(1.0, 3.0)
                            time.sleep(wait_time)
                            continue
                        else:
                            last_error = f"Model {model} returned HTTP {resp.status_code}: {resp.text[:200]}"
                            break
                except ValueError as ve:
                    # Raised by _parse_and_validate when quality guardrails fail (e.g. single clause on long ayah)
                    last_error = f"Validation guardrail failed: {ve}"
                    time.sleep(2.0)
                    continue
                except Exception as e:
                    last_error = f"Model {model} error: {e}"
                    time.sleep(2.0)

        raise RuntimeError(f"All Gemini models failed for {surah}:{ayah}. Last error: {last_error}")

    def _parse_and_validate(
        self,
        raw_json_str: str,
        num_words: int,
        audio_duration_ms: int,
        translation_text: str,
        surah: int = 0,
        ayah: int = 0,
    ) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        # Clean potential markdown wrapping
        cleaned = re.sub(r"```json\s*", "", raw_json_str, flags=re.IGNORECASE)
        cleaned = re.sub(r"```", "", cleaned).strip()

        # Safely parse JSON whether top-level object or array of dicts
        try:
            data = json.loads(cleaned)
        except Exception:
            start_bracket = cleaned.find("[")
            start_brace = cleaned.find("{")
            if start_bracket != -1 and (start_brace == -1 or start_bracket < start_brace):
                end_bracket = cleaned.rfind("]")
                if end_bracket != -1:
                    cleaned = cleaned[start_bracket : end_bracket + 1]
            elif start_brace != -1:
                end_brace = cleaned.rfind("}")
                if end_brace != -1:
                    cleaned = cleaned[start_brace : end_brace + 1]
            data = json.loads(cleaned)

        if isinstance(data, list):
            merged: Dict[str, Any] = {}
            for item in data:
                if isinstance(item, dict):
                    for k, v in item.items():
                        if k not in merged:
                            merged[k] = v
                        elif isinstance(v, list) and isinstance(merged[k], list):
                            merged[k].extend(v)
            data = merged

        raw_clauses = (
            data.get("clauses")
            or data.get("audioClauses")
            or data.get("audio_clauses")
            or data.get("spokenClauses")
            or data.get("segments")
            or []
        )
        raw_alignments = (
            data.get("phraseAlignments")
            or data.get("phrase_alignments")
            or data.get("phrases")
            or data.get("alignment")
            or data.get("alignments")
            or []
        )

        def _parse_ms(val: Any, default: int) -> int:
            if val is None:
                return default
            try:
                f_val = float(val)
                # If timestamp is in seconds (e.g. 3.5s instead of 3500ms)
                if 0 < f_val < 120 and audio_duration_ms > 1000:
                    return int(f_val * 1000)
                return int(f_val)
            except (ValueError, TypeError):
                return default

        # 1. Validate & sanitize clauses
        clauses: List[Dict[str, Any]] = []
        covered_words = set()
        current_start = 0

        for i, c in enumerate(raw_clauses):
            raw_s = (
                c.get("startMs")
                or c.get("start_ms")
                or c.get("startTimeMs")
                or c.get("start_time_ms")
                or c.get("start")
            )
            raw_e = (
                c.get("endMs")
                or c.get("end_ms")
                or c.get("endTimeMs")
                or c.get("end_time_ms")
                or c.get("end")
            )

            s_ms = max(_parse_ms(raw_s, current_start), current_start)
            e_ms = max(_parse_ms(raw_e, s_ms + 500), s_ms + 300)

            # Extract word indices
            raw_w = (
                c.get("wordIndices")
                or c.get("word_indices")
                or c.get("words")
                or c.get("arabicWords")
                or c.get("indices")
                or []
            )

            w_indices = []
            for w in raw_w:
                try:
                    w_indices.append(int(w))
                except (ValueError, TypeError):
                    continue

            # Convert 1-based indices to 0-based if necessary
            if w_indices and min(w_indices) == 1 and max(w_indices) == num_words and 0 not in w_indices:
                w_indices = [x - 1 for x in w_indices]

            w_indices = [w for w in w_indices if 0 <= w < num_words]
            if not w_indices:
                continue

            clauses.append({
                "startMs": s_ms,
                "endMs": e_ms,
                "wordIndices": w_indices,
            })
            covered_words.update(w_indices)
            current_start = e_ms

        # If any words missed, ensure coverage
        if covered_words != set(range(num_words)) and clauses:
            missing = sorted(list(set(range(num_words)) - covered_words))
            if missing:
                clauses[-1]["wordIndices"] = sorted(list(set(clauses[-1]["wordIndices"] + missing)))

        # Quality guardrail: Long ayah should NOT have a single clause
        if num_words >= 8 and audio_duration_ms >= 8000 and len(clauses) <= 1:
            raise ValueError(
                f"Ayah {surah}:{ayah} has {num_words} words and {audio_duration_ms}ms "
                f"but produced only {len(clauses)} clause(s)."
            )

        if not clauses:
            clauses = [{
                "startMs": 0,
                "endMs": audio_duration_ms,
                "wordIndices": list(range(num_words)),
            }]

        # Clamp final clause endMs to actual audio length
        if audio_duration_ms > 0:
            last = clauses[-1]
            if last["endMs"] < audio_duration_ms:
                last["endMs"] = audio_duration_ms
            elif last["endMs"] > audio_duration_ms + 500:
                last["endMs"] = audio_duration_ms

        # 2. Validate phrase alignments
        alignments: List[Dict[str, Any]] = []
        covered_positions = set()
        for p in raw_alignments:
            phrase = str(p.get("phrase") or p.get("text") or "").strip()
            raw_pos = (
                p.get("arabicPositions")
                or p.get("arabic_positions")
                or p.get("positions")
                or p.get("wordIndices")
                or []
            )

            positions = []
            for x in raw_pos:
                try:
                    positions.append(int(x))
                except (ValueError, TypeError):
                    continue

            # Convert 0-based to 1-based if necessary
            if positions and 0 in positions and num_words not in positions:
                positions = [x + 1 for x in positions]

            valid_positions = [x for x in positions if 1 <= x <= num_words]
            if phrase and valid_positions:
                alignments.append({
                    "phrase": phrase,
                    "arabicPositions": sorted(list(set(valid_positions))),
                })
                covered_positions.update(valid_positions)

        # Ensure all 1..num_words positions are covered in alignments
        missing_positions = sorted(list(set(range(1, num_words + 1)) - covered_positions))
        if missing_positions and alignments:
            for m in missing_positions:
                attached = False
                for item in alignments:
                    pos_list = item["arabicPositions"]
                    if (m - 1) in pos_list or (m + 1) in pos_list:
                        pos_list.append(m)
                        pos_list.sort()
                        attached = True
                        break
                if not attached:
                    alignments[-1]["arabicPositions"].append(m)
                    alignments[-1]["arabicPositions"].sort()

        if not alignments:
            alignments = [{
                "phrase": translation_text,
                "arabicPositions": list(range(1, num_words + 1)),
            }]

        return clauses, alignments

# ── Supabase Ingester ─────────────────────────────────────────────────────────

class SupabaseIngester:
    def __init__(self, base_url: str = SUPABASE_URL, key: str = SUPABASE_KEY):
        self.base_url = base_url.rstrip("/")
        self.headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Prefer": "resolution=merge-duplicates,return=minimal",
            "Content-Type": "application/json",
        }

    def upsert_batch(
        self,
        batch_timestamps: List[Dict[str, Any]],
        batch_alignments: List[Dict[str, Any]],
    ) -> bool:
        """
        Upserts batches into ml_word_timestamps and ar_ml_alignments using PostgREST.
        """
        with httpx.Client(timeout=30.0) as client:
            if batch_timestamps:
                url_ts = f"{self.base_url}/rest/v1/ml_word_timestamps?on_conflict=surah_number,ayah_number"
                resp_ts = client.post(url_ts, json=batch_timestamps, headers=self.headers)
                if resp_ts.status_code not in (200, 201, 204):
                    raise RuntimeError(f"Upsert ml_word_timestamps failed: HTTP {resp_ts.status_code} {resp_ts.text}")

            if batch_alignments:
                url_al = f"{self.base_url}/rest/v1/ar_ml_alignments?on_conflict=surah_number,ayah_number"
                resp_al = client.post(url_al, json=batch_alignments, headers=self.headers)
                if resp_al.status_code not in (200, 201, 204):
                    raise RuntimeError(f"Upsert ar_ml_alignments failed: HTTP {resp_al.status_code} {resp_al.text}")

        return True

    def verify_target(self, verses: List[Tuple[int, int]], title: str):
        print(f"\n🔍 Verifying Supabase status for {title} ({len(verses)} verses)...")
        headers = {
            "apikey": self.headers["apikey"],
            "Authorization": self.headers["Authorization"],
        }

        # Group by surah
        surah_map: Dict[int, List[int]] = {}
        for s, a in verses:
            surah_map.setdefault(s, []).append(a)

        ts_lookup: Dict[Tuple[int, int], Dict[str, Any]] = {}
        al_lookup: Dict[Tuple[int, int], List[Dict[str, Any]]] = {}

        with httpx.Client(timeout=30.0) as client:
            for s, ayahs in surah_map.items():
                min_a, max_a = min(ayahs), max(ayahs)
                # Query timestamps
                url_ts = f"{self.base_url}/rest/v1/ml_word_timestamps?surah_number=eq.{s}&ayah_number=gte.{min_a}&ayah_number=lte.{max_a}&select=surah_number,ayah_number,segments"
                r_ts = client.get(url_ts, headers=headers)
                if r_ts.status_code == 200:
                    for row in r_ts.json():
                        ts_lookup[(row["surah_number"], row["ayah_number"])] = row.get("segments")

                # Query alignments
                url_al = f"{self.base_url}/rest/v1/ar_ml_alignments?surah_number=eq.{s}&ayah_number=gte.{min_a}&ayah_number=lte.{max_a}&select=surah_number,ayah_number,alignment"
                r_al = client.get(url_al, headers=headers)
                if r_al.status_code == 200:
                    for row in r_al.json():
                        al_lookup[(row["surah_number"], row["ayah_number"])] = row.get("alignment") or []

        complete = 0
        missing = 0
        for s, a in verses:
            raw_ts = ts_lookup.get((s, a))
            has_modern_clause = isinstance(raw_ts, dict) and "clauses" in raw_ts
            has_legacy_words = isinstance(raw_ts, list)
            has_alignment = (s, a) in al_lookup and len(al_lookup[(s, a)]) > 0

            is_complete = has_modern_clause and has_alignment
            if is_complete:
                complete += 1
            else:
                missing += 1

            status_icon = "✅" if is_complete else "⚠️"
            desc = []
            if has_modern_clause:
                desc.append("clauses")
            elif has_legacy_words:
                desc.append("legacy_words")
            else:
                desc.append("NO_TIMINGS")

            if has_alignment:
                desc.append("alignments")
            else:
                desc.append("NO_ALIGNMENTS")

            print(f"{status_icon} {s:3d}:{a:3d} -> {', '.join(desc)}")

        print(f"\nVerification summary: {complete}/{len(verses)} complete, {missing} incomplete.")

    def audit_coverage(self, quran_loader: QuranDataLoader):
        print("\n" + "=" * 60)
        print("🔍 SUPABASE DATABASE COVERAGE AUDIT")
        print("=" * 60)

        headers = {
            "apikey": self.headers["apikey"],
            "Authorization": self.headers["Authorization"],
            "Range-Unit": "items",
            "Range": "0-0",
            "Prefer": "count=exact",
        }

        with httpx.Client(timeout=30.0) as client:
            r1 = client.get(f"{self.base_url}/rest/v1/ml_word_timestamps?select=id", headers=headers)
            r2 = client.get(f"{self.base_url}/rest/v1/ar_ml_alignments?select=id", headers=headers)

            c1 = r1.headers.get("Content-Range", "0/0").split("/")[-1]
            c2 = r2.headers.get("Content-Range", "0/0").split("/")[-1]

        print(f"Total Ayahs in Quran : 6,236")
        print(f"ml_word_timestamps   : {c1} rows ({int(c1)/6236*100:.1f}%)")
        print(f"ar_ml_alignments     : {c2} rows ({int(c2)/6236*100:.1f}%)")
        print("-" * 60)

    def list_reports(self, status: str = "pending") -> List[Dict[str, Any]]:
        headers = {
            "apikey": self.headers["apikey"],
            "Authorization": self.headers["Authorization"],
        }
        url = f"{self.base_url}/rest/v1/ml_word_timestamps?select=surah_number,ayah_number,segments&segments->report->>status=eq.{status}&order=surah_number.asc,ayah_number.asc"
        with httpx.Client(timeout=30.0) as client:
            resp = client.get(url, headers=headers)
            if resp.status_code != 200:
                print(f"Error fetching reports: {resp.status_code} {resp.text}")
                return []
            rows = resp.json()

        reports = []
        for r in rows:
            seg = r.get("segments") or {}
            rep = seg.get("report") or {}
            reports.append({
                "surah": r.get("surah_number"),
                "ayah": r.get("ayah_number"),
                "issue_type": rep.get("issue_type", "timing_mismatch"),
                "note": rep.get("note", ""),
                "reported_at": rep.get("reported_at", ""),
                "status": rep.get("status", status),
                "app_version": rep.get("app_version", ""),
            })

        print("\n" + "=" * 78)
        print(f"📋 USER-REPORTED TIMING ISSUES ({status.upper()}): {len(reports)} AYAH(S)")
        print("=" * 78)
        if not reports:
            print(f"🎉 No {status} timing issue reports found in Supabase!")
        else:
            print(f"{'AYAH':<8} | {'ISSUE TYPE':<20} | {'REPORTED AT':<20} | {'NOTE'}")
            print("-" * 78)
            for item in reports:
                ayah_str = f"{item['surah']}:{item['ayah']}"
                rep_time = item['reported_at'][:19].replace("T", " ") if item['reported_at'] else "N/A"
                print(f"{ayah_str:<8} | {item['issue_type']:<20} | {rep_time:<20} | {item['note']}")
        print("=" * 78 + "\n")
        return reports

    def resolve_report(self, surah: int, ayah: int, resolution_notes: str = "Re-aligned by Gemini agent") -> bool:
        headers = {
            "apikey": self.headers["apikey"],
            "Authorization": self.headers["Authorization"],
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        }
        get_url = f"{self.base_url}/rest/v1/ml_word_timestamps?surah_number=eq.{surah}&ayah_number=eq.{ayah}"
        with httpx.Client(timeout=30.0) as client:
            resp = client.get(get_url, headers=headers)
            if resp.status_code != 200 or not resp.json():
                return False
            row = resp.json()[0]
            seg = row.get("segments") or {}
            rep = seg.get("report") or {}
            rep["status"] = "resolved"
            rep["resolved_at"] = datetime.now(timezone.utc).isoformat()
            rep["resolution_notes"] = resolution_notes
            seg["report"] = rep

            patch_url = f"{self.base_url}/rest/v1/ml_word_timestamps?surah_number=eq.{surah}&ayah_number=eq.{ayah}"
            patch_resp = client.patch(patch_url, headers=headers, json={"segments": seg})
            return patch_resp.status_code in [200, 204]

# ── Pipeline Runner ───────────────────────────────────────────────────────────

class BatchPipeline:
    def __init__(
        self,
        gemini_key: str = DEFAULT_GEMINI_KEY,
        concurrency: int = 4,
        dry_run: bool = False,
        force: bool = False,
        delay: float = 0.2,
    ):
        self.quran_loader = QuranDataLoader()
        self.audio_service = AudioService()
        self.gemini_generator = GeminiGenerator(api_key=gemini_key)
        self.supabase_ingester = SupabaseIngester()
        self.checkpoint_manager = CheckpointManager(CHECKPOINT_DB_PATH)
        self.concurrency = concurrency
        self.dry_run = dry_run
        self.force = force
        self.delay = delay

    def process_verse(self, surah: int, ayah: int) -> Tuple[int, int, bool, str]:
        """
        Process single verse: Checkpoint -> Download audio -> Gemini dual generation -> Save
        Returns (surah, ayah, success, message)
        """
        # Check checkpoint first unless force
        if not self.force:
            cp = self.checkpoint_manager.get_status(surah, ayah)
            if cp and cp["status"] == "UPSERTED":
                return surah, ayah, True, "Already UPSERTED (checkpoint hit)"

        try:
            arabic_words = self.quran_loader.get_ayah_arabic_words(surah, ayah)
            if not arabic_words:
                return surah, ayah, False, "No Arabic words found"

            wbw_meanings = self.quran_loader.get_ayah_wbw(surah, ayah)
            translation = self.quran_loader.get_ayah_translation(surah, ayah)

            # Download audio and get duration
            audio_bytes, duration_ms = self.audio_service.get_audio(surah, ayah)

            # Gemini dual generation
            clauses, alignments = self.gemini_generator.generate_ayah_data(
                surah=surah,
                ayah=ayah,
                arabic_words=arabic_words,
                wbw_meanings=wbw_meanings,
                translation_text=translation,
                audio_bytes=audio_bytes,
                audio_duration_ms=duration_ms,
            )

            # Save to checkpoint
            self.checkpoint_manager.save_result(
                surah=surah,
                ayah=ayah,
                status="GEMINI_DONE",
                clauses=clauses,
                alignments=alignments,
                audio_duration_ms=duration_ms,
            )

            # Upsert to Supabase unless dry-run
            if not self.dry_run:
                ts_row = {
                    "surah_number": surah,
                    "ayah_number": ayah,
                    "segments": {
                        "words": [],
                        "clauses": clauses,
                    },
                }
                al_row = {
                    "surah_number": surah,
                    "ayah_number": ayah,
                    "alignment": alignments,
                }
                self.supabase_ingester.upsert_batch([ts_row], [al_row])
                self.checkpoint_manager.save_result(surah, ayah, status="UPSERTED")

            if self.delay > 0:
                time.sleep(self.delay)

            return surah, ayah, True, f"OK ({len(clauses)} clauses, {len(alignments)} phrases)"

        except Exception as e:
            err_msg = str(e)
            self.checkpoint_manager.save_result(surah, ayah, status="FAILED", error_message=err_msg)
            return surah, ayah, False, err_msg

    def run_verses(self, verses: List[Tuple[int, int]], title: str = "Batch"):
        print(f"\n🚀 Starting {title}: {len(verses)} verses with concurrency={self.concurrency}")
        if self.dry_run:
            print("⚠️ DRY RUN MODE: No data will be written to Supabase.")
        if self.force:
            print("⚡ FORCE MODE: Re-processing all verses regardless of checkpoint.")

        success_count = 0
        fail_count = 0

        with tqdm(total=len(verses), desc=title, unit="ayah") as pbar:
            with ThreadPoolExecutor(max_workers=self.concurrency) as executor:
                futures = {
                    executor.submit(self.process_verse, s, a): (s, a) for s, a in verses
                }

                for future in as_completed(futures):
                    s, a = futures[future]
                    try:
                        surah, ayah, ok, msg = future.result()
                        if ok:
                            success_count += 1
                            pbar.set_postfix_str(f"✓ {surah}:{ayah} {msg[:25]}")
                        else:
                            fail_count += 1
                            tqdm.write(f"❌ Failed {surah}:{ayah}: {msg}")
                    except Exception as exc:
                        fail_count += 1
                        tqdm.write(f"❌ Exception on {s}:{a}: {exc}")
                    pbar.update(1)

        print(f"\n✅ {title} Finished: {success_count} succeeded, {fail_count} failed out of {len(verses)} verses.")
        return success_count, fail_count

    def fix_reports(self, target_verse: Optional[Tuple[int, int]] = None):
        """
        Re-computes alignment and audio timestamps for user-reported ayahs and marks them resolved.
        """
        reports = self.supabase_ingester.list_reports(status="pending")
        if target_verse:
            filtered = [r for r in reports if (r["surah"], r["ayah"]) == target_verse]
            if not filtered:
                print(f"ℹ️ Target Ayah {target_verse[0]}:{target_verse[1]} not currently in pending reports. Re-computing on demand...")
                reports = [{
                    "surah": target_verse[0],
                    "ayah": target_verse[1],
                    "issue_type": "on_demand_fix",
                    "note": "Re-alignment requested via CLI",
                }]
            else:
                reports = filtered

        if not reports:
            print("✨ No pending reports to fix.")
            return

        print(f"\n🔧 Re-computing and fixing {len(reports)} reported Ayah(s)...")
        resolved = 0
        for r in reports:
            s, a = r["surah"], r["ayah"]
            issue = r.get("issue_type", "timing_mismatch")
            note = r.get("note", "")
            print(f"\n▶️ Processing reported Ayah {s}:{a} (Issue: '{issue}', Note: '{note}')...")

            # Force re-generation
            self.force = True
            _, _, ok, msg = self.process_verse(s, a)
            if ok:
                res_note = f"Resolved timing issue ({issue}). Re-aligned with Gemini."
                if not self.dry_run:
                    self.supabase_ingester.resolve_report(s, a, resolution_notes=res_note)
                print(f"✅ Ayah {s}:{a} successfully fixed and resolved in Supabase! ({msg})")
                resolved += 1
            else:
                print(f"❌ Failed to fix Ayah {s}:{a}: {msg}")

        print(f"\n🎉 Finished fixing reports: {resolved}/{len(reports)} resolved successfully.")

# ── CLI Interface ─────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Pre-compute Quran audio clauses and phrase alignments and ingest into Supabase."
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--surah", type=int, help="Single Surah number (1-114)")
    group.add_argument("--juz", type=int, help="Single Juz number (1-30)")
    group.add_argument("--all", action="store_true", help="Process all 114 Surahs (6,236 ayahs)")
    group.add_argument("--audit-coverage", action="store_true", help="Audit database coverage in Supabase")
    group.add_argument("--list-reports", action="store_true", help="List all pending user-reported timing issues")
    group.add_argument("--fix-reports", action="store_true", help="Automatically re-align and resolve all pending reported ayahs")
    group.add_argument("--fix-ayah", type=str, help="Re-align and fix a specific Ayah (format: SURAH:AYAH, e.g. 2:187)")

    parser.add_argument("--verify", action="store_true", help="Verify verses in Supabase for specified target")
    parser.add_argument("--ayah", type=int, help="Single Ayah number (optional, used with --surah)")
    parser.add_argument("--concurrency", type=int, default=4, help="Worker pool concurrency (default: 4)")
    parser.add_argument("--dry-run", action="store_true", help="Run without writing to Supabase")
    parser.add_argument("--force", action="store_true", help="Force re-generation ignoring checkpoint")
    parser.add_argument("--delay", type=float, default=0.2, help="Delay between worker calls in seconds (default: 0.2)")
    parser.add_argument("--gemini-key", type=str, default=DEFAULT_GEMINI_KEY, help="Gemini API Key override")

    args = parser.parse_args()

    pipeline = BatchPipeline(
        gemini_key=args.gemini_key,
        concurrency=args.concurrency,
        dry_run=args.dry_run,
        force=args.force,
        delay=args.delay,
    )

    if args.audit_coverage:
        pipeline.supabase_ingester.audit_coverage(pipeline.quran_loader)
        return

    if args.list_reports:
        pipeline.supabase_ingester.list_reports()
        return

    if args.fix_reports:
        pipeline.fix_reports()
        return

    if args.fix_ayah:
        parts = args.fix_ayah.split(":")
        if len(parts) == 2 and parts[0].isdigit() and parts[1].isdigit():
            target = (int(parts[0]), int(parts[1]))
            pipeline.fix_reports(target_verse=target)
        else:
            print("❌ Invalid format for --fix-ayah. Use SURAH:AYAH (e.g. --fix-ayah 2:187)")
        return

    # Determine verses to process
    verses: List[Tuple[int, int]] = []
    title = ""

    if args.surah:
        s = args.surah
        if args.ayah:
            verses = [(s, args.ayah)]
            title = f"Surah {s}:{args.ayah}"
        else:
            count = pipeline.quran_loader.surah_verse_counts.get(s, 0)
            verses = [(s, a) for a in range(1, count + 1)]
            title = f"Surah {s}"
    elif args.juz:
        j = args.juz
        verses = pipeline.quran_loader.get_juz_verses(j)
        title = f"Juz {j}"
    elif args.all:
        for s, count in pipeline.quran_loader.surah_verse_counts.items():
            for a in range(1, count + 1):
                verses.append((s, a))
        verses.sort(key=lambda x: (x[0], x[1]))
        title = "Entire Quran (6,236 Ayahs)"

    if args.verify:
        pipeline.supabase_ingester.verify_target(verses, title=title)
        return

    # Execute batch run
    pipeline.run_verses(verses, title=title)


if __name__ == "__main__":
    main()
