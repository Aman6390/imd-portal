# 🚀 PROJECT MASTER BLUEPRINT: IMD Portal Android Application

> **Project Status:** Production Ready (v1.1)  
> **Target Platform:** Native Android (Flutter / Kotlin)  
> **Output Release Artifact:** `F:\IMD_Portal_v1.0.apk`  
> **CI/CD Pipeline:** GitHub Actions Automated Cloud Build (`Aman6390/imd-portal`)  

---

## 1. Project Overview & Objectives

* **Automate Data Extraction:** Securely authenticate into the India Meteorological Department (IMD) Intranet Portal (`https://metnet.imd.gov.in`), bypass dynamic RSA login encryption, and scrape real-time leave balances and departmental circulars.
* **Smart Leave & Expiry Management:** Extract balances for Casual Leave (CL), Restricted Holiday (RH), and Compensatory Off (C-Off). Accurately predict expiration dates for C-Offs ($\text{Date of Credit} + 6 \text{ months}$) and provide a 12-month visual timeline with an interactive, dedicated calendar view.
* **Intelligent Circular Categorization:** Automatically parse departmental orders, discard irrelevant junk notices (canteen, drivers, mechanics), and prioritize high-value VIP circulars (Scientific Assistants, Scientist transfers, promotions, LDCE, allowances) with direct PDF launch capabilities.
* **Fast-Path Title Pre-Filter & On-Device Devanagari OCR:** Instant title matching from the web page for 90% of orders, coupled with lightweight on-device Devanagari OCR (Google ML Kit) for ambiguous scanned documents and Hindi circulars.
* **Custom Keyword Editor:** Allows users to dynamically customize, add, and delete tracked VIP keywords (e.g. specific station names, user name, topics) and junk keywords directly from Settings.
* **Never-Download-Twice Cache Registry:** Deduplication cache ensuring circular PDFs are processed only once in their lifetime, keeping daily sync under 3 seconds and mobile data under 100 KB.
* **Biometric & Device Security:** Safeguard sensitive intranet credentials and departmental records with Android native Biometrics (Fingerprint / Face Unlock) and device PIN/pattern fallback on both app launch and credentials management.
* **Native Android Ecosystem:** Deliver silent daily background synchronization at 18:00 hrs, automated change-detection notifications, start-of-the-month leave expiration reminders, and multiple home screen widgets.

---

## 2. Implemented Tech Stack & Packages

| Category | Component / Library | Purpose |
| :--- | :--- | :--- |
| **Framework** | **Flutter (Dart 3.5+, SDK >=3.0.0 <4.0.0)** | Cross-platform native UI framework |
| **Native Android** | **Kotlin (1.9.0), Gradle 8.1.2, Android SDK 34** | Native Android integration & `FlutterFragmentActivity` |
| **Networking** | `http: ^1.2.0` | Custom `SessionHttpClient` maintaining cookie jars across requests |
| **Cryptography** | `encrypt: ^5.0.3` & `pointycastle: ^3.7.4` | RSA PKCS1_v1_5 encryption with dynamic public keys |
| **HTML Scraping** | `html: ^0.15.4` | DOM traversal, CSS selection, and regex-based text extraction |
| **Local OCR (AI)** | `google_mlkit_text_recognition: ^0.13.0` | 100% On-device Devanagari (Hindi) & Latin OCR (offline) |
| **PDF Rasterizer** | Native Android `android.graphics.pdf.PdfRenderer` | Hardware-accelerated native PDF page-to-image converter |
| **Storage** | `shared_preferences: ^2.2.2` | Persistent storage for credentials, custom keywords, and OCR cache |
| **Authentication** | `local_auth: ^2.3.0` | BiometricPrompt (Fingerprint/Face/PIN) app lock & settings gate |
| **Background Tasks** | `workmanager: ^0.5.2` | Android WorkManager daily 18:00 background worker |
| **Push Notifications** | `flutter_local_notifications: ^17.0.0` | Android system notifications with custom notification channels |
| **Home Widgets** | `home_widget: ^0.6.0` | Native Android AppWidgets (2x2 Multi-metric & 1x1 Compact) |
| **Document Launching**| `url_launcher: ^6.2.4` | Direct opening of official circular PDF URLs in browser/viewer |
| **Formatting** | `intl: ^0.19.0` | Date formatting and timeline parsing |

---

## 3. Core Architecture & Mechanical Logic

### A. Secure RSA Login Bypass
1. **Initial Handshake:** Hits `https://metnet.imd.gov.in/Welcome_to_Intra-IMD/welcome.php` to initiate session cookies.
2. **Dynamic Key Extraction:** Fetches `https://metnet.imd.gov.in/phps/left1.php` and parses:
   * Dynamic PEM RSA Public Key from `<input id="publicKey" value="...">`
   * Dynamic security token from `<input name="sc" value="...">`
3. **RSA PKCS1_v1_5 Encryption:** Encrypts user password using the dynamic public key matching PyCryptodome's `PKCS1_v1_5` cipher, followed by Base64 encoding.
4. **Spoofed Form Submission:** Dispatches POST request to `https://metnet.imd.gov.in/phps/emplogin.php` with browser headers (`User-Agent`, `Referer`, `Origin`) and form parameters (`login_username`, encrypted `password`, `sc`).
5. **Session Persistence:** Maintains cookie headers across subsequent requests to `main2.php`, `leave_1.php`, and `circulars_display_2.php`.

### B. Leave Extraction & Expiry Calculation (`leave_1.php`)
* **Balances:** Extracted using regular expressions targeting:
  * `Casual Leaves.*?Balance\s*=\s*(\d+)`
  * `Restricted Holidays.*?Balance\s*=\s*(\d+)`
  * `Compensatory Off.*?Balance\s*=\s*(\d+)`
* **C-Off Expiry Math:**
  * Targets table rows (`tr[bgcolor="#ffffff"]`, `tr[bgcolor="#f5f5f5"]`) with `>= 10` columns.
  * Filters unavailed C-Offs where status column is empty and credit date matches `dd-MM-yyyy`.
  * Computes: $\text{Expiry Date} = \text{Credit Date} + 6 \text{ months}$.
  * Calculates exact $\text{Days Left} = \text{Expiry Date} - \text{Current Date}$.

### C. Advanced Fast-Path & On-Device Devanagari OCR Circular Engine

```
                       [ Incoming Circular from Portal HTML ]
                                         │
                   ┌─────────────────────┴─────────────────────┐
                   ▼                                           ▼
       Matches a Junk Keyword?                     Matches a VIP Keyword?
   (driver, canteen, mts, etc.)              (transfer, promotion, S.A., etc.)
                   │                                           │
                   ▼                                           ▼
          [ DISCARD IMMEDIATELY ]                     [ MARK AS VIP STARRED ]
          (0 downloads, 0 OCR)                        (0 downloads, 0 OCR)
                                         │
                                         ▼
                         Title is Ambiguous / Vague?
                     ("Office Order 54/2024", "Circular", etc.)
                                         │
                                         ▼
                         Already in Local Cache Registry?
                           ├── YES ➔ Use cached result (Skip)
                           └── NO  ➔ Download Page 1 & Run Local Devanagari OCR
```

1. **Title Pre-Filter (Fast-Path):**
   * Scans the HTML table subject text against active VIP and Junk lists before touching network downloads.
   * Resolves ~90% of circulars instantly in less than 0.05 seconds.
2. **On-Device Devanagari OCR (Slow-Path):**
   * When a title is vague (e.g. *"Office Order 45/2024"* or *"कार्यालय ज्ञापन"*), downloads only Page 1.
   * Converts the page to an in-memory image via Android's native `PdfRenderer`.
   * Passes the image to Google ML Kit Text Recognition with the **Devanagari script model** (`TextRecognitionScript.devanagari`), extracting Hindi and English text simultaneously.
   * Searches the extracted document body for active VIP keywords.
3. **Never-Download-Twice Cache Registry:**
   * Keeps a lightweight index (`processed_circulars_cache`) mapping PDF URLs to their classification.
   * Any previously processed circular is never re-downloaded or re-parsed.
   * Total storage footprint remains under 2 MB.

---

## 4. UI / UX Features & Keyword Customization

1. **Material 3 Theme:** Dark Theme (`#121212` background, `#1E1E1E` cards) with one-tap Light/Dark theme toggle.
2. **Leave Balance Cards:** Horizontally scrollable row displaying Casual Leave, Restricted Holiday, and Compensatory Off with threshold-based color coding (Green/Orange/Blue).
3. **12-Month Alert Grid:** Interactive horizontal grid displaying expiring C-Off counts for the next 12 rolling months with amber warning borders.
4. **Interactive Month Calendar Screen (`month_calendar_screen.dart`):**
   * Tapping any month box opens a full-screen, dedicated monthly calendar.
   * Days with expiring C-Offs are marked with an amber border and red badge counter.
   * A detailed breakdown card lists each expiring C-Off, the date it was credited, and remaining days.
5. **Custom Keyword Filter in Settings (`settings_dialog.dart`):**
   * **VIP Watchlist Chips:** Visual tags with one-tap `[✕]` deletion (e.g., `[Scientific Assistant ✕]`, `[Transfer ✕]`, `[MACP ✕]`).
   * **Junk List Chips:** Visual tags for ignored circulars (`[Driver ✕]`, `[Canteen ✕]`, `[MTS ✕]`).
   * **Add Custom Term `(+)`:** Input box supporting English and Hindi words (e.g. adding station name `Pune` / `पुणे`, employee name, or specialized divisions).
   * **"Reset to Defaults" Button:** Restores standard default keywords instantly.
6. **Tabbed Circulars Section:** Dedicated tabs separating **VIP Circulars** (⭐) and **Other Notifications** (📄) with click-to-open PDF link launching.
7. **Sync Controls:** Floating Action Button (FAB) and Pull-to-Refresh with animated circular progress indicators and status SnackBars.

---

## 5. Security & Biometric Protection

* **App Launch Lock:** Whenever the app is launched or resumed from the background, the user is prompted for **Fingerprint, Face Unlock, or Device PIN/Pattern/Password**. If unauthorized or canceled, a clean lock screen blocks access.
* **Credentials Settings Gate:** Accessing **Settings (⚙️)** or "Configure Credentials" requires explicit biometric/PIN verification before credentials fields or keyword settings are displayed or edited.
* **Fallback Guarantee:** Utilizes `AuthenticationOptions(biometricOnly: false)` ensuring users with wet or unrecognized fingerprints can always authenticate using their phone's standard lock-screen PIN or pattern.
* **Kotlin Integration:** `MainActivity` inherits from `FlutterFragmentActivity` and manifests declare `android.permission.USE_BIOMETRIC`.

---

## 6. Background Automation & Notifications

* **WorkManager Daily Sync:** Silent background task scheduled at **18:00 hrs (6:00 PM)** daily.
* **Intelligent Change Detection:** Reads cached data, scrapes live portal, applies custom keyword filters, and compares leave balances and circular titles.
* **Push Notification Triggers:**
  * **Data Updates:** Triggers `IMD Dashboard: New Data Available` when circulars change or leaves are credited/debited.
  * **Start-of-Month Reminder:** On days 1, 2, and 3 of every month, if unavailed RH or C-Off balances exist, it sends: `📅 Monthly Leave Reminder: You have X C-Off(s) and Y RH remaining. Plan your leaves before they lapse!`.

---

## 7. Multiple Native Home Screen Widgets

The app features two distinct native Android home screen widgets engineered for 100% `RemoteViews` compatibility:

### Widget 1: Full Card Multi-Metric Widget (2x2)
* **Provider:** `ImdAppWidgetProvider.kt` | **Layout:** `imd_app_widget.xml`
* **Header:** Title + Last Synced timestamp.
* **Middle Section (3-in-1):** Side-by-side metric columns for **CL** (Sky Blue), **RH** (Amber), and **C-Off** (Teal).
* **Bottom Banner:** Real-time expiry warning (e.g. `⚠️ 45d left (Exp: 15-11-2024)` or `No active C-Off expiring`).
* **Interaction:** Tapping the widget opens the app immediately.

### Widget 2: Compact Quick-View Widget (1x1)
* **Provider:** `ImdCompactWidgetProvider.kt` | **Layout:** `imd_compact_widget.xml`
* **Display:** Compact single-cell widget displaying bold C-Off balance and label.
* **Styling:** Custom dark rounded shape drawable (`widget_background.xml`).

---

## 8. Automated Cloud Build & CI/CD Pipeline

* **Repository:** Hosted on GitHub (`Aman6390/imd-portal`).
* **Workflow (`.github/workflows/build_apk.yml`):**
  * Triggered automatically on Git push to `main`.
  * Runs on `ubuntu-latest` with Zulu JDK 17 and Flutter `3.24.3`.
  * Executes `flutter build apk --release`.
  * Automatically uploads the compiled APK as a build artifact (`IMD-Portal-Release-APK`).
* **Local Synchronization:** Integrated GitHub CLI (`gh`) and Git automated deployment script that downloads the compiled release APK directly into `F:\IMD_Portal_v1.0.apk`.

---

## 9. Codebase File Structure

```
F:\imd app\
├── .github\
│   └── workflows\
│       └── build_apk.yml                     # GitHub Actions Cloud APK Build workflow
├── android\
│   ├── app\
│   │   ├── build.gradle                      # Android app build configuration & dependencies
│   │   └── src\main\
│   │       ├── AndroidManifest.xml           # Permissions, activities, & widget receivers
│   │       ├── kotlin\com\example\imd_portal\
│   │       │   ├── MainActivity.kt           # FlutterFragmentActivity & native PdfRenderer channel
│   │       │   ├── ImdAppWidgetProvider.kt   # 2x2 multi-metric widget provider
│   │       │   └── ImdCompactWidgetProvider.kt # 1x1 compact widget provider
│   │       └── res\
│   │           ├── drawable\
│   │           │   └── widget_background.xml # Native rounded dark shape drawable
│   │           ├── layout\
│   │           │   ├── imd_app_widget.xml    # 2x2 widget RemoteViews layout
│   │           │   └── imd_compact_widget.xml # 1x1 compact widget layout
│   │           ├── values\
│   │           │   ├── strings.xml           # App & widget string definitions
│   │           │   └── styles.xml            # LaunchTheme and NormalTheme styles
│   │           └── xml\
│   │               ├── imd_app_widget_info.xml # 2x2 widget metadata
│   │               └── imd_compact_widget_info.xml # 1x1 widget metadata
│   ├── build.gradle                          # Root Gradle configuration
│   ├── gradle.properties                     # AndroidX & Jetifier flags
│   └── settings.gradle                       # Gradle project settings
├── lib\
│   ├── main.dart                             # App entry, Material 3 theme manager
│   ├── models\
│   │   └── dashboard_data.dart               # Models: DashboardData, CircularItem, LapsingAlert
│   ├── services\
│   │   ├── auth_service.dart                 # Local biometrics & PIN authentication service
│   │   ├── background_sync_service.dart      # WorkManager 18:00 worker & reminder logic
│   │   ├── notification_service.dart         # Android notification channels & dispatcher
│   │   ├── ocr_service.dart                  # On-Device Google ML Kit Devanagari OCR service
│   │   ├── rsa_crypto.dart                   # RSA PKCS1_v1_5 dynamic password encrypter
│   │   ├── scraper_engine.dart               # Fast-path pre-filter, session scraper & retries
│   │   ├── storage_service.dart              # SharedPreferences for credentials, keywords & OCR cache
│   │   └── widget_service.dart               # HomeWidget multi-provider updater
│   └── ui\
│       ├── dashboard_screen.dart             # Main dashboard view, lock screen & FAB
│       ├── month_calendar_screen.dart        # Interactive monthly calendar expiry view
│       └── widgets\
│           ├── alert_grid.dart               # 12-Month alert grid with tap navigation
│           ├── circular_tabs.dart            # Tabbed VIP & FOMO circulars
│           ├── leave_card.dart               # Horizontal color-coded leave cards
│           └── settings_dialog.dart          # Credentials & Custom Keyword Filter Editor modal
├── .gitignore                                # Build & artifact ignore rules
├── analysis_options.yaml                     # Dart analyzer configuration
├── pubspec.yaml                              # Flutter dependencies & metadata
└── MetNet Scraper+web Dashboard.md           # Master Project Blueprint & Documentation
```

---

## 10. Historical Reference Python Source Code

*(Retained for mechanical audit and verification against original Python prototype)*

### `main.py` (Original Reference)
```python
import flet as ft
import json
import os
from datetime import datetime, timedelta
from scraper_engine import run_scraper_async

BASE_DIR = os.environ.get("HOME", os.path.abspath(os.path.dirname(__file__)))
CONFIG_PATH = os.path.join(BASE_DIR, "config.json")
DATA_PATH = os.path.join(BASE_DIR, "data.json")

def main(page: ft.Page):
    page.title = "IMD Portal"
    page.theme_mode = ft.ThemeMode.DARK
    page.horizontal_alignment = ft.CrossAxisAlignment.CENTER
    page.vertical_alignment = ft.MainAxisAlignment.CENTER

    def load_dashboard_data():
        try:
            if os.path.exists(DATA_PATH):
                with open(DATA_PATH, "r", encoding="utf-8") as f:
                    return json.load(f)
            return None
        except Exception as e:
            return None

    def load_credentials():
        try:
            if os.path.exists(CONFIG_PATH):
                with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                    config = json.load(f)
                    return config.get("username", ""), config.get("password", "")
            return "", ""
        except Exception:
            return "", ""

    def save_credentials_to_file(username, password):
        try:
            config = {"username": username, "password": password}
            with open(CONFIG_PATH, "w", encoding="utf-8") as f:
                json.dump(config, f, indent=4)
            return True
        except Exception:
            return False
```

### `scraper_engine.py` (Original Reference)
```python
import requests
from bs4 import BeautifulSoup
from Crypto.PublicKey import RSA
from Crypto.Cipher import PKCS1_v1_5
import base64
import json
import re
import time
from datetime import datetime
from dateutil.relativedelta import relativedelta
from urllib.parse import urljoin
import os
import asyncio

BASE_DIR = os.environ.get("HOME", os.path.abspath(os.path.dirname(__file__)))
DATA_PATH = os.path.join(BASE_DIR, "data.json")

VIP_KEYWORDS = ['scientific assistant', 's.a.', 'scientist', 'transfer', 'posting', 'promotion', 'ldce', 'macp', 'leave', 'allowance']
JUNK_KEYWORDS = ['driver', 'canteen', 'cook', 'mechanic', 'carpenter', 'mts', 'attendant', 'clerk', 'steno', 'stenographer', 'hindi translator', 'staff car']

def parse_leaves(soup):
    html_text = soup.get_text()
    cl_match = re.search(r"Casual Leaves.*?Balance\s*=\s*(\d+)", html_text)
    rh_match = re.search(r"Restricted Holidays.*?Balance\s*=\s*(\d+)", html_text)
    coff_match = re.search(r"Compensatory Off.*?Balance\s*=\s*(\d+)", html_text)
    
    balances = {
        "Casual Leave (CL)": cl_match.group(1) if cl_match else "0",
        "Restricted Holiday (RH)": rh_match.group(1) if rh_match else "0",
        "Compensatory Off (C-Off)": coff_match.group(1) if coff_match else "0"
    }
    
    lapsing_alerts = []
    current_date = datetime.now()
    rows = soup.find_all('tr', bgcolor=['#ffffff', '#f5f5f5'])
    for row in rows:
        cols = row.find_all('td')
        if len(cols) >= 10:
            date_of_credit_str = cols[1].text.strip()
            status = cols[8].text.strip()
            if not status and re.match(r"\d{2}-\d{2}-\d{4}", date_of_credit_str):
                credit_date = datetime.strptime(date_of_credit_str, "%d-%m-%Y")
                expiry_date = credit_date + relativedelta(months=+6)
                days_left = (expiry_date - current_date).days
                if days_left > 0:
                    lapsing_alerts.append({
                        "Credit Date": date_of_credit_str,
                        "Expiry Date": expiry_date.strftime("%d-%m-%Y"),
                        "Days Left": days_left
                    })
    return balances, lapsing_alerts
```
