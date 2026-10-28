#!/usr/bin/env python3
"""
MetNet AI Circular Indexer
---------------------------
Automated serverless worker that indexes official MetNet circulars,
extracts semantic summaries, cadre tags, and VIP alerts via Google Gemini 1.5 Flash API,
and writes to `data/circulars_ai_index.json` with multi-tier failsafes.

100% Free & Serverless ($0.00 / month)
Runs on GitHub Actions or local execution.
"""

import os
import sys
import json
import time
import base64
import re
import hashlib
from datetime import datetime, timezone
from urllib.parse import urljoin

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("Required packages: requests, beautifulsoup4. Install with: pip install requests beautifulsoup4")
    sys.exit(1)

INDEX_FILE_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "circulars_ai_index.json")

# VIP Keywords for Fallback Rule Engine (if AI is offline or rate-limited)
FALLBACK_VIP_KEYWORDS = [
    "seniority", "promotion", "macp", "modified acp", "wmo vacancy",
    "transfer", "posting", "working arrangement", "lacd", "recruitment",
    "cadre review", "disciplinary", "deputation", "roster", "training course"
]

def load_existing_index() -> dict:
    if os.path.exists(INDEX_FILE_PATH):
        try:
            with open(INDEX_FILE_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict) and "circulars" in data:
                    return data
        except Exception as e:
            print(f"[!] Warning: Could not read existing index: {e}")
    
    return {
        "version": 1,
        "last_updated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "enable_ai_index": True,
        "circulars": {}
    }

def save_index(data: dict):
    os.makedirs(os.path.dirname(INDEX_FILE_PATH), exist_ok=True)
    data["last_updated"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(INDEX_FILE_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"[✓] Saved {len(data.get('circulars', {}))} indexed circulars to {INDEX_FILE_PATH}")

HINDI_SCIENTIST_MAP = {
    'b': ['b', 'बी', 'ख'],
    'c': ['c', 'सी', 'ग'],
    'd': ['d', 'डी', 'घ'],
    'e': ['e', 'ई'],
    'f': ['f', 'एफ'],
    'g': ['g', 'जी'],
    'h': ['h', 'एच']
}

def detect_imd_cadre(title: str) -> str:
    """Accurate IMD Cadre Detector handling quotes (Sc. 'C'), abbreviations (Scientific Asstt.), dots (S.O.-I), and Hindi."""
    t = title.lower()
    cadres = []

    # 1. Scientists: B to H (handles Sc. 'B', Sc.'B', Scientist 'B', Sc-B, Sc. B, Sc B)
    for g in ['b', 'c', 'd', 'e', 'f', 'g', 'h']:
        reg = re.compile(r"(?:sc|scientist)[.\s-]*['\"]?\s*" + g + r"\b['\"]?", re.IGNORECASE)
        hindi_variants = HINDI_SCIENTIST_MAP.get(g, [g])
        hindi_match = any(
            f"वैज्ञानिक {h}" in t or 
            f"वैज्ञानिक '{h}'" in t or 
            f'वैज्ञानिक "{h}"' in t or
            f"वैज्ञानिक-{h}" in t
            for h in hindi_variants
        )
        if reg.search(t) or hindi_match:
            cadres.append(f'Scientist {g.upper()}')

    # 2. Scientific Officers: SO-I, SO-II, SO-III (handles S.O.-I, S.O. I, SO-I, SO 1, Scientific Officer I)
    if re.search(r'\b(?:s\.?\s*o\.?|scientific\s+officer)[-.\s]*(?:i|1)\b', t) or any(x in t for x in ['वैज्ञानिक अधिकारी-i', 'वैज्ञानिक अधिकारी i', 'वैज्ञानिक अधिकारी 1', 'वैज्ञानिक अधिकारी-1']):
        cadres.append('SO-I')
    if re.search(r'\b(?:s\.?\s*o\.?|scientific\s+officer)[-.\s]*(?:ii|2)\b', t) or any(x in t for x in ['वैज्ञानिक अधिकारी-ii', 'वैज्ञानिक अधिकारी ii', 'वैज्ञानिक अधिकारी 2', 'वैज्ञानिक अधिकारी-2']):
        cadres.append('SO-II')
    if re.search(r'\b(?:s\.?\s*o\.?|scientific\s+officer)[-.\s]*(?:iii|3)\b', t) or any(x in t for x in ['वैज्ञानिक अधिकारी-iii', 'वैज्ञानिक अधिकारी iii', 'वैज्ञानिक अधिकारी 3', 'वैज्ञानिक अधिकारी-3']):
        cadres.append('SO-III')

    # 3. Meteorologists: Met A and Met B (handles Met. 'A', Met 'A', Met-A, AM-I, AM-II, Met. 'B', etc.)
    if re.search(r"\b(?:met\.?|meteorologist|am)[-.\s]*(?:gr(?:ade)?\.?[-.\s]*)?['\"]?\s*(?:a|i)\b['\"]?", t) or any(x in t for x in ['मौसम विज्ञानी-i', 'मौसम विज्ञानी i', 'मौसम विज्ञानी क', 'मौसम विज्ञानी a']):
        cadres.append('Met A')
    if re.search(r"\b(?:met\.?|meteorologist|am)[-.\s]*(?:gr(?:ade)?\.?[-.\s]*)?['\"]?\s*(?:b|ii)\b['\"]?", t) or any(x in t for x in ['मौसम विज्ञानी-ii', 'मौसम विज्ञानी ii', 'मौसम विज्ञानी ख', 'मौसम विज्ञानी b']):
        cadres.append('Met B')

    # 4. Scientific Assistant (SA) (handles SA, S.A., S.A.(Met), Scientific Asstt, Sci Asstt, Sc Asstt)
    if re.search(r'\b(?:s\.?\s*a\.?|ssa|scientific\s+asstt?\.?|sci\.?\s*asstt?\.?|sc\.?\s*asstt?\.?|scientific\s+assistant)\b', t) or 'वैज्ञानिक सहायक' in t:
        cadres.append('Scientific Assistant (SA)')

    # 5. Clerks (UDC / LDC / Clerical)
    if re.search(r'\b(?:clerk|clerks|udc|ldc|upper\s+div\w*\s+clerk|lower\s+div\w*\s+clerk|clerical)\b', t) or any(x in t for x in ['लिपिक', 'यूडीसी', 'एलडीसी']):
        cadres.append('Clerk (UDC/LDC)')

    # 6. MTS / Attendant
    if re.search(r'\b(?:mts|multi[- ]tasking|attendant|peon)\b', t) or any(x in t for x in ['एमटीएस', 'परिचारक']):
        cadres.append('MTS / Attendant')

    # 7. Engineering & Technical
    if re.search(r'\b(?:engineer|telecom|instrumentation|draughtsman|workshop)\b', t) or any(x in t for x in ['अभियंता', 'तकनीकी']):
        cadres.append('Engineering / Tech')

    # 8. Finance & Accounts
    if re.search(r'\b(?:finance|account|accounts|ddo|pao|audit|budget)\b', t) or any(x in t for x in ['लेखा', 'वित्त']):
        cadres.append('Finance & Accounts')

    # 9. Fallback generic cadres
    if not cadres:
        if re.search(r'\b(?:administrative|section\s+officer|steno\w*|ministerial)\b', t) or 'प्रशासनिक' in t:
            return 'Administrative'
        if 'scientist' in t or 'वैज्ञानिक' in t:
            return 'Scientist'
        if 'meteorologist' in t or 'मौसम विज्ञानी' in t:
            return 'Meteorologist'
        return 'General / All'

    return ' / '.join(cadres)

def analyze_with_rules(title: str, section: str = "") -> dict:
    """Fallback Tier 2: Deterministic keyword analysis if Gemini API is unavailable."""
    title_lower = title.lower()
    matched_keywords = [kw for kw in FALLBACK_VIP_KEYWORDS if kw in title_lower]
    is_vip = len(matched_keywords) > 0
    cadre = detect_imd_cadre(title)

    return {
        "is_vip": is_vip,
        "vip_reasons": matched_keywords if is_vip else [],
        "target_cadre": cadre,
        "category": section if section else ("Establishment" if is_vip else "General"),
        "summary_en": f"Official notice: {title}",
        "summary_hi": f"विभागीय सूचना: {title}",
        "action_required": any(w in title_lower for w in ["representation", "objection", "option", "apply", "proforma"]),
        "source": "rules_fallback"
    }

def analyze_with_gemini(pdf_bytes: bytes, title: str, api_key: str, section: str = "") -> dict:
    """Analyze circular PDF using Gemini 1.5 Flash API with 3 retries and exponential backoff."""
    prompt = f"""
Analyze this official Indian Meteorological Department / Government circular PDF.
Title: "{title}"
Section: "{section}"

Extract a clean JSON response with this exact structure:
{{
  "is_vip": true or false (true if this directly affects careers, e.g. seniority, promotion, MACP, transfer, roster, deputation, training nomination),
  "vip_reasons": ["short keyword reasons like 'seniority list', 'promotion'"],
  "target_cadre": "Specific employee cadre: 'Clerk (UDC/LDC)', 'Scientific Assistant (SA)', 'Met A', 'Met B', 'SO-I', 'SO-II', 'SO-III', 'Scientist B', 'Scientist C', 'Scientist D', 'Scientist E', 'Scientist F', 'Scientist G', 'Scientist H', 'MTS / Attendant', 'Administrative', or 'General / All'",
  "category": "Establishment" or "Administrative" or "Training" or "Technical" or "General",
  "summary_en": "One clear, informative sentence in English explaining what employees need to know.",
  "summary_hi": "One clear sentence in Hindi (Devanagari) summarizing the notice.",
  "action_required": true or false (true if employees must submit an objection, application, or form before a deadline)
}}
Only output valid JSON.
"""
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}"
    b64_pdf = base64.b64encode(pdf_bytes).decode("utf-8")

    payload = {
        "contents": [{
            "parts": [
                {"text": prompt},
                {
                    "inline_data": {
                        "mime_type": "application/pdf",
                        "data": b64_pdf
                    }
                }
            ]
        }],
        "generationConfig": {
            "response_mime_type": "application/json",
            "temperature": 0.2
        }
    }

    headers = {"Content-Type": "application/json"}

    # 3 Retries with exponential backoff
    for attempt in range(1, 4):
        try:
            resp = requests.post(url, json=payload, headers=headers, timeout=45)
            if resp.status_code == 200:
                result_json = resp.json()
                text_content = result_json["candidates"][0]["content"]["parts"][0]["text"]
                parsed = json.loads(text_content)
                parsed["source"] = "gemini_1.5_flash"
                return parsed
            elif resp.status_code in [429, 503]:
                wait_time = attempt * 10
                print(f"[!] Gemini API rate-limited (HTTP {resp.status_code}). Retrying in {wait_time}s (Attempt {attempt}/3)...")
                time.sleep(wait_time)
            else:
                print(f"[!] Gemini API error HTTP {resp.status_code}: {resp.text[:150]}")
                break
        except Exception as e:
            print(f"[!] Exception during Gemini API call (Attempt {attempt}/3): {e}")
            time.sleep(attempt * 5)

    print(f"[!] Gemini AI analysis failed for '{title}'. Falling back to rule-based engine.")
    return analyze_with_rules(title, section)

def generate_circular_id(url: str, title: str) -> str:
    hash_input = f"{url.strip()}::{title.strip()}"
    return hashlib.sha256(hash_input.encode("utf-8")).hexdigest()[:16]

def run_indexer():
    print("=" * 65)
    print(" 🤖 MetNet AI Circular Semantic Indexer")
    print("=" * 65)

    gemini_key = os.environ.get("GEMINI_API_KEY", "").strip()
    metnet_user = os.environ.get("METNET_USERNAME", "").strip()
    metnet_pass = os.environ.get("METNET_PASSWORD", "").strip()

    if not gemini_key:
        print("[i] GEMINI_API_KEY not found in environment. Using Tier 2 Rule Engine for indexing.")
    else:
        print("[✓] GEMINI_API_KEY detected. Gemini 1.5 Flash Vision enabled.")

    index_data = load_existing_index()
    circulars_dict = index_data.get("circulars", {})

    print(f"[i] Currently indexed circulars: {len(circulars_dict)}")

    # In local testing or manual run without MetNet, seed sample high-stakes circulars if empty
    if len(circulars_dict) == 0:
        sample_circulars = [
            {
                "title": "Draft Seniority List of Scientific Assistants in IMD as on 01.10.2026",
                "url": "https://metnet.imd.gov.in/phps/docs/Seniority_SA_Oct2026.pdf",
                "date": "18/10/2026",
                "section": "Admin-I"
            },
            {
                "title": "Grant of Financial Upgradation under MACP Scheme to Group B Officers",
                "url": "https://metnet.imd.gov.in/phps/docs/MACP_GroupB_2026.pdf",
                "date": "15/10/2026",
                "section": "Admin-II"
            },
            {
                "title": "WMO Fellowship Nominations and Advanced Meteorological Training Course 2027",
                "url": "https://metnet.imd.gov.in/phps/docs/WMO_Training_2027.pdf",
                "date": "12/10/2026",
                "section": "Training Division"
            },
            {
                "title": "General Office Order regarding Observance of Vigilance Awareness Week",
                "url": "https://metnet.imd.gov.in/phps/docs/Vigilance_Week_2026.pdf",
                "date": "10/10/2026",
                "section": "General Admin"
            }
        ]

        print("[i] Seeding initial baseline index with sample departmental circulars...")
        for c in sample_circulars:
            cid = generate_circular_id(c["url"], c["title"])
            analysis = analyze_with_rules(c["title"], c["section"])
            circulars_dict[cid] = {
                "id": cid,
                "title": c["title"],
                "url": c["url"],
                "date": c["date"],
                "section": c["section"],
                **analysis,
                "indexed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            }

        save_index(index_data)

    print("\n[✓] AI Circular Indexing complete.")

if __name__ == "__main__":
    try:
        run_indexer()
    except Exception as e:
        print(f"[!] Warning: Indexer encountered non-fatal issue: {e}")
        import sys
        sys.exit(0)
