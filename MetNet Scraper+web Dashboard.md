# **🚀 PROJECT MASTER BLUEPRINT: IMD Portal Automation Dashboard**

## **1\. Project Objectives**

* **Automate Data Extraction:** To securely log into the official portal bypassing basic bot-protections and extract real-time operational data.  
* **Leave Management:** To fetch balances for Casual Leaves (CL), Restricted Holidays (RH), and Compensatory Offs (C-Off), while predicting exact lapse dates for C-Offs.  
* **Smart Circular Tracking:** To monitor daily departmental orders/circulars, automatically filter out irrelevant notifications, and use AI to summarize crucial documents (specifically focusing on Scientific Assistant roles, transfers, and promotions).  
* **Multi-Platform Output:** To create a central `data.json` file that powers both a modern web dashboard (Streamlit) and a future hardware display (ESP32).

## **2\. Architecture & Data Flow (The 3 Phases)**

### **Phase 1: Cloud & Streamlit (The Core Engine)**

* **`scraper.py` (The Backend):** A Python script that logs in, scrapes HTML, processes the logic, and generates a structured `data.json` file. Scheduled to run once or twice daily.  
* **`data.json` (The Bridge):** The universal database file hosted on the cloud.  
* **`app.py` (The Frontend):** A Streamlit dashboard that solely reads the `data.json` file and displays beautiful metrics, charts, and alerts.

### **Phase 2: AI Parser (Zero/Low Cost OCR & NLP)**

* Integrates with `scraper.py`.  
* Downloads relevant VIP circular PDFs.  
* Sends the PDF content (via text extraction or OCR for scanned images) to a local AI model via LM Studio (or a low-cost API like Gemini Flash).  
* Appends the 2-line AI summary to `data.json`.

### **Phase 3: Hardware Integration (ESP32 Seed)**

* An ESP32 microcontroller with an OLED screen connects to Wi-Fi.  
* It performs a simple GET request directly to the hosted `data.json` URL.  
* Parses the JSON and displays real-time leave balances and the latest circular headline on the physical desk display.

## **3\. Extraction Techniques & Logic**

### **A. Secure Login Handling**

* **Method:** Python `requests.Session()` to maintain cookies.  
* **Encryption Bypass:** The portal uses JSEncrypt. The script will fetch the dynamically generated `publicKey` from the login page, use the `pycryptodome` library to encrypt the password via RSA PKCS1\_v1\_5, and post it exactly like a human browser.  
* **Token Handling:** Dynamic security tokens (`sc=...`) will be parsed from the HTML and appended to the POST request and subsequent URL navigation.

### **B. Leave Extraction (`leave_1.php`)**

* **Parsing Tool:** `BeautifulSoup4`.  
* **Target Elements:** The script searches for specific `<font color=#ff3333>` tags containing `<b>` elements.  
* **Extraction:** Uses Regular Expressions (Regex) or string slicing to grab the digits right after `[ Balance =` .  
* **The C-Off Expiry Math (Crucial Feature):**  
  * Script targets the C-Off table and extracts dates from the "Date of Credit" column.  
  * **Logic:** `Expiry Date = Date of Credit + 6 months`.  
  * **Alert System:** The script checks if the calculated Expiry Date falls in the *current month* or the *next month* and flags it in the JSON file as `"lapsing_soon"`.

### **C. Circular Extraction (`orders_display_1.php`)**

* **Method:** Iterating through table rows (`<tr>`) checking for background colors (`#ffffff` and `#f5f5f5`) to find circular entries.  
* **Data Points:** Parses the `<a href...>` tag to get the PDF download link, the text inside for the "Subject", and the adjacent column for the "Date of Upload".

## **4\. The "Smart Filter" Categorization System**

To prevent dashboard clutter and save AI API costs, circulars are funneled into three buckets based on keyword string-matching in their subjects:

1. **The VIP Bucket (Action Required):**  
   * *Keywords:* `Scientific Assistant`, `S.A.`, `Scientist`, `Transfer`, `Posting`, `Promotion`, `LDCE`, `MACP`, `Leave`, `Allowance`.  
   * *Action:* Display on top of the dashboard, download PDF, run AI summary.  
2. **The Blacklist / Junk Bucket (Ignore Completely):**  
   * *Keywords:* `Driver`, `Canteen`, `Cook`, `Mechanic`, `Carpenter`, `MTS`, `Attendant`.  
   * *Action:* Script ignores these completely. They never reach the JSON file.  
3. **The FOMO Bucket (Miscellaneous):**  
   * *Condition:* Circulars that don't match VIP or Junk keywords.  
   * *Action:* Extract Title and Link only. Displayed in an "Other Notifications" tab on Streamlit. No AI processing is done (saves cost), but ensures nothing is missed.

## **5\. Anti-Bot & Error Handling Safeguards**

* **IP Block Prevention:** Script includes `User-Agent` headers mimicking a standard Google Chrome browser on Windows.  
* **Maintenance Blackouts:** Wrapped in standard `try-except` blocks. If the portal is down or tags have changed, the script fails silently, logging the error internally without crashing the active Streamlit app (which simply continues showing the last known `data.json`).  
* **Server Overload Guard:** Fixed daily scheduling to prevent rapid-fire requests that trigger CAPTCHAs.

—-------------------------------------------------------------------------------------------  
\# ROLE & OBJECTIVE  
Act as an Expert Flutter & Dart Developer. Your objective is to build a native Android dashboard app for an India Meteorological Department (IMD) employee.   
The app must scrape attendance/leave data and departmental circulars from a secure Intranet portal, bypass an RSA-encrypted login, and introduce advanced native Android features (Background Sync, Local Notifications, and Home Screen Widgets).

\# REFERENCE MATERIAL  
I have already built the core scraping, encryption, and HTML parsing logic in a working Python (Flet) app.   
I have provided two reference files: \`main.py\` (UI structure) and \`scraper\_engine.py\` (auth, scraping, encryption).   
DO NOT guess the portal's URLs or login mechanics. Strictly translate the mechanical logic of \`scraper\_engine.py\` into Dart.

\# TECH STACK & PACKAGES  
\- Framework: Flutter (Dart)  
\- Networking: \`http\` (Maintain sessions/cookies)  
\- Encryption: \`encrypt\` or \`pointycastle\` (Must support RSA PKCS1\_v1\_5 like PyCryptodome)  
\- HTML Parsing: \`html\` or \`beautiful\_soup\_dart\`  
\- Storage: \`shared\_preferences\` (for saving credentials and JSON data securely)  
\- Background Tasks: \`workmanager\`  
\- Notifications: \`flutter\_local\_notifications\`  
\- Widget: \`home\_widget\`

\# CORE ARCHITECTURE & LOGIC (TRANSLATED FROM PYTHON)  
1\. \*\*Login Bypass:\*\*   
   \- Fetch the login page to extract the dynamic \`publicKey\` and \`sc\` (security code).  
   \- Encrypt the user's password using RSA PKCS1\_v1\_5 with the extracted \`publicKey\`.  
   \- Post the payload with appropriate headers (User-Agent spoofing, Referer).  
2\. \*\*Data Extraction:\*\*   
   \- Scrape leave balances (CL, RH, C-Off).  
   \- Scrape C-Off expiry dates and calculate days left.  
   \- Scrape circulars and categorize them into "VIP" (using keywords like scientist, promotion, transfer) and "Other Notifications".  
3\. \*\*Error Handling:\*\*   
   \- Implement a retry mechanism (Exponential Backoff, up to 3 tries) for network requests.  
   \- Handle HTTP non-200 status codes gracefully without crashing.

\# UI/UX REQUIREMENTS (DARK THEME)  
Translate my existing Flet UI into a modern Flutter Material Design UI:  
1\. \*\*App Bar:\*\* Title "🌤️ IMD Portal" with a Settings icon to input/save credentials.  
2\. \*\*Leave Cards:\*\* A horizontal scrollable row showing Balances for CL, RH, and C-Off. Color-code the text (e.g., Green/Orange based on threshold).  
3\. \*\*Alerts Grid:\*\* A 12-month visual grid highlighting expiring C-Offs.  
4\. \*\*Circulars Tab:\*\* A tabbed view separating "VIP Circulars" (Star icon) and "Other Notifications" (Article icon).  
5\. \*\*Sync Button:\*\* A Floating Action Button (FAB) for manual syncing. Show a CircularProgressIndicator during the sync.

\# ADVANCED NATIVE FEATURES (NEW)  
1\. \*\*Background Sync:\*\* Use \`workmanager\` to schedule a silent background sync every day at 18:00 hrs (6:00 PM). It should read the saved credentials, scrape the portal, and update the local data JSON.  
2\. \*\*Push Notifications:\*\* Use \`flutter\_local\_notifications\`. If the 18:00 hrs background sync detects a NEW circular or a CHANGE in leave balances compared to the local storage, trigger a local Android push notification stating: "IMD Dashboard: New Data Available".  
3\. \*\*Android Home Screen Widget:\*\* Use \`home\_widget\` to create a 2x2 Android widget. It should display the current "C-Off Balance" prominently and the "Last Synced" timestamp.

\# EXECUTION PLAN  
Acknowledge this PRD first. Do not write the entire app at once. We will build this step-by-step:  
Step 1: Initialize Flutter project and build the Dart scraper/encryption engine.  
Step 2: Build the UI and connect it to local storage.  
Step 3: Implement WorkManager and Local Notifications.  
Step 4: Implement the Home Screen Widget.  
Confirm you understand the logic and wait for my command to begin Step 1\.

\#code is pasted below:  
[main.py](http://main.py):  
*import* flet *as* ft  
*import* json  
*import* os  
*from* datetime *import* datetime, timedelta  
*from* scraper\_engine *import* run\_scraper\_async

\# \--- CRITICAL FIX: ANDROID SAFE FILE PATHS \---  
\# This ensures both the config and the scraped data are saved in the app's internal writable directory.  
BASE\_DIR \= os.environ.get("HOME", os.path.abspath(os.path.dirname(\_\_file\_\_)))  
CONFIG\_PATH \= os.path.join(BASE\_DIR, "config.json")  
DATA\_PATH \= os.path.join(BASE\_DIR, "data.json")

*def* main(page: ft.Page):  
    page.title \= "IMD Portal"  
    page.theme\_mode \= ft.ThemeMode.DARK  
    page.horizontal\_alignment \= ft.CrossAxisAlignment.CENTER  
    page.vertical\_alignment \= ft.MainAxisAlignment.CENTER

    \# \--- DATA LOADING \---  
    *def* load\_dashboard\_data():  
        """Load JSON data from Android safe path"""  
        *try*:  
            *if* os.path.exists(DATA\_PATH):  
                *with* open(DATA\_PATH, "r", encoding\="utf-8") *as* f:  
                    data \= json.load(f)  
                    *return* data  
            *else*:  
                *return* None  
        *except* *Exception* *as* e:  
            print(*f*"Error loading dashboard data: {e}")  
            *return* None  
     
    \# \--- CREDENTIALS FILE HANDLING \---  
    *def* load\_credentials():  
        """Load credentials from Android safe path"""  
        *try*:  
            *if* os.path.exists(CONFIG\_PATH):  
                *with* open(CONFIG\_PATH, "r", encoding\="utf-8") *as* f:  
                    config \= json.load(f)  
                    *return* config.get("username", ""), config.get("password", "")  
            *else*:  
                *return* "", ""  
        *except* *Exception* *as* e:  
            print(*f*"Error loading credentials: {e}")  
            *return* "", ""  
     
    *def* save\_credentials\_to\_file(username, password):  
        """Save credentials to Android safe path"""  
        *try*:  
            config \= {"username": username, "password": password}  
            *with* open(CONFIG\_PATH, "w", encoding\="utf-8") *as* f:  
                json.dump(config, f, indent\=4)  
            *return* True  
        *except* *Exception* *as* e:  
            print(*f*"Error saving credentials: {e}")  
            *return* False

    \# \--- THEME TOGGLE LOGIC \---  
    *def* toggle\_theme(e):  
        *if* page.theme\_mode \== ft.ThemeMode.DARK:  
            page.theme\_mode \= ft.ThemeMode.LIGHT  
            theme\_btn.icon \= ft.icons.DARK\_MODE  
        *else*:  
            page.theme\_mode \= ft.ThemeMode.DARK  
            theme\_btn.icon \= ft.icons.LIGHT\_MODE  
        page.update()

    theme\_btn \= ft.IconButton(  
        icon\=ft.icons.LIGHT\_MODE,  
        tooltip\="Toggle Dark/Light Theme",  
        on\_click\=toggle\_theme  
    )

    \# \--- CREDENTIALS / SETTINGS DIALOG \---  
    saved\_username, saved\_password \= load\_credentials()  
     
    username\_field \= ft.TextField(  
        label\="Username",  
        value\=saved\_username,  
        border\=ft.InputBorder.OUTLINE  
    )  
    password\_field \= ft.TextField(  
        label\="Password",  
        password\=True,  
        can\_reveal\_password\=True,  
        value\=saved\_password,  
        border\=ft.InputBorder.OUTLINE  
    )

    *def* close\_dialog(e):  
        settings\_dialog.open \= False  
        page.update()

    *def* save\_credentials(e):  
        username \= username\_field.value.strip()  
        password \= password\_field.value.strip()  
        *if* save\_credentials\_to\_file(username, password):  
            settings\_dialog.open \= False  
            page.snack\_bar \= ft.SnackBar(ft.Text("Credentials successfully saved\!"), bgcolor\=ft.colors.GREEN)  
            page.snack\_bar.open \= True  
            page.update()  
        *else*:  
            page.snack\_bar \= ft.SnackBar(ft.Text("Failed to save credentials\!"), bgcolor\=ft.colors.RED)  
            page.snack\_bar.open \= True  
            page.update()

    settings\_dialog \= ft.AlertDialog(  
        title\=ft.Text("Portal Settings"),  
        content\=ft.Column(  
            controls\=\[username\_field, password\_field\],  
            tight\=True,  
            spacing\=15  
        ),  
        actions\=\[  
            ft.TextButton("Cancel", on\_click\=close\_dialog),  
            ft.ElevatedButton("Save", on\_click\=save\_credentials)  
        \],  
        actions\_alignment\=ft.MainAxisAlignment.END,  
    )

    *def* open\_settings(e):  
        saved\_username, saved\_password \= load\_credentials()  
        username\_field.value \= saved\_username  
        password\_field.value \= saved\_password  
        settings\_dialog.open \= True  
        page.dialog \= settings\_dialog  
        page.update()

    settings\_btn \= ft.IconButton(  
        icon\=ft.icons.SETTINGS,  
        tooltip\="Settings",  
        on\_click\=open\_settings  
    )

    \# \--- APP BAR \---  
    page.appbar \= ft.AppBar(  
        title\=ft.Text("🌤️ IMD Portal", weight\=ft.FontWeight.BOLD),  
        center\_title\=False,  
        actions\=\[theme\_btn, settings\_btn\],  
    )

    \# \--- DASHBOARD UI BUILDERS \---  
    *def* build\_no\_data\_view():  
        *return* ft.Card(  
            content\=ft.Container(  
                content\=ft.Column(  
                    controls\=\[  
                        ft.Icon(ft.icons.SYNC\_PROBLEM, size\=52, color\=ft.colors.ORANGE),  
                        ft.Text("No Data Yet", size\=24, weight\=ft.FontWeight.BOLD),  
                        ft.Text("Tap the sync button below to fetch your leave balances and circulars.",  
                                color\=ft.colors.GREY\_400, text\_align\=ft.TextAlign.CENTER),  
                        ft.Text("Make sure you've saved your credentials in Settings (⚙️) first.",  
                                color\=ft.colors.GREY\_500, size\=12, text\_align\=ft.TextAlign.CENTER),  
                    \],  
                    alignment\=ft.MainAxisAlignment.CENTER,  
                    horizontal\_alignment\=ft.CrossAxisAlignment.CENTER,  
                    spacing\=12,  
                ),  
                padding\=35,  
                alignment\=ft.alignment.center,  
            )  
        )  
     
    *def* build\_leave\_cards(leaves\_data):  
        cards \= \[\]  
        *for* key, display\_name *in* \[  
            ("Casual Leave (CL)", "Casual Leave"),  
            ("Restricted Holiday (RH)", "Restricted Holiday"),  
            ("Compensatory Off (C-Off)", "Compensatory Off")  
        \]:  
            value \= leaves\_data.get(key, "0")  
            *if* key \== "Compensatory Off (C-Off)":  
                color \= ft.colors.DEEP\_ORANGE *if* *int*(value) \> 15 *else* ft.colors.GREEN  
            *else*:  
                color \= ft.colors.BLUE *if* *int*(value) \> 5 *else* ft.colors.ORANGE  
                 
            cards.append(  
                ft.Card(  
                    content\=ft.Container(  
                        content\=ft.Column(  
                            controls\=\[  
                                ft.Text(display\_name, size\=14, weight\=ft.FontWeight.W\_500, color\=ft.colors.GREY\_600),  
                                ft.Text(value, size\=32, weight\=ft.FontWeight.BOLD, color\=color),  
                                ft.Text("days" *if* key \!= "Restricted Holiday (RH)" *else* "days",  
                                        size\=12, color\=ft.colors.GREY\_500),  
                            \],  
                            alignment\=ft.MainAxisAlignment.CENTER,  
                            horizontal\_alignment\=ft.CrossAxisAlignment.CENTER,  
                            spacing\=2,  
                        ),  
                        padding\=20,  
                        width\=110,  
                    ),  
                    elevation\=2,  
                )  
            )  
        *return* ft.Row(controls\=cards, alignment\=ft.MainAxisAlignment.SPACE\_EVENLY, spacing\=10)  
     
    *def* build\_alerts\_list(alerts\_data):  
        month\_counts \= {}  
        *if* alerts\_data:  
            *for* alert *in* alerts\_data:  
                expiry\_str \= alert.get("Expiry Date", "")  
                *try*:  
                    expiry\_date \= datetime.strptime(expiry\_str, "%d\-%m-%Y")  
                    month\_key \= expiry\_date.strftime("%Y-%m")  
                    month\_counts\[month\_key\] \= month\_counts.get(month\_key, 0) \+ 1  
                *except* (*ValueError*, *AttributeError*):  
                    *continue*  
         
        current\_date \= datetime.now()  
        month\_boxes \= \[\]  
         
        *for* i *in* range(12):  
            month \= current\_date.month \+ i  
            year \= current\_date.year \+ (month \- 1) // 12  
            month \= (month \- 1) % 12 \+ 1  
            month\_date \= datetime(year, month, 1)  
             
            month\_key \= month\_date.strftime("%Y-%m")  
            month\_name \= month\_date.strftime("%b %Y")  
            count \= month\_counts.get(month\_key, 0)  
             
            bg\_color \= ft.colors.with\_opacity(0.1, ft.colors.AMBER) *if* count \> 0 *else* ft.colors.with\_opacity(0.05, ft.colors.GREY\_400)  
            border\_color \= ft.colors.AMBER *if* count \> 0 *else* ft.colors.GREY\_400  
            text\_color \= ft.colors.AMBER *if* count \> 0 *else* ft.colors.GREY\_600  
             
            *if* count \> 0:  
                display\_text \= *f*'{count} C-Off{"s" *if* count \!= 1 *else* ""}'  
                text\_color\_count \= ft.colors.RED  
            *else*:  
                display\_text \= "0"  
                text\_color\_count \= ft.colors.GREY\_500  
             
            month\_box \= ft.Container(  
                content\=ft.Column(  
                    controls\=\[  
                        ft.Text(month\_name, size\=14, weight\=ft.FontWeight.BOLD, color\=text\_color),  
                        ft.Text(  
                            display\_text,  
                            size\=18,  
                            weight\=ft.FontWeight.BOLD,  
                            color\=text\_color\_count  
                        ),  
                    \],  
                    horizontal\_alignment\=ft.CrossAxisAlignment.CENTER,  
                    alignment\=ft.MainAxisAlignment.CENTER,  
                    spacing\=5,  
                ),  
                width\=110,  
                height\=110,  
                border\=ft.border.all(1, border\_color),  
                border\_radius\=10,  
                bgcolor\=bg\_color,  
                padding\=10,  
                alignment\=ft.alignment.center,  
            )  
            month\_boxes.append(month\_box)  
         
        grid \= ft.Row(  
            controls\=month\_boxes,  
            wrap\=False,  
            spacing\=10,  
            scroll\=ft.ScrollMode.ADAPTIVE,  
            alignment\=ft.MainAxisAlignment.START,  
        )  
         
        *if* not alerts\_data:  
            *return* ft.Column(\[  
                ft.Text("No active C-Offs expiring soon.", italic\=True, color\=ft.colors.GREY\_500)  
            \], spacing\=8)  
         
        *return* ft.Column(  
            controls\=\[  
                grid,  
                ft.Container(height\=5),  
                ft.Text(*f*"Total active C-Offs: {sum(month\_counts.values())}",  
                        size\=12, color\=ft.colors.GREY\_500, italic\=True)  
            \],  
            spacing\=8,  
            horizontal\_alignment\=ft.CrossAxisAlignment.CENTER,  
        )  
     
    *def* build\_circulars\_tabs(circulars\_data):  
        vip\_items \= \[\]  
        *for* circ *in* circulars\_data.get("vip", \[\]):  
            vip\_items.append(  
                ft.ListTile(  
                    title\=ft.Text(circ.get("title", "No title"), max\_lines\=2, overflow\=ft.TextOverflow.ELLIPSIS),  
                    subtitle\=ft.Text(*f*"Uploaded: {circ.get('date', 'Unknown')}", size\=12),  
                    leading\=ft.Icon(ft.icons.STAR, color\=ft.colors.AMBER),  
                    on\_click\=*lambda* e, link\=circ.get("link"): page.launch\_url(link) *if* link *else* None,  
                )  
            )  
         
        fomo\_items \= \[\]  
        *for* circ *in* circulars\_data.get("fomo", \[\]):  
            fomo\_items.append(  
                ft.ListTile(  
                    title\=ft.Text(circ.get("title", "No title"), max\_lines\=2, overflow\=ft.TextOverflow.ELLIPSIS),  
                    subtitle\=ft.Text(*f*"Uploaded: {circ.get('date', 'Unknown')}", size\=12),  
                    leading\=ft.Icon(ft.icons.ARTICLE, color\=ft.colors.BLUE),  
                    on\_click\=*lambda* e, link\=circ.get("link"): page.launch\_url(link) *if* link *else* None,  
                )  
            )  
         
        *return* ft.Tabs(  
            selected\_index\=0,  
            animation\_duration\=300,  
            tabs\=\[  
                ft.Tab(  
                    text\="VIP Circulars",  
                    icon\=ft.icons.STAR,  
                    content\=ft.Container(  
                        content\=ft.ListView(  
                            controls\=vip\_items *if* vip\_items *else* \[  
                                ft.Text("No VIP circulars found.", italic\=True, color\=ft.colors.GREY\_500)  
                            \],  
                            spacing\=5,  
                            height\=200,  
                        ),  
                        padding\=10,  
                    ),  
                ),  
                ft.Tab(  
                    text\="Other Notifications",  
                    icon\=ft.icons.ARTICLE,  
                    content\=ft.Container(  
                        content\=ft.ListView(  
                            controls\=fomo\_items *if* fomo\_items *else* \[  
                                ft.Text("No other notifications.", italic\=True, color\=ft.colors.GREY\_500)  
                            \],  
                            spacing\=5,  
                            height\=200,  
                        ),  
                        padding\=10,  
                    ),  
                ),  
            \],  
            expand\=1,  
        )  
     
    *def* build\_dashboard\_view(data):  
        last\_updated \= data.get("last\_updated", "Unknown")  
        leaves \= data.get("leaves", {})  
        alerts \= data.get("alerts", \[\])  
        circulars \= data.get("circulars", {})  
         
        *return* ft.Column(  
            controls\=\[  
                ft.Container(  
                    content\=ft.Row(  
                        controls\=\[  
                            ft.Icon(ft.icons.UPDATE, size\=16, color\=ft.colors.GREY\_500),  
                            ft.Text(*f*"Last synced: {last\_updated}", size\=12, color\=ft.colors.GREY\_500),  
                        \],  
                        spacing\=5,  
                    ),  
                    padding\=ft.padding.symmetric(horizontal\=15, vertical\=10),  
                    alignment\=ft.alignment.center\_left,  
                ),  
                ft.Container(  
                    content\=ft.Column(  
                        controls\=\[  
                            ft.Text("📅 Leave Balances", size\=18, weight\=ft.FontWeight.BOLD),  
                            build\_leave\_cards(leaves),  
                        \],  
                        spacing\=15,  
                    ),  
                    padding\=15,  
                ),  
                ft.Container(  
                    content\=ft.Column(  
                        controls\=\[  
                            ft.Text("⚠️ C-Off Expiry Alerts", size\=18, weight\=ft.FontWeight.BOLD),  
                            build\_alerts\_list(alerts),  
                        \],  
                        spacing\=15,  
                    ),  
                    padding\=15,  
                ),  
                ft.Container(  
                    content\=ft.Column(  
                        controls\=\[  
                            ft.Text("📄 Departmental Circulars", size\=18, weight\=ft.FontWeight.BOLD),  
                            ft.Container(  
                                content\=build\_circulars\_tabs(circulars),  
                                height\=300,  
                            ),  
                        \],  
                        spacing\=15,  
                    ),  
                    padding\=15,  
                ),  
                ft.Container(height\=20),  
            \],  
            scroll\=ft.ScrollMode.AUTO,  
            spacing\=0,  
        )  
     
    *def* refresh\_dashboard():  
        data \= load\_dashboard\_data()  
        *if* data:  
            main\_content.content \= build\_dashboard\_view(data)  
            main\_content.alignment \= ft.alignment.top\_left  
        *else*:  
            main\_content.content \= build\_no\_data\_view()  
            main\_content.alignment \= ft.alignment.center  
        page.update()  
     
    \# \--- MAIN CONTENT CONTAINER \---  
    main\_content \= ft.Container(  
        content\=build\_no\_data\_view(),  
        alignment\=ft.alignment.center,  
        expand\=True,  
    )  
     
    \# \--- BODY \---  
    page.horizontal\_alignment \= ft.CrossAxisAlignment.STRETCH  
    page.vertical\_alignment \= ft.MainAxisAlignment.START  
    page.add(main\_content)  
     
    refresh\_dashboard()

    \# \--- SYNC BUTTON LOGIC \---  
    progress\_ring \= ft.ProgressRing(width\=20, height\=20, stroke\_width\=2, visible\=False)  
     
    *async* *def* sync\_data(e):  
        user, pwd \= load\_credentials()  
         
        *if* not user or not pwd:  
            page.snack\_bar \= ft.SnackBar(ft.Text("Please save your credentials in Settings first\!"))  
            page.snack\_bar.open \= True  
            page.update()  
            *return*  
             
        sync\_fab.icon \= None  
        sync\_fab.content \= progress\_ring  
        progress\_ring.visible \= True  
        page.update()  
         
        success, message \= *await* run\_scraper\_async(user, pwd)  
         
        progress\_ring.visible \= False  
        sync\_fab.content \= None  
        sync\_fab.icon \= ft.icons.SYNC  
         
        page.snack\_bar \= ft.SnackBar(ft.Text(message))  
        page.snack\_bar.open \= True  
        page.update()  
         
        *if* success:  
            refresh\_dashboard()

    sync\_fab \= ft.FloatingActionButton(icon\=ft.icons.SYNC, on\_click\=sync\_data)  
    page.floating\_action\_button \= sync\_fab  
    page.update()  
     
*if* \_\_name\_\_ \== "\_\_main\_\_":  
    ft.app(target\=main)

Requirements.txt:  
flet==0.25.2  
requests  
beautifulsoup4  
pycryptodome  
python-dateutil

Scraper\_engine.py:  
*import* requests  
*from* bs4 *import* BeautifulSoup  
*from* Crypto.PublicKey *import* RSA  
*from* Crypto.Cipher *import* PKCS1\_v1\_5  
*import* base64  
*import* json  
*import* re  
*import* time  
*from* datetime *import* datetime  
*from* dateutil.relativedelta *import* relativedelta  
*from* urllib.parse *import* urljoin  
*import* os  
*import* asyncio

\# \--- CRITICAL FIX: ANDROID SAFE FILE PATH \---  
BASE\_DIR \= os.environ.get("HOME", os.path.abspath(os.path.dirname(\_\_file\_\_)))  
DATA\_PATH \= os.path.join(BASE\_DIR, "data.json")

\# \--- SMART FILTERS \---  
VIP\_KEYWORDS \= \['scientific assistant', 's.a.', 'scientist', 'transfer', 'posting', 'promotion', 'ldce', 'macp', 'leave', 'allowance'\]  
JUNK\_KEYWORDS \= \['driver', 'canteen', 'cook', 'mechanic', 'carpenter', 'mts', 'attendant', 'clerk', 'steno', 'stenographer', 'hindi translator', 'staff car'\]

*def* parse\_leaves(soup):  
    html\_text \= soup.get\_text()  
     
    cl\_match \= re.search(*r*"Casual Leaves.\*?Balance \=\\s\*(\\d\+)", html\_text)  
    rh\_match \= re.search(*r*"Restricted Holidays.\*?Balance \=\\s\*(\\d\+)", html\_text)  
    coff\_match \= re.search(*r*"Compensatory Off.\*?Balance \=\\s\*(\\d\+)", html\_text)  
     
    balances \= {  
        "Casual Leave (CL)": cl\_match.group(1) *if* cl\_match *else* "0",  
        "Restricted Holiday (RH)": rh\_match.group(1) *if* rh\_match *else* "0",  
        "Compensatory Off (C-Off)": coff\_match.group(1) *if* coff\_match *else* "0"  
    }  
     
    lapsing\_alerts \= \[\]  
    current\_date \= datetime.now()  
     
    rows \= soup.find\_all('tr', bgcolor\=\['\#ffffff', '\#f5f5f5'\])  
    *for* row *in* rows:  
        cols \= row.find\_all('td')  
        *if* len(cols) \>= 10:  
            date\_of\_credit\_str \= cols\[1\].text.strip()  
            status \= cols\[8\].text.strip()  
             
            *if* not status and re.match(*r*"\\d{2}\-\\d{2}\-\\d{4}", date\_of\_credit\_str):  
                credit\_date \= datetime.strptime(date\_of\_credit\_str, "%d\-%m-%Y")  
                expiry\_date \= credit\_date \+ relativedelta(months\=+6)  
                days\_left \= (expiry\_date \- current\_date).days  
                 
                *if* days\_left \> 0:  
                    lapsing\_alerts.append({  
                        "Credit Date": date\_of\_credit\_str,  
                        "Expiry Date": expiry\_date.strftime("%d\-%m-%Y"),  
                        "Days Left": days\_left  
                    })  
     
    *return* balances, lapsing\_alerts

*def* parse\_circulars(soup):  
    vip\_circulars \= \[\]  
    fomo\_circulars \= \[\]  
     
    rows \= soup.find\_all('tr', bgcolor\=\['\#ffffff', '\#f5f5f5'\])  
    *for* row *in* rows:  
        cols \= row.find\_all('td')  
        *if* len(cols) \>= 4:  
            a\_tag \= cols\[1\].find('a')  
            *if* a\_tag:  
                title \= a\_tag.text.strip().replace('\\n', ' ')  
                link \= "https\://metnet.imd.gov.in" \+ a\_tag\['href'\].replace('..', '')  
                upload\_date \= cols\[3\].text.strip()  
                title\_lower \= title.lower()  
                 
                *if* any(junk *in* title\_lower *for* junk *in* JUNK\_KEYWORDS):  
                    *continue*  
                *if* any(vip *in* title\_lower *for* vip *in* VIP\_KEYWORDS):  
                    vip\_circulars.append({"title": title, "link": link, "date": upload\_date})  
                *else*:  
                    fomo\_circulars.append({"title": title, "link": link, "date": upload\_date})  
                     
    *return* vip\_circulars, fomo\_circulars

*def* \_run\_scraper\_sync(username, password):  
    print("Session start kar rahe hain...")  
    session \= requests.Session()  
     
    session.headers.update({  
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36'  
    })  
     
    *try*:  
        print("Fetching login form...")  
        session.get("https\://metnet.imd.gov.in/Welcome\_to\_Intra-IMD/welcome.php", timeout\=20)  
        login\_page \= session.get("https\://metnet.imd.gov.in/phps/left1.php", timeout\=20)  
        soup\_login \= BeautifulSoup(login\_page.text, 'html.parser')  
         
        pub\_input \= soup\_login.find('input', {'id': 'publicKey'})  
        sc\_input \= soup\_login.find('input', {'name': 'sc'})  
         
        *if* not pub\_input or not sc\_input:  
            *return* False, "❌ Form inputs nahi mile\!"

        public\_key\_str \= pub\_input\['value'\]  
        sc\_val \= sc\_input\['value'\]  
         
        rsa\_key \= RSA.importKey(public\_key\_str)  
        cipher \= PKCS1\_v1\_5.new(rsa\_key)  
        encrypted\_pass \= base64.b64encode(cipher.encrypt(password.encode('utf-8'))).decode('utf-8')  
         
        payload \= {}  
        form \= soup\_login.find('form')  
        *if* form:  
            *for* el *in* form.find\_all(\['input', 'button', 'select'\]):  
                *if* el.get('name'):  
                    payload\[el.get('name')\] \= el.get('value', '')  
                     
        payload\['login\_username'\] \= username  
        payload\['password'\] \= encrypted\_pass  
        payload\['sc'\] \= sc\_val  
         
        print("Logging in...")  
        session.headers.update({  
            'Referer': 'https\://metnet.imd.gov.in/phps/left1.php',  
            'Origin': 'https\://metnet.imd.gov.in'  
        })  
         
        session.post("https\://metnet.imd.gov.in/phps/emplogin.php", data\=payload, timeout\=20)  
        time.sleep(2)  
         
        main\_page \= session.get("https\://metnet.imd.gov.in/phps/main2.php?ver=e", timeout\=20)  
        soup\_main \= BeautifulSoup(main\_page.text, 'html.parser')  
         
        leave\_url \= None  
        circular\_url \= None  
        base\_url \= "https\://metnet.imd.gov.in/phps/"  
         
        *for* a *in* soup\_main.find\_all('a', href\=True):  
            href \= a\['href'\]  
            *if* 'leave\_1.php' in href and not leave\_url:  
                leave\_url \= urljoin(base\_url, href)  
            *elif* 'circulars\_display\_2.php' in href and 'GENERAL' in href and not circular\_url:  
                circular\_url \= urljoin(base\_url, href)  
                 
        *if* not leave\_url or not circular\_url:  
            *return* False, "❌ Dashboard URLs nahi mile. Credentials check karein."  
             
        leave\_page \= session.get(leave\_url, timeout\=20)  
        leave\_balances, lapsing\_alerts \= parse\_leaves(BeautifulSoup(leave\_page.text, 'html.parser'))  
         
        circular\_page \= session.get(circular\_url, timeout\=20)  
        vip\_circ, fomo\_circ \= parse\_circulars(BeautifulSoup(circular\_page.text, 'html.parser'))  
         
        dashboard\_data \= {  
            "last\_updated": datetime.now().strftime("%d\-%m-%Y %H:%M:%S"),  
            "leaves": leave\_balances,  
            "alerts": lapsing\_alerts,  
            "circulars": {  
                "vip": vip\_circ\[:10\],      
                "fomo": fomo\_circ\[:15\]    
            }  
        }  
         
        \# \--- FIXED: Save to Android-safe Path \---  
        *with* open(DATA\_PATH, "w") *as* f:  
            json.dump(dashboard\_data, f, indent\=4)  
             
        *return* True, "✅ SUCCESS\! Data synced successfully."  
         
    *except* *Exception* *as* e:  
        *return* False, *f*"Error aayi: {*str*(e)}"

*async* *def* run\_scraper\_async(username, password):  
    *return* *await* asyncio.to\_thread(\_run\_scraper\_sync, username, password)

