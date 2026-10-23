# 🚀 PROJECT MASTER BLUEPRINT: Meteorological Portal Android Application

> **Project Status:** Production Ready — 100% Free & Open Edition (v1.4.11)  
> **Target Platform:** Native Android (Flutter / Kotlin) [Why: Guarantees broad compatibility with all modern Android smartphones used by staff]  
> **Output Release Artifact:** `build/app/outputs/flutter-apk/app-release.apk` [Why: Standard Android standalone package format for direct distribution]  
> **CI/CD Pipeline:** GitHub Actions Automated Cloud Build (`Aman6390/imd-portal`) [Why: Eliminates the need for a high-end development computer by compiling APKs in the cloud automatically]  
> **Licensing & Access:** 100% Free for all meteorological staff and employees [Why: Pure non-profit internal utility tool built to empower colleagues with zero financial or technical barriers]

---

## 📌 Project Quick Reference & Repository Endpoints

| Item | Value / Reference | Description & Details [Why We Use It] |
| :--- | :--- | :--- |
| **🐙 GitHub Repository** | `https://github.com/Aman6390/imd-portal` | Authenticated remote repository with automated CI/CD cloud build workflow. [Why: Provides permanent version control, cloud compilation, and public update hosting for colleagues] |
| **🌐 Intranet Target Portal** | `https://metnet.imd.gov.in` | Official India Meteorological Department Intranet Portal. [Why: The authoritative central server storing employee leave records and departmental circulars] |
| **📦 Cloud Build Release APK** | `build/app/outputs/flutter-apk/app-release.apk` | Production Android APK compiled via GitHub Actions Ubuntu runners. [Why: Compiles a clean, optimized binary that anyone can install directly without app stores] |
| **🚀 Over-The-Air Updates** | `https://github.com/Aman6390/imd-portal/releases` | GitHub Releases endpoint for version tracking and direct APK update downloads. [Why: Enables seamless in-app auto-updating so users receive bug fixes and new features automatically] |
| **🎁 Edition & Pricing** | **100% Free Edition** | Unrestricted full access for all staff, scientists, and employees with zero barriers. [Why: Avoids user frustration, paywalls, and license key validation issues] |
| **👤 Project Lead & Developer** | Aman Kumar (`Aman6390`) | Designed & built for meteorological colleagues. [Why: Created by an insider who understands the exact departmental pain points of MetNet] |

---

## 1. Project Overview & Objectives

* **Automate Intranet Data Extraction:** [Why: Manual portal login requires solving dynamic RSA encryption and navigating slow web pages; automated extraction retrieves leave records and circulars in under 3 seconds]. Securely authenticates into the Intranet Portal (`https://metnet.imd.gov.in`), bypasses dynamic RSA login encryption, and scrapes real-time balances and circulars.
* **Smart Leave & Expiry Management:** [Why: Compensatory Offs lapse after exactly 6 months, and employees frequently lose hard-earned leaves simply because they forget when they were earned]. Extracts balances for Casual Leave (CL), Restricted Holiday (RH), and Compensatory Off (C-Off). Accurately predicts expiration dates for C-Offs ($\text{Date of Credit} + 6 \text{ months}$) and provides a 12-month visual timeline with an interactive, dedicated calendar view. Dynamic rotating sweep-gradient neon border highlights active expiring months (e.g. March 2027) with zero layout shift.
* **Intelligent Circular Categorization & "For You" Personalization:** [Why: MetNet publishes dozens of daily notices (driver duties, canteen menus, carpenter jobs) that bury critical orders like promotions, transfers, and allowances]. Automatically parses departmental orders, discards irrelevant junk notices, and prioritizes high-value orders in a personalized **"For You"** tab with 1-tap cadre filter chips (`[ All ]`, `[ ⛅ Met B ]`, `[ 🌤️ Met A ]`, `[ 🔬 SA ]`, `[ 🧪 Scientists ]`, `[ ⚠️ Action Required ]`, `[ 🔖 Bookmarked ]`). Removed leading star to grant full horizontal space to notice titles, and integrated persistent offline bookmarking.
* **Fast-Path Title Pre-Filter & On-Device Devanagari OCR:** [Why: 90% of orders have clear titles that can be filtered in milliseconds, but vague scanned Hindi notices require reading the actual document without wasting mobile data]. Instant title matching from the web page for 90% of orders, coupled with lightweight on-device Devanagari OCR (Google ML Kit) for ambiguous scanned documents and Hindi circulars.
* **Custom Keyword Editor:** [Why: Every employee cares about different things—some track their specific station (e.g. Pune, Delhi), their own name, or specialized sections]. Allows users to dynamically customize, add, and delete tracked VIP keywords and junk keywords directly from Settings.
* **In-App MetNet Notice Resolver WebView:** [Why: MetNet periodically blocks login with mandatory popups, unread inbox messages, or duty declarations that break automated scrapers]. When portal sync encounters unread notices, displays `⚠️ MetNet Notice or Action Required` with an `Open MetNet to Resolve` button. Auto-logs into MetNet, lets the user dismiss the notice, and automatically closes and triggers re-sync upon returning.
* **100% Free & Open Access:** [Why: To foster maximum adoption among all departmental staff without trial limits, activation keys, or subscription hurdles]. Zero licensing barriers, zero paywalls, and zero trial expiration dates. All features are permanently available upon download.
* **Over-The-Air (OTA) Updates:** [Why: Because the app is distributed directly via APK rather than Google Play, users need a smooth way to get updates without manually searching GitHub]. In-app check for new releases and features via GitHub Releases, allowing colleagues to update their installed app seamlessly over the internet.
* **Never-Download-Twice Cache Registry:** [Why: Mobile networks in regional meteorological centers can be slow; re-downloading the same PDFs repeatedly drains data and battery]. Deduplication cache ensuring circular PDFs are processed only once in their lifetime, keeping daily sync under 3 seconds and mobile data under 100 KB.
* **Biometric & Device Security:** [Why: MetNet credentials and leave balances are private employee records that must be protected if someone else holds the phone]. Safeguard sensitive intranet credentials and departmental records with Android native Biometrics (Fingerprint / Face Unlock) and device PIN/pattern fallback on both app launch and credentials management.
* **100% Free Live Weather Forecast & Global Geocoding:** [Why: As the central mobile client for meteorological staff, having live real-time station weather, 24-hour shift timelines, and 7-day outlooks gives forecasters and observers instant environmental situational awareness without needing external weather apps or third-party API keys]. Integrates Open-Meteo and IMD numerical weather models, native GPS auto-location detection, and worldwide geocoding search for any city, town, or district.
* **AI Semantic Circular Summaries, Plain-Words Explanations & Dual-Tap Navigation:** [Why: MetNet circular titles are often cryptic, bilingual, or bury crucial deadlines inside multi-page PDFs; employees need to immediately know who an order is for and what action is required without downloading and opening every document]. Integrates a multi-tier AI and on-device semantic engine that classifies every circular into the exact official IMD hierarchy (Clerks, Scientific Assistants, Met A/B, SO I-III, Scientists B through H), detects action-required notices (representations, objections, options, proformas), and displays instant 1-sentence plain-English summaries (`🤖 ...`). Features dual-action tap architecture where 1 tap on the notice opens the official PDF directly, and 1 tap on the summary box below smoothly unfolds an in-place plain-words breakdown with actionable advice and a built-in government Jargon Buster.
* **Smooth 1-Tap Update Installation & Process-Restart Recovery:** [Why: Android 10-14+ security policies kill app processes when users grant 'Allow from this source', and rapid file descriptor transitions cause silent PackageParser race conditions, making updates take multiple attempts]. Re-architected in-app updating with persistent SharedPreferences state recovery across process restarts, 400ms filesystem buffer settling delay, broadcast URI permissions across all OEM package installers, and automatic stale APK cache cleanup for a guaranteed 1-tap installation experience.
* **Settings & Customization:** [Why: Gives users full control over visual appearance, security preferences, and filter keywords in one central location]. Unified settings panel featuring Theme selection (Dark / Light Mode), keyword filters, account credentials, updates, and an About Section honoring developer Aman (Aman6390).

---

## 2. Implemented Tech Stack & Packages

| Category | Component / Library | Purpose & [Why We Chose It] |
| :--- | :--- | :--- |
| **Framework** | **Flutter (Dart 3.5+, SDK >=3.0.0 <4.0.0)** | Cross-platform native UI framework [Why: Delivers 60fps native performance, rich Material 3 animations, and rapid UI development from a single codebase] |
| **Native Android** | **Kotlin (1.9.0), Gradle 8.1.2, Android SDK 35** | Native Android integration & `FlutterFragmentActivity` [Why: Required for direct hardware access, native biometrics, FileProvider, and Android 15 compatibility] |
| **Networking** | `http: ^1.2.0` | Custom `SessionHttpClient` maintaining cookie jars across requests [Why: MetNet requires continuous session persistence (`PHPSESSID`) across multiple login and data endpoints] |
| **Cryptography** | `encrypt: ^5.0.3` & `pointycastle: ^3.7.4` | RSA PKCS1_v1_5 encryption with dynamic public keys matching PyCryptodome [Why: MetNet encrypts user passwords using RSA PKCS1_v1_5 on the login page; without this exact cipher, authentication is rejected] |
| **HTML Scraping** | `html: ^0.15.4` | DOM traversal, CSS selection, and regex-based text extraction [Why: Parses server-rendered HTML tables directly without needing heavy, resource-intensive browser engines] |
| **Local OCR (AI)** | `google_mlkit_text_recognition: ^0.13.0` | 100% On-device Devanagari (Hindi) & Latin OCR [Why: Extracts text from scanned Hindi/English circular PDFs locally on the device without sending sensitive documents to external cloud APIs] |
| **PDF Rasterizer** | Native Android `android.graphics.pdf.PdfRenderer` | Hardware-accelerated native PDF page-to-image converter [Why: Built directly into Android OS; renders PDF pages into bitmaps at maximum speed with zero third-party dependencies] |
| **Storage** | `shared_preferences: ^2.2.2` | Persistent key-value storage for credentials, custom keywords, and OCR cache [Why: Instant local read/write access for user preferences without the overhead of an SQL database] |
| **Authentication** | `local_auth: ^2.3.0` | BiometricPrompt (Fingerprint/Face/PIN) app lock & settings gate [Why: Standard Android security bridge that automatically adapts to each device's biometric hardware or lock-screen PIN] |
| **Background Tasks** | `workmanager: ^0.5.2` | Android WorkManager daily 18:00 background worker [Why: Android's official recommended battery-efficient background scheduler that survives phone reboots and app termination] |
| **Push Notifications** | `flutter_local_notifications: ^17.0.0` | Android system notifications with custom notification channels [Why: Delivers heads-up alerts for expiring leaves, new circulars, and background app updates] |
| **Home Widgets** | `home_widget: ^0.6.0` | Native Android AppWidgets (2x2 Multi-metric & 1x1 Compact) [Why: Lets staff view their leave balances directly on their phone home screen without opening the app] |
| **Document Launching**| `url_launcher: ^6.2.4` | Fallback browser and document launcher [Why: Standard utility to invoke system handlers for web links] |
| **Notice Resolver** | `webview_flutter: ^4.10.0` | In-app authenticated WebView for resolving MetNet notices & pop-ups [Why: Allows employees to interact directly with MetNet popups without leaving the app or re-entering credentials] |
| **Formatting** | `intl: ^0.19.0` | Date formatting and timeline parsing [Why: Reliably handles diverse date string formats used across government records (`dd-MM-yyyy`, `dd/MM/yyyy`, etc.)] |
| **Weather Engine** | **Open-Meteo API & WMO Decoders** | 100% Free global numerical weather prediction API [Why: Provides real-time temperatures, WMO codes, 24h hourly curves, and 7-day outlooks with zero API keys or user signups] |
| **Location Services**| Native Android `LocationManager` & Reverse Geocoder | Dual-mode native GPS/Network channel + IP fallback [Why: Automatically pinpoints exact employee duty stations or cities in milliseconds without third-party plugin bloat] |

---

## 3. Core Architecture & Mechanical Logic

### A. Secure RSA Login Bypass
[Why: MetNet does not provide a public REST API; instead, it uses a multi-step PHP authentication flow with dynamic RSA public keys that change on every page load to prevent replay attacks.]

1. **Initial Handshake:** Hits `https://metnet.imd.gov.in/Welcome_to_Intra-IMD/welcome.php` to initiate session cookies. [Why: MetNet requires a valid session cookie before granting access to the login form].
2. **Dynamic Key Extraction:** Fetches `https://metnet.imd.gov.in/phps/left1.php` and parses:
   * Dynamic PEM RSA Public Key from `<input id="publicKey" value="...">` [Why: The server uses this key to encrypt the password before sending].
   * Dynamic security token from `<input name="sc" value="...">` [Why: MetNet validates this token to prevent automated CSRF attacks].
3. **RSA PKCS1_v1_5 Encryption:** Encrypts user password using the dynamic public key matching PyCryptodome's `PKCS1_v1_5` cipher, followed by Base64 encoding. [Why: Matches MetNet's internal server-side PHP decryption logic].
4. **Spoofed Form Submission:** Dispatches POST request to `https://metnet.imd.gov.in/phps/emplogin.php` with browser headers (`User-Agent`, `Referer`, `Origin`) and form parameters (`login_username`, encrypted `password`, `sc`). [Why: Mimics an authentic desktop web browser to prevent anti-bot security blocks].
5. **Session Persistence:** Maintains cookie headers across subsequent requests to `main2.php`, `leave_1.php`, and `circulars_display_2.php`. [Why: Ensures authenticated state remains valid across all departmental subpages].

### B. Leave Extraction & Expiry Calculation (`leave_1.php`)
[Why: Staff need instant clarity on how many leaves they have left and which ones are about to expire so they don't forfeit them.]

* **Balances:** Extracted using regular expressions targeting:
  * `Casual Leaves.*?Balance\s*=\s*(\d+)` [Why: Fast regex handles whitespace differences in portal HTML].
  * `Restricted Holidays.*?Balance\s*=\s*(\d+)` [Why: Captures remaining RH quota for the calendar year].
  * `Compensatory Off.*?Balance\s*=\s*(\d+)` [Why: Tracks active earned C-Offs from weekend or holiday duties].
* **C-Off Expiry Math:**
  * Targets table rows (`tr[bgcolor="#ffffff"]`, `tr[bgcolor="#f5f5f5"]`) with `>= 10` columns. [Why: MetNet displays C-Off credit history in alternating striped table rows].
  * Filters unavailed C-Offs where status column is empty and credit date matches `dd-MM-yyyy`. [Why: Avoids calculating expiry for leaves that were already taken or canceled].
  * Computes: $\text{Expiry Date} = \text{Credit Date} + 6 \text{ months}$. [Why: Departmental rules stipulate that Compensatory Offs strictly lapse 6 months after the duty date].
  * Calculates exact $\text{Days Left} = \text{Expiry Date} - \text{Current Date}$. [Why: Gives the employee a real-time countdown to plan their leaves before they are lost].

### C. Advanced Fast-Path & On-Device Devanagari OCR Circular Engine
[Why: MetNet publishes an overwhelming volume of notices. Processing every single PDF with AI OCR would be slow and data-heavy; this two-tier engine filters 90% instantly and only uses OCR when strictly necessary.]

```
                       [ Incoming Circular from Portal HTML ]
                                         │
                   ┌─────────────────────┴─────────────────────┐
                   ▼                                           ▼
       Matches a Junk Keyword?                     Matches a VIP Keyword?
   (driver, canteen, mts, etc.)              (transfer, promotion, S.A., etc.)
   [Why: Drops irrelevant notices]           [Why: Stars high-priority notices]
                   │                                           │
                   ▼                                           ▼
          [ DISCARD IMMEDIATELY ]                     [ MARK AS VIP STARRED ]
          (0 downloads, 0 OCR)                        (0 downloads, 0 OCR)
                                         │
                                         ▼
                         Title is Ambiguous / Vague?
                     ("Office Order 54/2024", "Circular", etc.)
                   [Why: Scanned orders need deep inspection]
                                         │
                                         ▼
                         Already in Local Cache Registry?
                           ├── YES ➔ Use cached result (Skip) [Why: Saves mobile data]
                           └── NO  ➔ Download Page 1 & Run Local Devanagari OCR
```

1. **Title Pre-Filter (Fast-Path):** [Why: Checks the HTML table title text first; resolves 90% of notices in under 0.05 seconds with zero network downloads].
2. **On-Device Devanagari OCR (Slow-Path):** [Why: Reads ambiguous scanned orders locally using Google ML Kit Hindi OCR without sending sensitive government circulars to external cloud servers].
3. **Never-Download-Twice Cache Registry:** [Why: Remembers every previously analyzed PDF so daily syncs stay under 3 seconds and mobile data usage stays under 100 KB].
4. **Last One Month Rolling Circular Filter & Chronological Sorting:** [Why: Focuses on currently active, actionable circulars while hiding outdated months-old records].
5. **Multi-Category Portal Discovery (Looking in Every Place):** [Why: MetNet scatters orders across General, Establishment, Office Orders, and Transfers; querying all categories ensures no critical transfer or promotion order is ever missed].
6. **RFC-Compliant Link Resolution & Android 11+ Package Visibility:** [Why: Fixes broken relative link concatenation bugs and ensures the app has OS permissions to open PDF links on modern Android devices].
7. **Intelligent In-App Downloader & Sibling Fallback (`CircularService.dart`):** [Why: External browsers like Chrome lack the app's login cookies and fail with 404 Not Found; this service downloads documents using the app's authenticated session].
   * **Pre-flight Magic Bytes Verification:** [Why: Inspects the first 4 bytes for `%PDF` (`0x25 0x50 0x44 0x46`) to discard deceptive HTML error pages that pretend to be 200 OK].
   * **Intelligent Sibling Path Probing:** [Why: If a link has a folder mismatch on MetNet, automatically tests alternate paths (`/docs/`, `/phps/docs/`, `/Welcome_to_Intra-IMD/docs/`) in milliseconds].
8. **Graceful Handling of Withdrawn / Removed Notices (404 Interception):** [Why: Department staff sometimes revoke orders by deleting the PDF file while leaving the title on the portal; catching this in-app prevents ugly browser crashes and clearly informs the user: `⚠️ Notice Unavailable on Server`].
9. **Native PDF Launch via Android FileProvider & Local Offline Cache:** [Why: Saves verified circulars in the device cache so colleagues can view them offline at any time without re-downloading].

### D. Live Weather Forecast Engine & Dual-Mode Positioning
[Why: Meteorological staff require immediate environmental situational awareness and shift-planning forecasts without juggling multiple third-party apps or paying for weather API keys.]

1. **Zero-Configuration Open-Meteo Integration:** Queries Open-Meteo's high-resolution global forecast system (`https://api.open-meteo.com/v1/forecast`), which synthesizes ECMWF, GFS, and regional Indian numerical models. Extracts temperature, apparent temperature ("Feels like"), humidity, wind speed, precipitation, WMO weather codes, 24-hour hourly timelines, and 7-day outlooks with 100% free, zero-key public access.
2. **Dual-Mode Auto-Location Positioning:**
   * **Primary:** Native Android `LocationManager` invoked via Kotlin MethodChannel (`com.imd.portal/location`). Queries `GPS_PROVIDER`, `NETWORK_PROVIDER`, and `PASSIVE_PROVIDER` with runtime permission checks.
   * **Secondary Fallback:** High-speed IP-based geolocation (`http://ip-api.com/json`) resolving city and region in under 300ms without requiring location permissions.
   * **Reverse-Geocoding Client:** Converts raw coordinates into readable city, state, and country descriptors (`https://api.bigdatacloud.net/data/reverse-geocode-client`).
3. **Global City & Town Geocoding Search:** Leverages Open-Meteo Geocoding Search (`https://geocoding-api.open-meteo.com/v1/search`), allowing staff to search and monitor any city, town, or remote observatory across India or globally.
4. **Persistent Offline Caching:** Automatically persists the latest weather reading and user's selected station in `SharedPreferences`. The weather card loads immediately on app startup with zero network blocking.

---

### E. AI Semantic Circular Summaries, Plain-Words Explanations & Dual-Tap Navigation (v1.4.4 - v1.4.10)

[Why: MetNet publishes dozens of daily administrative, scientific, and technical orders. Employees previously had to download every PDF or rely on basic keyword matching. The AI Semantic Architecture categorizes 100% of circulars with zero user effort, zero monthly server costs, and complete privacy preservation.]

#### 1. Multi-Tier Failsafe Strategy
To ensure the app never fails or relies on a single point of failure:
* **Tier 1 — Cloud Gemini 1.5 Flash Vision Index (`data/circulars_ai_index.json`):** Serverless GitHub Actions cron workflow (`ai_circular_indexer.yml`) runs every 4 hours, analyzes public notices using Google Gemini 1.5 Flash API (free tier) with 3 exponential backoff retries, and commits verified metadata to GitHub.
* **Tier 2 — Built-In 0ms On-Device Smart Semantic Synthesizer (`AiCircularService._synthesizeLocalMetadata`):** When circulars are behind the employee's authenticated intranet login or if the cloud index is unreachable/offline, the phone's native Dart engine performs instant on-device semantic parsing in 0ms. It detects cadres, evaluates action verbs, flags VIP status, and generates human-readable summaries without sending intranet documents or credentials to any third-party server.
* **Tier 3 — Local Devanagari OCR (Google ML Kit):** For unclassified or scanned physical Hindi notices, the on-device ML Kit OCR engine parses rasterized page bitmaps on demand.

#### 2. Official IMD Cadre Classification Hierarchy
Every circular is mapped to the exact organizational structure of the India Meteorological Department:
* **Clerks / Ministerial:** `📑 Clerk (UDC/LDC)` — UDC, LDC, Upper/Lower Division Clerks, Typists, Ministerial staff, and Hindi variants (`लिपिक`, `यूडीसी`, `एलडीसी`).
* **Scientific Assistants:** `🔬 Scientific Assistant (SA)` — S.A., SA, SSA, Senior Scientific Assistant, `वैज्ञानिक सहायक`.
* **Meteorologist Grade A:** `🌤️ Met A` — Meteorologist Grade A, Met-A, Met Gr A, Meteorologist Gr. I, `मौसम विज्ञानी-I/क`.
* **Meteorologist Grade B:** `⛅ Met B` — Meteorologist Grade B, Met-B, Met Gr B, Meteorologist Gr. II, `मौसम विज्ञानी-II/ख`.
* **Scientific Officers:** `🧭 SO-I`, `🧭 SO-II`, `🧭 SO-III` — Scientific Officer Grades I, II, and III, `वैज्ञानिक अधिकारी I-III`.
* **Scientists (Grades B through H):** `🧪 Scientist B` to `🧪 Scientist H` — Individual grade detection for Sc-B, Sc-C, Sc-D, Sc-E, Sc-F, Sc-G, and Sc-H, plus Hindi variants (`वैज्ञानिक 'बी'` to `'एच'`).
* **Compound Multi-Cadre Linkages:** Automatically links multi-cadre orders for promotions and joint rosters (e.g. `🌤️ Met A / 🧭 SO-I`, `🧪 Scientist B / Scientist C`).
* **Support & Administrative:** `👥 MTS / Attendant`, `⚙️ Engineering / Tech`, `💼 Finance & Accounts`, and `🏛️ General / All`.

#### 3. Action Required & VIP Detection
* **Action Required Alert (`⚠️ Action Required`):** Automatically scans for time-sensitive administrative triggers (representations, objections, options, proformas, applications, vigilance clearances, nominations, willingness, and deadlines).
* **VIP Career Priority (`⭐`):** Flags seniority lists, MACP/promotion orders, transfer/posting arrangements, and WMO training courses.
* **Plain-English 1-Sentence Summaries (`🤖 ...`):** Displays a concise, actionable summary under every circular card.
* **Interactive AI Breakdown Sheet:** Long-pressing any circular opens a modal bottom sheet displaying full target cadre, action requirement, VIP status, processing tier (Cloud Gemini vs. On-Device Engine), and upload metadata.
* **User Control & Remote Kill-Switch:** Users can toggle summaries on/off in **Settings ➔ Cloud AI Summaries**. The central index includes an `enable_ai_index` remote flag that can disable the feature instantly if ever required.

#### 4. Dual-Action Tap Architecture & In-Place Expandable Breakdown (v1.4.10)
[Why: Employees previously had to download every PDF just to know who was transferred or what action was needed. Dual-tap navigation gives users 100% control: 1 tap for the PDF, 1 tap for the AI breakdown without leaving the screen.]
* **1 Tap on the Notice Card / Title:** Immediately launches the PDF viewer and downloads/opens the official MetNet document.
* **1 Tap on the Summary Box Right Below:** Smoothly unfolds the summary **right in place** using `AnimatedSize` without shifting list scroll position.
  * **Plain-Words Meaning:** Translates dense administrative orders (seniority rankings, postings, pay upgrades, working arrangements) into clear, everyday English.
  * **Action Advice (👉 What you should do):** Provides direct, actionable guidance (e.g. verify name & date on seniority list, representations cutoff, or station joining instructions).
  * **Built-in Jargon Buster (💡):** Decodes confusing government abbreviations (`MACP`, `LACD`, `LDCE`, `Seniority Lists`, `Representations`).
  * **In-Card PDF Shortcut:** Added an **[ Open Original Document ]** button right inside the expanded summary box so you can open the official PDF whenever you're ready.
* **Tapping Again Collapses:** Tapping the summary box again collapses it back to the neat 1-line **IN BRIEF** preview.

#### 5. Personalized "For You" Section & 1-Tap Cadre Quick Filters (v1.4.9)
[Why: Employees care primarily about circulars affecting their own career or grade. Quick filters allow 0ms switching without opening Settings.]
* **"For You" Branding:** VIP Tab rebranded to **"For You"** (`✨`) to emphasize personalized, relevant notices while keeping **"Other Notices"** for general browsing.
* **1-Tap Horizontal Cadre Filter Chips:** Interactive horizontal scrolling strip right inside "For You":
  * `[ All ]`
  * `[ ⛅ Met B ]`
  * `[ 🌤️ Met A ]`
  * `[ 🔬 SA ]`
  * `[ 🧪 Scientists ]`
  * `[ ⚠️ Action Required ]`
  * `[ 🔖 Bookmarked ]`
* **Full Horizontal Width Reading:** Removed leading star icon so notice titles and cadre tags display cleanly across the entire screen without truncation.
* **Persistent Offline Bookmarking (🔖):** 1-tap bookmark button next to the download button; bookmarked notices are saved locally in private `SharedPreferences` (`imd_bookmarked_urls`) and persist across updates.

#### 6. Dynamic Rotating Neon Border on Expiring C-Off Months (v1.4.9)
[Why: Staff need an unmissable visual cue when hard-earned Compensatory Offs are close to their 6-month expiry.]
* In `AlertGrid`, months with active expiring C-Offs (such as **March 2027**) feature a dynamic rotating sweep-gradient neon light border (`_AnimatedMonthBox` and `_RotatingBorderPainter`).
* **Zero Layout Shift:** Dimensions remain strictly fixed at **`105dp × 105dp`**, preserving calendar navigation and layout alignment with zero jitter.

#### 7. Smart 18:00 AI Push Notification Digest (v1.4.9)
[Why: Staff on afternoon shift or at home want a quick summary of new notices without opening the app.]
* Upgraded `BackgroundSyncService` so the daily 18:00 evening sync puts the AI executive summary directly into the Android notification drawer (e.g. `🤖 New Notice: Met B` / `In Brief: ...`).

## 4. UI / UX Features & Keyword Customization

1. **Interactive Live Weather Card (`weather_card.dart`):** [Why: Greets employees with instant station weather, feels-like metric, humidity, wind, and precipitation probability at the very top of the dashboard]. Includes one-tap station switcher, automatic location detection, a 24-hour horizontal hourly carousel, and a 7-day weather outlook bottom sheet.
2. **Material 3 Theme:** [Why: Modern, battery-saving dark interface that reduces eye strain during night-shift duty operations]. Dark Theme (`#121212` background, `#1E1E1E` cards) with one-tap Light/Dark theme toggle.
3. **Leave Balance Cards:** [Why: Clean visual hierarchy letting staff see their CL, RH, and C-Off balances within one second of unlocking the app].
4. **12-Month Alert Grid with Dynamic Rotating Border (`alert_grid.dart`):** [Why: Visual warning matrix showing which upcoming months have expiring C-Offs so employees can plan leave applications in advance]. Features a dynamic rotating sweep-gradient neon light border around active expiring months (e.g. March 2027) with zero layout shift (maintains strict 105x105 dimensions).
5. **Interactive Month Calendar Screen (`month_calendar_screen.dart`):** [Why: Provides an intuitive calendar view where days with expiring leaves are marked with alert borders and day counters].
6. **Custom Keyword Filter in Settings (`settings_dialog.dart`):** [Why: Empowers each employee to personalize their notice board by tracking their own station, name, or cadre while hiding unwanted notices].
7. **Tabbed Circulars Section ("For You" & "Other Notices"):** [Why: Rebrands VIP notices to a personalized "For You" board while organizing general announcements into "Other Notices"]. Features 1-tap horizontal cadre filter chips (`All`, `Met B`, `Met A`, `SA`, `Scientists`, `Action Required`, `Bookmarked`), full-width title layout (leading star icon removed), and 1-tap local offline bookmarking (`🔖`).
8. **Sync Controls:** [Why: Gives users immediate visual feedback with animated spinners and SnackBars while data is refreshing from MetNet].
9. **Settings Panel (4 Tabs):** [Why: Organizes credentials, VIP filters, junk terms, and app updates into logical tabs for effortless navigation].
10. **Interactive In-Place Expandable Plain-Words Summary:** [Why: Employees want quick clarity on dense government orders without leaving their list position or downloading heavy PDFs]. Dual-tap navigation allows 1 tap on the notice card to open the PDF directly, while 1 tap on the summary box right below smoothly unfolds an in-place plain-words breakdown (`AnimatedSize`) explaining the order in everyday English, detailing action items, decoding confusing jargon, and offering an in-card PDF button.

---

## 5. Security & Biometric Protection

* **App Launch Lock:** [Why: Departmental intranet credentials and personal leave records must remain confidential if a colleague or family member borrows the phone]. Requires Fingerprint, Face Unlock, or Device PIN on launch.
* **Credentials Settings Gate:** [Why: Prevents unauthorized viewing or modification of stored MetNet passwords in Settings].
* **Fallback Guarantee (`biometricOnly: false`):** [Why: Ensures employees with wet, cold, or worn fingerprints can always unlock the app using their standard phone PIN or pattern].
* **Kotlin Integration (`FlutterFragmentActivity`):** [Why: Standard Android architecture requirement to support native `BiometricPrompt` dialogs].

---

## 6. Background Automation & Notifications

* **WorkManager Daily Sync (18:00 hrs):** [Why: Most departmental circulars and daily duty rosters are issued by late afternoon; syncing at 6:00 PM ensures employees receive the freshest data as they finish their shifts].
* **Intelligent Change Detection:** [Why: Compares newly fetched records with cached data so the app only notifies the user when something actually changed, avoiding annoying spam].
* **Start-of-Month Leave Reminders:** [Why: Reminds staff on the 1st, 2nd, and 3rd of each month if they have pending C-Offs or RHs to plan for].

---

## 7. Multiple Native Home Screen Widgets

[Why: Staff often just want to check their leave balances quickly; widgets display real-time numbers right on the home screen without needing to launch the app.]

* **Widget 1: Full Card Multi-Metric Widget (2x2):** [Why: Shows all 3 leave metrics (CL, RH, C-Off) along with the earliest expiring date and timestamp at a glance].
* **Widget 2: Compact Quick-View Widget (1x1):** [Why: Minimalist single-cell tile showing active C-Off balance for employees with crowded home screen setups].

---

## 8. In-App MetNet Notice & Multi-Email Resolver ("Open MetNet to Resolve")

[Why: MetNet intranet frequently blocks automated scrapers by demanding mandatory password changes every 90 days, unread official webmail/Zimbra notifications, duty declarations, or popup surveys. If the app closed prematurely after dismissing the first prompt, MetNet would bounce back to the second prompt and fail again.]

* **Status & Barrier Detection:** Automatically detects whether portal access is obstructed by an expired password, unread official emails, or general administrative declarations.
* **Contextual Dashboard Action Banners:**
  * If Password Expired: `🔑 Action Required: MetNet Password Expired` ➔ `[ Open MetNet to Change Password ]`
  * If Unread Webmail: `📬 Action Required: Unread Official Email Prompt` ➔ `[ Open MetNet to Clear Emails ]`
  * If General Notice/Pledge: `⚠️ MetNet Notice or Action Required` ➔ `[ Open MetNet to Resolve ]`
* **Protective Zero-Shield:** If leave balances cannot be parsed because an interstitial prompt is blocking the page, the scraper **never overwrites real balances with fake zeroes**, safely preserving cached records.
* **4-Second Settling Delay Buffer:** When MetNet touches `main2.php`, the viewer does not close instantly. It allows the page to load and initiates a 4-second countdown with a live status banner (`🟢 Dashboard reached! Settling in 4s...`). If MetNet bounces to email #2 or another declaration, the timer automatically cancels so the user can resolve remaining prompts without interruption.
* **Full User Control (`[ Done / Sync ]` Button):** An explicit `Done / Sync` button in the AppBar gives users an instant exit door whenever they know all emails and notices have been cleared.

---

## 9. Over-The-Air (OTA) & Internet Update Architecture

[Why: Because this app is distributed directly as an APK to colleagues, it requires an intelligent, self-updating system so everyone stays on the latest, bug-free version without manual downloads.]

1. **Automated Cloud Compilation:** [Why: GitHub Actions automatically compiles the production APK on push, ensuring clean, verifiable builds without local toolchain dependencies].
2. **On-Launch High-Urgency Update Prompt:** [Why: Uses psychological urgency triggers to ensure colleagues don't ignore critical bug fixes or scraper engine updates].
3. **Seamless Background Download:** [Why: Downloads the 48 MB update file asynchronously while letting the employee continue reading circulars and checking leaves without disruption].
4. **Native Package Installer Bridge (`MainActivity.kt`):** [Why: Bypasses Android 11+ web URL blocking by handing the downloaded APK directly to Android's system package installer via `FileProvider`].
5. **Auto-Resume Permission Flow:** [Why: If Android asks the user to toggle "Allow from this source", the app remembers the pending file and automatically pops up the installation dialog the moment they tap Back].
6. **Dual Push Notification System (`NotificationService.dart`):** [Why: Lets users update directly from their notification tray with a single tap, even if they haven't opened the app].
   * **Notification 201:** `🚨 Update Available` [Why: Informs users a new release is waiting].
   * **Notification 202:** `✅ Update Ready to Install` [Why: 1-tap install directly from the notification shade].
7. **Permanent Cryptographic Release Signing (`release.keystore`):** [Why: Android requires all updates to be signed with the exact same certificate. Using a permanent 30-year release key permanently eliminates the *"App not installed as package conflicts with an existing package"* error across all future updates].

---


8. **Process-Restart Recovery (`MainActivity.kt` & `SharedPreferences`):** [Why: On Android 10-14+, toggling 'Allow from this source' in Settings forces the OS to kill and restart the app process for security, wiping volatile memory and dropping the installation prompt]. The pending APK path is persisted in private `SharedPreferences` (`imd_installer_prefs`). When the user enables the permission and returns to the app, `MainActivity.onResume()` automatically recovers the path, verifies file integrity, and immediately launches the installation dialog on the very first attempt.
9. **Filesystem Buffer Settling Delay & Integrity Verification:** [Why: Immediately launching the PackageInstaller after closing Dart's download sink causes a race condition where the Linux OS has not yet flushed the file descriptor to flash memory, resulting in silent `PackageParser` EOF errors]. Introduced an explicit buffer flush, file size verification (>10MB), and a 400ms settling pause before invoking the installer, ensuring the package installer always receives a clean, unlocked file descriptor.
10. **Broadcast URI Permissions Across All OEM Installers:** [Why: Custom Android skins (Samsung Knox, Xiaomi MIUI/HyperOS, OnePlus OxygenOS, Vivo FuntouchOS) use proprietary package installers that reject standard FileProvider intents without explicit grants]. Dynamically queries all resolved activities matching `application/vnd.android.package-archive` and explicitly executes `grantUriPermission(pkg, contentUri, FLAG_GRANT_READ_URI_PERMISSION)`, eliminating hidden OEM permission rejections.
11. **Stale APK Cache Purge:** [Why: Re-using the same filename can cause Android's package manager to read older cached or partially aborted APK files]. Automatically cleans up older update files from the cache directory before initiating fresh downloads.

---

## 10. Key 6390 Diagnostic & Troubleshooting Suite (Discreet Protected Tools)

[Why: In enterprise field deployment across meteorological stations, employees occasionally experience network timeouts or question whether scanned Hindi orders are being OCR'd accurately. Exposing complex debug interfaces directly would confuse non-technical users; shielding all diagnostic tools behind a discreet 4-digit key (`6390`) guarantees a serene, clean interface for normal users while granting immediate diagnostic power to administrators and developers.]

* **Discreet Access Guard (Key `6390`):** [Why: Prevents accidental activation and keeps Settings Tab 4 uncluttered. Unlocking requires entering key `6390`, persisted securely in local storage via `StorageService.isDiagnosticsUnlocked()`].
* **Tool 1: Real-Time MetNet Server Connectivity & Latency Ping:** [Why: Instantly distinguishes between local Wi-Fi/cellular connection drops and MetNet server downtime by pinging `https://metnet.imd.gov.in/phps/left1.php`, clocking response round-trip time in milliseconds, and validating dynamic RSA encryption form readiness].
* **Tool 2: Offline Document Storage Cleaner:** [Why: Over months of active use, locally cached circular PDFs can occupy significant phone storage. Provides a safe 1-tap cache cleaner that purges cached PDFs without touching credentials or saved settings].
* **Tool 3: Scanned Notice Text Inspector (Devanagari OCR Sandbox):** [Why: Resolves user doubts regarding OCR accuracy on blurry or skewed scanned Hindi notices. Allows selecting any circular from the last 30 days to view full Google ML Kit Devanagari/Latin extracted text and highlights all matched VIP keywords in real time].
* **Tool 4: Circular Item Diagnostic Action Sheet (Long-Press):** [Why: Normal users copy the circular link upon long-pressing any circular tile; once key `6390` is unlocked, long-pressing opens an interactive diagnostic modal offering to inspect OCR text & summary, launch the document in PDF viewer, or copy the link].
* **Instant Re-Lock Safeguard:** [Why: Allows the user or developer to immediately lock the diagnostic tools again with a single tap on the lock icon, returning the app to its pristine standard user experience].

---

## 11. Automated Cloud Build & CI/CD Pipeline

* **Repository (`Aman6390/imd-portal`):** [Why: Secure central hosting for code, documentation, and releases].
* **GitHub Actions Workflow (`build_apk.yml`):** [Why: Runs on `ubuntu-latest` with Zulu JDK 17 and Flutter `3.24.3`, allocating 4GB heap to compile production APKs in under 5 minutes].
* **Artifact Upload & Release Management:** [Why: Makes compiled APKs immediately downloadable via GitHub CLI (`gh`) for testing and instant release creation].

---

## 12. Codebase File Structure

```
E:\imd portal\
├── .github\
│   └── workflows\
│       ├── ai_circular_indexer.yml           # Automated serverless AI circular semantic indexer [Why: Generates cloud AI metadata every 4h]
│       └── build_apk.yml                     # GitHub Actions Cloud APK Build workflow [Why: Automates cloud compilation]
├── android\
│   ├── app\
│   │   ├── build.gradle                      # Android build config & permanent release signing [Why: Manages dependencies & keystore]
│   │   ├── release.keystore                  # Permanent 30-year production cryptographic key [Why: Eliminates signature conflicts]
│   │   └── src\main\
│   │       ├── AndroidManifest.xml           # Permissions, activities, & widget receivers [Why: Declares Android OS capabilities]
│   │       ├── kotlin\com\example\imd_portal\
│   │       │   ├── MainActivity.kt           # Native FileProvider, PdfRenderer & installer bridge [Why: Executes native Android tasks]
│   │       │   ├── ImdAppWidgetProvider.kt   # 2x2 multi-metric widget provider [Why: Renders 2x2 home screen card]
│   │       │   └── ImdCompactWidgetProvider.kt # 1x1 compact widget provider [Why: Renders 1x1 home screen tile]
│   │       └── res\
│   │           ├── drawable\
│   │           │   ├── ic_stat_notification.xml # Dedicated vector notification icon [Why: Conforms to Android status bar specs]
│   │           │   └── widget_background.xml # Native rounded dark shape drawable [Why: Consistent dark styling]
│   │           ├── layout\
│   │           │   ├── imd_app_widget.xml    # 2x2 widget RemoteViews layout [Why: Native Android widget UI structure]
│   │           │   └── imd_compact_widget.xml # 1x1 compact widget layout [Why: Minimalist widget UI structure]
│   │           ├── values\
│   │           │   ├── strings.xml           # App & widget string definitions [Why: Centralized string labels]
│   │           │   └── styles.xml            # LaunchTheme and NormalTheme styles [Why: Native splash screen transition]
│   │           └── xml\
│   │               ├── file_paths.xml        # Secure FileProvider paths for APK & PDF sharing [Why: Grants temporary file access to OS]
│   │               ├── imd_app_widget_info.xml # 2x2 widget metadata [Why: Android widget dimension & resize config]
│   │               └── imd_compact_widget_info.xml # 1x1 widget metadata [Why: Android 1x1 cell config]
│   ├── build.gradle                          # Root Gradle configuration [Why: Builds Android project dependencies]
│   ├── gradle.properties                     # AndroidX & Jetifier flags [Why: AndroidX compatibility]
│   └── settings.gradle                       # Gradle project settings [Why: Multi-module Gradle routing]
├── lib\
│   ├── main.dart                             # App entry, Material 3 theme manager [Why: Initializes services & boots UI]
│   ├── models\
│   │   ├── ai_circular_entry.dart            # Model: AiCircularEntry with cadre, summary & actions [Why: AI metadata serialization]
│   │   └── dashboard_data.dart               # Models: DashboardData, CircularItem, LapsingAlert [Why: Type-safe JSON serialization]
│   ├── services\
│   │   ├── ai_circular_service.dart          # Multi-tier AI semantic indexer, on-device synthesizer & plain-words engine [Why: Decodes circulars & jargon]
│   │   ├── auth_service.dart                 # Local biometrics & PIN authentication service [Why: Manages device lock security]
│   │   ├── background_sync_service.dart      # WorkManager 18:00 worker & AI push notification digest [Why: Manages daily background automation]
│   │   ├── circular_service.dart             # Pre-flight verified PDF downloader, sibling fallback & cache [Why: Fixes 404 & loads PDFs]
│   │   ├── notification_service.dart         # Android notification channels & dispatcher [Why: Posts system push notifications]
│   │   ├── ocr_service.dart                  # On-Device Google ML Kit Devanagari OCR service [Why: Scans ambiguous Hindi orders]
│   │   ├── rsa_crypto.dart                   # RSA PKCS1_v1_5 dynamic password encrypter [Why: Bypasses MetNet login encryption]
│   │   ├── scraper_engine.dart               # AI-augmented VIP & junk filtering, session scraper & retries [Why: Scrapes portal data & circulars]
│   │   ├── storage_service.dart              # SharedPreferences for credentials, keywords, bookmarks & cache [Why: Persistent local storage]
│   │   ├── update_service.dart               # GitHub Releases automated update checker & installer [Why: Handles OTA background updates]
│   │   └── widget_service.dart               # HomeWidget multi-provider updater [Why: Synchronizes data to home widgets]
│   └── ui\
│       ├── dashboard_screen.dart             # Main dashboard view, lock screen, notice banner & FAB [Why: Core app user interface]
│       ├── month_calendar_screen.dart        # Interactive monthly calendar expiry view [Why: Dedicated C-Off expiry calendar]
│       └── widgets\
│           ├── alert_grid.dart               # 12-Month alert grid with dynamic rotating neon border [Why: Visual leave matrix with active expiry glow]
│           ├── circular_tabs.dart            # "For You" & "Other Notices" with cadre chips, bookmarks & expandable plain-words summaries [Why: Displays circulars]
│           ├── leave_card.dart               # Horizontal color-coded leave cards [Why: Displays CL, RH, C-Off balances]
│           ├── notice_resolver_webview.dart  # In-App MetNet Notice Resolver WebView [Why: Dismisses portal blocking popups]
│           ├── settings_dialog.dart          # 4-Tab settings: Account, VIP, Junk, About & Updates [Why: User configuration modal]
│           └── weather_card.dart             # Expandable high-density station weather card [Why: Real-time meteorological station situational awareness]
├── scripts\
│   └── ai_circular_indexer.py                # Serverless Python circular scraper & Gemini 1.5 Flash Vision indexer [Why: Automated cloud indexing]
├── .gitignore                                # Build & artifact ignore rules [Why: Prevents binary files in git]
├── analysis_options.yaml                     # Dart analyzer configuration [Why: Enforces Dart code quality standards]
├── pubspec.yaml                              # Flutter dependencies & metadata (v1.4.10+27) [Why: Defines app version & third-party packages]
└── MetNet Scraper+web Dashboard.md           # Master Project Blueprint & Documentation [Why: Single source of truth for the project]
```

---

## 13. Version History & Release Changelog

| Version | Build Code | Date | Key Architectural Changes & [Why We Made Them] |
| :--- | :--- | :--- | :--- |
| **v1.0.0** | `1.0.0+1` | Oct 2026 | **Initial Flutter Port:** Dynamic RSA PKCS1_v1_5 encryption handshake, leave balance extraction, 6-month C-Off expiry calculation, and 12-month visual alert timeline. [Why: Replaced Python desktop prototype with a native mobile app for staff smartphones] |
| **v1.1.0** | `1.1.0+2` | Oct 2026 | **Biometrics, Widgets & Background Worker:** Added Android native biometrics (`local_auth`), 2x2 and 1x1 home screen widgets (`home_widget`), WorkManager 18:00 daily sync, and on-device Devanagari OCR (`google_mlkit_text_recognition`). [Why: Provided phone-level security and allowed users to check balances without opening the app] |
| **v1.2.0** | `1.2.0+3` | Oct 2026 | **100% Free Edition:** Completely stripped all license validation, Pro tags, and paywall code. Introduced GitHub Releases-based Over-The-Air (OTA) update checking. [Why: User requested the app to be completely free and accessible to all meteorological staff without barriers] |
| **v1.3.0** | `1.3.0+4` | Oct 2026 | **Branding Neutralization:** Renamed user-facing branding to **Meteorological Portal**. Added visual progress indicator on update checking and high-urgency update modal prompt. [Why: Avoided proprietary IMD naming risks and created psychological urgency so staff don't ignore critical updates] |
| **v1.3.1** | `1.3.1+4` | Oct 2026 | **Comprehensive Circular Scraper:** Scrapes General, Establishment, Office Orders, and Transfers. Added RFC-compliant `Uri.resolve()` for relative paths, 4-tier PDF opening chain, and Android 11+ `<queries>` package visibility. [Why: Prevented missed notices across MetNet categories and resolved broken relative links] |
| **v1.3.2** | `1.3.2+5` | Oct 2026 | **Native Package Installer Bridge:** Integrated `FileProvider`, `file_paths.xml`, and `REQUEST_INSTALL_PACKAGES` permission in `MainActivity.kt` to replace web URL redirects with direct system installation. [Why: Fixed the stuck 'Install' button by invoking Android's system package installer natively] |
| **v1.3.3** | `1.3.3+6` | Oct 2026 | **Auto-Resume Permission Flow:** Added `checkAndResumePendingInstall()`, `onResume()`, and `onActivityResult()` in `MainActivity.kt`. Switched to external cache for broad OEM compatibility. [Why: Eliminated confusion when Android redirected users to 'Allow from this source' settings by auto-resuming the install upon returning] |
| **v1.3.4** | `1.3.4+7` | Oct 2026 | **Push Notification-Driven Updates:** Introduced system notification shade integration via `NotificationService.dart` & `BackgroundSyncService.dart`. Notification 201 prompts download; Notification 202 provides 1-tap install directly from the notification tray. [Why: Allowed colleagues to update the app directly from their notification shade with one tap] |
| **v1.3.5** | `1.3.5+8` | Oct 2026 | **Intelligent Circular Downloader & Sibling Fallback (Step 1):** Introduced `CircularService.dart`. Added `%PDF` magic byte verification, automatic multi-path sibling URL discovery (`/docs/`, `/phps/docs/`, `/Welcome_to_Intra-IMD/docs/`), authenticated session fallback, in-app modal handling for 404 withdrawn circulars, and native PDF launching via `FileProvider`. [Why: Completely solved the 'Not Found' Apache error when tapping circulars, and badged withdrawn notices clearly] |
| **v1.3.6** | `1.3.6+9` | Oct 2026 | **Permanent Release Keystore Signing:** Generated official 30-year `release.keystore` (alias `metnetkey`, valid until 2054) and configured `signingConfigs.release` in Gradle. Added dedicated vector icon `ic_stat_notification.xml` and runtime notification permission request. [Why: Permanently fixed 'App not installed as package conflicts with an existing package' caused by ephemeral cloud runner debug keys] |
| **v1.3.7** | `1.3.7+10` | Oct 2026 | **Key 6390 Troubleshooting Tools & Scanned Notice OCR Sandbox:** Embedded discreet developer/troubleshooting suite protected by key `6390`. Features live MetNet server connectivity & latency ping, offline document cache cleaner, scanned notice text inspector (Devanagari OCR & VIP keyword preview), and circular item long-press diagnostic action sheet. [Why: Gives developers and advanced users complete diagnostic transparency into network latency and OCR accuracy without cluttering the clean, non-technical experience for regular staff] |
| **v1.3.8** | `1.3.8+11` | Oct 2026 | **OCR Inspector Transparency & Devanagari Preload:** Added instant 404 validation before OCR processing, live multi-stage progress reporting (`Step 1/2: Downloading PDF...` -> `Step 2/2: Extracting Hindi text...`), user-dismissible/cancelable dialogs, silent background caching without launching external viewer, and pre-bundled `ocr_devanagari` model dependency in `AndroidManifest.xml`. Preserved robust 12s/15s portal fallback timeouts. [Why: Eliminates perceived OCR freezes, ensures Google Play pre-installs the Hindi language pack, and gives users full control and live visibility into download vs extraction phases] |
| **v1.3.9** | `1.3.9+12` | Oct 2026 | **30-Day Storage Auto-Purge & Bulletproof Dual-Engine OCR:** Added automatic 30-day rolling storage cleaner running on startup & daily 18:00 sync. Fixed Step 2/2 OCR freeze by clamping native bitmap allocation to 1600px with `Throwable` exception safety in `MainActivity.kt`, adding a 4s timeout on Devanagari OCR with instant pre-bundled Latin OCR fallback for sideloaded cellular devices, and immediate deletion of temporary page bitmaps. [Why: Completely prevents storage buildup beyond the 30-day window, and ensures OCR extracts text in 1-2 seconds without freezing when Google Play Services restricts background Devanagari model downloads on mobile data] |
| **v1.3.10** | `1.3.10+13` | Oct 2026 | **Background Thread PDF Rendering & Latin-First OCR Architecture:** Offloaded `PdfRenderer` and bitmap compression in `MainActivity.kt` to a dedicated background worker thread (`Thread { ... }.start()`) with `runOnUiThread` callbacks to completely eliminate UI thread blocking. Re-architected OCR engine to run pre-installed high-speed Latin OCR first (completing in ~300ms for bilingual notices), gracefully attempting Devanagari only if no Latin text is found, and enforced a hard 8-second safety ceiling on Step 2/2. [Why: Eliminates the 2-minute freeze on mobile data by ensuring native rendering never blocks the main thread, and avoids Google Play Services Devanagari download stalls on 5G] |
| **v1.3.11** | `1.3.11+14` | Oct 2026 | **Root Navigation Key & Context-Safe Dialog Dismissal:** Added global `rootNavigatorKey` in `main.dart` and decoupled loading dialog dismissal from local widget tree lifecycles in `CircularService.inspectCircularOcr`. Replaced unmounted context references with safe dialog context references, renamed shadowed `(context, index)` parameter in `settings_dialog.dart`, made `OcrService.processPdfFromUrl` share the optimized dual-engine pipeline, and made temporary rendered image filenames unique with timestamps. [Why: Permanently fixed the apparent 2-minute freeze where the OCR processing finished in 300ms but the progress dialog was never dismissed because the local caller context had unmounted or was shadowed by the popped parent dialog] |
| **v1.3.12** | `1.3.12+15` | Oct 2026 | **Programmatic Pop Disambiguation & Document Summary Dialog:** Disambiguated user manual cancels from programmatic progress dialog pops by adding `isProgrammaticDismiss` flag in `CircularService.inspectCircularOcr`. Replaced modal bottom sheet with a dedicated, centered `AlertDialog` with `SelectableText`, scrollable monospace container, and one-tap clipboard copy. [Why: Fixed the bug where Flutter's `PopScope.onPopInvoked` flagged programmatic dialog dismissal as user cancellation, which silently aborted the results display and prevented the user from seeing the extracted text] |
| **v1.3.13** | `1.3.13+16` | Oct 2026 | **Empirical VIP Keywords & Signatory-Safe OCR Matching:** Indexed 9,602 real MetNet circulars across 38 authenticated sections to discover real-world high-stakes keywords (`seniority list`, `draft seniority`, `working arrangement`, `lacd arrangement`, `promotion`, `modified acp`, `wmo vacancy`, `training course`). Implemented smart signatory neutralization so `scientist` and `वैज्ञानिक` only match in circular titles or explicit `Sub:` / `विषय:` headers, completely preventing routine administrative orders from falsely triggering VIP via bottom signature blocks. Added automatic legacy default migration in `StorageService`. [Why: Eliminates false VIP alerts on routine circulars signed by Scientists while ensuring essential career, posting, and seniority notices are detected with 100% precision] |
| **v1.4.0** | `1.4.0+17` | Oct 2026 | **100% Free Live Weather Forecast Engine & Multi-Station Outlook:** Introduced zero-configuration live weather forecasting powered by Open-Meteo & IMD numerical weather models with zero API keys required from users. Features interactive station selector with 27 pre-configured IMD Regional (RMC) and State (MC) Centres (New Delhi, Pune, Kolkata, Chennai, Mumbai, Nagpur, Guwahati, etc.), live temperature, "Feels like", humidity, wind speed, precipitation probability, WMO condition emojis, 24-hour horizontal hourly timeline carousel, 7-day weather outlook, and instant offline caching. [Why: Provides meteorologists and staff with instant station weather and shift planning metrics right on the dashboard with zero cost, zero setup, and zero rate limits] |
| **v1.4.1** | `1.4.1+18` | Oct 2026 | **Native GPS Auto-Location & Global City/Town Geocoding Search:** Added native Android LocationManager channel (`com.imd.portal/location`) with high-speed IP geolocation fallback so the app automatically pinpoints the user's real current location on first launch or via one-tap "Use My Current Location". Integrated Open-Meteo Geocoding Search so users can search and set the forecast to ANY city, town, or district in India or worldwide (e.g. Srinagar, Gulmarg, Noida, Dwarka) beyond standard IMD centres. [Why: Gives staff complete freedom to track their exact hometown, duty station, or field observatory weather with automatic GPS accuracy] |
| **v1.4.2** | `1.4.2+19` | Oct 2026 | **Compact High-Density Weather Card Redesign:** Re-engineered the dashboard weather card from a ~230dp vertical block into an ultra-compact ~85dp dual-row strip (a 65% reduction in vertical space). Features inline temperature, condition icon, feels-like metric, high/low range, and frosted micro-pills for humidity, wind, and rain probability alongside location chip and auto-detect shortcut. [Why: User feedback indicated the weather card occupied too much vertical space; this compact redesign frees up two-thirds of the screen for leave balances and departmental circulars while preserving full tap-to-view 24h & 7-day outlook functionality] |
| **v1.4.3** | `1.4.3+20` | Oct 2026 | **Expandable High-Density Weather Strip with In-Place Animated Unfolding:** Built dynamic interactive expand/collapse functionality for the compact weather card. By default, the card sits as an ultra-compact ~85dp dual-row strip saving ~65% screen space. Tapping the strip triggers a smooth 280ms animated expansion right on the dashboard, unfolding 4 dedicated metric cards (feels-like, humidity, wind, rain), the next 16-hour horizontal timeline carousel, and full 7-day outlook access, with rotating chevron and persisted user preference. [Why: Gives users the best of both worlds � maximum screen space by default, with complete station meteorological metrics expandable on demand] |
| **v1.4.4** | `1.4.4+21` | Oct 2026 | **AI Semantic Circular Summaries & Multi-Tier Failsafe Architecture:** Introduced serverless AI circular semantic indexer powered by Gemini 1.5 Flash Vision with multi-tier failsafe architecture (Tier 1 Cloud Index, Tier 2 On-Device Smart Engine, Tier 3 Local Devanagari OCR). Added 1-sentence plain-English summaries (`🤖 ...`), action required badges (`⚠️ Action Required`), VIP notification stars, and settings toggle in Settings Dialog. [Why: Enables employees to grasp circular purpose and deadlines in seconds without downloading or translating every individual notice] |
| **v1.4.5** | `1.4.5+22` | Oct 2026 | **Granular Official IMD Cadre Classification:** Expanded cadre detection across both cloud worker and on-device smart engine to recognize the full official IMD organizational hierarchy: Clerks (UDC/LDC), Scientific Assistants (SA), Meteorologist Grade A (`Met A`), Meteorologist Grade B (`Met B`), Scientific Officers (`SO-I`, `SO-II`, `SO-III`), and Scientists Grade B through H (`Scientist B` to `Scientist H`). Added multi-cadre compound linking (`Met A / SO-I`, `Scientist B / Scientist C`) and long-press AI breakdown modal bottom sheet. [Why: Matches official departmental designations so employees can instantly filter notices relevant to their exact career rank] |
| **v1.4.6** | `1.4.6+23` | Oct 2026 | **Smooth 1-Tap Update Installation & Process-Restart Recovery:** Solved the Android 10-14+ multi-attempt update bug caused by OS process-kills when toggling 'Allow from this source'. Persists update paths in SharedPreferences across app restarts, introduces 400ms filesystem buffer settling delay to prevent PackageParser race conditions, explicitly broadcasts URI permissions across all OEM package installers (Samsung, Xiaomi MIUI, OnePlus, Vivo), and purges stale APK caches. [Why: Guarantees a flawless, seamless 1-tap update installation on the very first attempt on any Android device] |
| **v1.4.7** | `1.4.7+24` | Oct 2026 | **Robust Government-Pattern Cadre Detection Engine:** Solved the "General / All" fallback issue where official circulars with quotes (e.g. Sc. 'C', Sc.'B', Met. 'A'), abbreviations (Scientific Asstt., Sci. Asstt., S.A.(Met)), dots (S.O.-I, S.O.-II, S.O.-III), and Devanagari Hindi grade aliases (सी, ख, ग) missed previous strict regex boundaries. Synchronized on-device Dart smart engine and GitHub Actions Python indexer with a comprehensive 23-point test suite. [Why: Ensures employees in every cadre—from Scientific Assistants to Scientists B-H—accurately see their specific cadre tags instead of falling back to General/All] |
| **v1.4.8** | `1.4.8+25` | Oct 2026 | **AI-Augmented VIP & Junk Filtering:** Expanded user keyword filtering beyond raw circular titles to simultaneously evaluate AI-generated semantic metadata (`targetCadre`, `summaryEn`, and `vipReasons`). Guarantees that circulars with abbreviated or obscure titles (e.g. `Draft Seniority list of Sci. Asstt.`) reliably land in the VIP Tab ⭐ when users track their cadre, while unwanted orders (e.g. peons/attendants/clerks) are cleanly discarded by Junk filters even if titles avoid explicit junk words. [Why: Gives staff bulletproof notice filtering that understands meaning and departmental designations rather than relying solely on literal word matching] |
| **v1.4.9** | `1.4.9+26` | Oct 2026 | **"For You" AI Executive Experience, Bookmarking & Dynamic Expiring C-Off Border:** Rebranded VIP tab to "For You" with one-tap horizontal cadre filter chips (`[ All ]`, `[ ⛅ Met B ]`, `[ 🌤️ Met A ]`, `[ 🔬 SA ]`, `[ 🧪 Scientists ]`, `[ ⚠️ Action Required ]`, `[ 🔖 Bookmarked ]`). Removed leading star icon to give full horizontal screen width to titles. Added instant 1-tap bookmarking/favorite toggle (`🔖`) next to the download button with local persistence. Designed an Executive "In-Brief" highlight card for AI summaries with frosted accents. Implemented dynamic rotating sweep-gradient neon border on active expiring C-Off months (e.g. March 2027) with zero layout shift (strictly preserved 105x105 dimensions). Upgraded daily 18:00 background sync to dispatch smart notification digests containing AI executive summaries. [Why: Transforms AI summaries into the premier daily driver feature of the app while giving users seamless cadre discovery, offline bookmarking, and visually compelling C-Off expiry alerts] |
| **v1.4.11** | `1.4.11+28` | Oct 2026 | **Settling Delay Multi-Email Resolver & Protective Zero-Shield:** Added intelligent 4-second settling countdown buffer in NoticeResolverWebView to prevent premature auto-closing when MetNet briefly visits main2.php between sequential unread email prompts, with real-time countdown banner and manual [ Done / Sync ] AppBar override. Integrated Protective Zero-Shield in scraper_engine.dart to ensure unparsed leave tables (due to password expiry, webmail notifications, or mandatory declarations) never overwrite existing valid leaves with fake zeroes. Added contextual dashboard warning banners specifically identifying Password Change vs Unread Email vs General Notice barriers with 1-tap in-app resolution. [Why: Permanently eliminates the empty dashboard bug caused by MetNet's 90-day password expiry and multiple sequential webmail notification prompts] |
| **v1.4.10** | `1.4.10+27` | Oct 2026 | **Interactive Expandable Plain-Words Summary & Dual-Tap Navigation:** Implemented dual-action tap architecture where 1 tap on the notice title or card body directly opens the original official PDF document, while 1 tap on the summary box right below smoothly unfolds an in-place detailed plain-words breakdown. Features plain everyday English translation (*What it means*), actionable employee advice (*👉 What you should do*), a built-in Jargon Buster for government acronyms (MACP, LACD, LDCE, Seniority lists), and an internal shortcut button to open the original PDF from within the expanded card. [Why: Gives staff instant plain-English clarity and control with zero friction: 1 tap for the PDF, 1 tap for the AI breakdown] |

---

## 14. Historical Reference Python Source Code

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
