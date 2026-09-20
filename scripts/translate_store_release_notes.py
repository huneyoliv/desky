#!/usr/bin/env python3
"""
Translates release notes and updates the Microsoft Store submission metadata JSON.
Supports all Microsoft Store locales configured in Desky.
"""

import sys
import os
import json
import urllib.request
import urllib.parse
import argparse
from typing import Dict, Any, Optional

# Max characters allowed by Microsoft Store for releaseNotes is 1500
MAX_RELEASE_NOTES_LEN = 1450

# Map Microsoft Store locale codes to Google Translate language codes
LOCALE_MAP = {
    'en-us': 'en',
    'en-gb': 'en',
    'pt-br': 'pt',
    'pt-pt': 'pt',
    'es-es': 'es',
    'es-mx': 'es',
    'ko-kr': 'ko',
    'ja-jp': 'ja',
    'zh-cn': 'zh-CN',
    'zh-tw': 'zh-TW',
    'fr-fr': 'fr',
    'de-de': 'de',
    'it-it': 'it',
    'ru-ru': 'ru',
}

def translate_text(text: str, target_lang: str) -> str:
    """Translates text to the target language using Google Translate endpoint."""
    if not text.strip():
        return ''
    if target_lang.lower() == 'en':
        return text

    try:
        url = (
            f"https://translate.googleapis.com/translate_a/single"
            f"?client=gtx&sl=en&tl={urllib.parse.quote(target_lang)}&dt=t&q="
            + urllib.parse.quote(text)
        )
        req = urllib.request.Request(
            url,
            headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            translated = ''.join([part[0] for part in data[0] if part and part[0]])
            return translated
    except Exception as e:
        print(f"[WARN] Translation to '{target_lang}' failed: {e}. Falling back to original English text.", file=sys.stderr)
        return text

def sanitize_release_notes(text: str) -> str:
    """Ensures release notes conform to length limits."""
    text = text.strip()
    if len(text) > MAX_RELEASE_NOTES_LEN:
        return text[:MAX_RELEASE_NOTES_LEN - 3].rstrip() + '...'
    return text

def update_submission_listings(submission: Dict[str, Any], release_notes_en: str) -> Dict[str, Any]:
    """Updates releaseNotes for all listings in the submission dictionary."""
    # Find listings key (case-insensitive)
    listings_key = None
    for k in submission.keys():
        if k.lower() == 'listings':
            listings_key = k
            break

    if not listings_key:
        print("[WARN] No 'listings' key found in submission JSON. Creating listings structure.", file=sys.stderr)
        listings_key = 'listings'
        submission[listings_key] = {}

    listings = submission[listings_key]
    if not isinstance(listings, dict):
        print(f"[WARN] '{listings_key}' is not a dictionary. Skipping release notes injection.", file=sys.stderr)
        return submission

    print(f"Found {len(listings)} listings in submission JSON.")

    for locale_code, listing_data in listings.items():
        loc_lower = locale_code.lower()
        target_lang = LOCALE_MAP.get(loc_lower, loc_lower.split('-')[0])

        print(f"Translating release notes for locale '{locale_code}' (target: '{target_lang}')...")
        if target_lang == 'en':
            translated_notes = release_notes_en
        else:
            translated_notes = translate_text(release_notes_en, target_lang)

        translated_notes = sanitize_release_notes(translated_notes)

        # Locate baseListing object (case-insensitive)
        if isinstance(listing_data, dict):
            base_listing_key = None
            for bk in listing_data.keys():
                if bk.lower() == 'baselisting':
                    base_listing_key = bk
                    break

            if base_listing_key and isinstance(listing_data[base_listing_key], dict):
                # Locate releaseNotes key
                rn_key = None
                for rk in listing_data[base_listing_key].keys():
                    if rk.lower() == 'releasenotes':
                        rn_key = rk
                        break
                if not rn_key:
                    rn_key = 'releaseNotes'
                listing_data[base_listing_key][rn_key] = translated_notes
            else:
                # If baseListing is missing or not a dict, attach releaseNotes directly or create baseListing
                if 'baseListing' not in listing_data:
                    listing_data['baseListing'] = {}
                listing_data['baseListing']['releaseNotes'] = translated_notes

        print(f"  [OK] '{locale_code}': {len(translated_notes)} chars")

    return submission

def main():
    parser = argparse.ArgumentParser(description="Inject localized release notes into Microsoft Store submission JSON.")
    parser.add_argument("--submission-json", required=True, help="Path to input submission JSON file.")
    parser.add_argument("--release-notes", required=True, help="Path to markdown/text release notes file.")
    parser.add_argument("--output-json", required=True, help="Path to output updated submission JSON file.")

    args = parser.parse_args()

    if not os.path.exists(args.release_notes):
        print(f"[ERROR] Release notes file not found: {args.release_notes}", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(args.submission_json):
        print(f"[ERROR] Submission JSON file not found: {args.submission_json}", file=sys.stderr)
        sys.exit(1)

    with open(args.release_notes, 'r', encoding='utf-8') as f:
        release_notes_en = f.read().strip()

    with open(args.submission_json, 'r', encoding='utf-8') as f:
        content = f.read().strip()

    # Handle potential CLI banners or non-JSON prefixes
    first_brace = content.find('{')
    last_brace = content.rfind('}')
    if first_brace == -1 or last_brace == -1:
        print("[ERROR] Could not find valid JSON object in submission input file.", file=sys.stderr)
        sys.exit(1)

    clean_json_str = content[first_brace:last_brace + 1]
    submission = json.loads(clean_json_str)

    updated_submission = update_submission_listings(submission, release_notes_en)

    with open(args.output_json, 'w', encoding='utf-8') as f:
        json.dump(updated_submission, f, ensure_ascii=False, indent=2)

    print(f"[SUCCESS] Successfully updated submission JSON written to: {args.output_json}")

if __name__ == '__main__':
    main()
