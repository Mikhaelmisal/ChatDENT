# ChatDENT

ChatDENT is a dental clinic app for Windows (and other Flutter targets). It manages patients, appointments, photos, expenses, lab work, leads, and WhatsApp.

Data lives in **PocketBase**. WhatsApp goes through **Evolution API** and **n8n**. The clinic desktop app is this Flutter project.

Read **[manual.md](manual.md)** for how to use the screens after install.

## What you need

| Software | Why |
|----------|-----|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | PocketBase, n8n, Evolution, Postgres, Redis |
| [Flutter](https://docs.flutter.dev/get-started/install/windows) (stable, 3.22+) | Build and run the clinic app |
| [Git](https://git-scm.com/) | Clone / update this project |
| An [OpenRouter](https://openrouter.ai/) API key | WhatsApp assistant (optional until chat is live) |

This guide assumes **Windows**, clinic PC, project folder `D:\ChatDENT` (use your real path).

## 1. Open the project

```powershell
cd D:\ChatDENT
```

## 2. Create the env file

Create `.env` in the project root (same folder as `docker-compose.yml`):

```
OPENROUTER_API_KEY=sk-or-v1-your-key-here
N8N_BOOKING_TOKEN=paste-the-same-token-as-Settings-clinic-hours
EVOLUTION_API_KEY=clinic_secret_key_123
```

`N8N_BOOKING_TOKEN` must match **Settings → Clinic hours → n8n booking API token**. After changing `.env`, recreate n8n (`docker compose up -d n8n --force-recreate`).

Leave OpenRouter empty only if you will not run the WhatsApp AI yet. n8n reads this file when the container starts.

## 3. Start the servers

```powershell
docker compose up -d
```

Wait until these are running (`docker compose ps`):

| Service | In the browser / app |
|---------|----------------------|
| PocketBase | http://localhost:8095 |
| PocketBase admin | http://localhost:8095/_/ |
| n8n | http://localhost:5678 |
| Evolution API | http://localhost:8080 |
| Evolution manager | http://localhost:3000 |

Data is stored in `pb_data`, `n8n_data`, and `evolution_db` next to the compose file.

## 4. Create the PocketBase admin

1. Open http://localhost:8095/_/
2. Create the first superuser (email + password). Remember these; ChatDENT logs in with them.
3. You do **not** create collections by hand. ChatDENT creates them on first login.

If the UI is not ready yet, you can also create the user from Docker:

```powershell
docker exec -it pocketbase /usr/local/bin/pocketbase superuser upsert admin@clinic.local YourPassword123 --dir=/pb_data
```

(Command name can vary with the image. The admin UI is the usual way.)

## 5. Run the ChatDENT app

```powershell
flutter pub get
flutter run -d windows
```

On the login screen:

- **Server:** `http://localhost:8095`
- **Email / password:** the PocketBase superuser from step 4

The first login sets up the database. After it loads, open **Settings**.

## 6. Clinic settings (required)

1. **Phone** (top of Settings) and **Evolution WhatsApp → Primary clinic phone** — the number patients call. This fills `{phone}` in templates.
2. **Evolution WhatsApp**
   - Base URL: `http://localhost:8080` (from the PC) or `http://evolution-api:8080` is only for n8n inside Docker.
   - API key: `clinic_secret_key_123` (same as `AUTHENTICATION_API_KEY` in compose)
   - Instance name: `clinic_default`
   - Clinic name, address, Google Maps, staff group ID
   - Marketing instance 1–4: leave empty until extra WhatsApp numbers are connected
3. **Clinic hours** and booking token. Copy that token into `.env` as `N8N_BOOKING_TOKEN` (n8n sends it as `X-Booking-Token`).
4. **WhatsApp templates** — welcome, confirm, reminder, birthday, review, staff alerts, opt-out
5. **WhatsApp campaign** — review link, flyer, quiet hours, treatments (no prices)

Fully restart the Flutter app after first-time template seed (hot reload is not enough).

## 7. Connect WhatsApp (Evolution)

1. Open http://localhost:3000 (or Evolution docs for your image).
2. Create / open instance **`clinic_default`**.
3. Scan the QR with the **clinic** WhatsApp.
4. Set the webhook to:

   `http://n8n:5678/webhook/chatdent-whatsapp`

   Event: `messages.upsert`. Use **byEvents: false** so n8n receives the path it knows.

5. Put the clinic WhatsApp in the staff leads group. Do not chat in that group.

## 8. Import n8n workflows

1. Open http://localhost:5678 and create the n8n owner account.
2. Import these four (delete any old duplicates in n8n first):

   - `n8n_workflows/chatdent-whatsapp-assistant.json` — **activate**
   - `n8n_workflows/chatdent-reminders.json` — activate when ready
   - `n8n_workflows/chatdent-birthdays-reviews.json` — activate when ready
   - `n8n_workflows/chatdent-marketing.json` — activate only if using marketing blast

   Do not import any other workflow JSON for ChatDENT.

3. If you change the JS in `n8n_workflows/js/`, rebuild JSON:

   ```powershell
   python n8n_workflows/build.py
   ```

   Then re-import the changed workflow.

4. Recreate n8n after changing `.env` or `N8N_BLOCK_ENV_ACCESS_IN_NODE`:

   ```powershell
   docker compose up -d n8n --force-recreate
   ```

## 9. After a PocketBase hook change

Hooks live in `pb_hooks/` (mounted into the container). Reload them with:

```powershell
docker compose restart pocketbase
```

## Ports (this clinic)

| Port | Service |
|------|---------|
| 8095 | PocketBase (Flutter uses this) |
| 8090 | PocketBase inside Docker (`http://pocketbase:8090` from n8n) |
| 5678 | n8n |
| 8080 | Evolution API |
| 3000 | Evolution manager |

## Everyday use

- **Leads** — WhatsApp contacts, campaign messages, queue marketing images
- **WhatsApp desk** — birthdays, reviews, reschedule, interested (staff call; the AI never books and never quotes fees)
- **Patients / Appointments / DICOM** — same clinic records as before

Canned WhatsApp copy is only in **Settings → WhatsApp templates**. The AI only chats after the welcome template.

## Tests

```powershell
flutter test test --exclude-tags "serial || live_backend"
```

PowerShell 5.1 has no `&&`. Use two commands, or PowerShell 7+.

## Android app (same codebase)

ChatDENT is Flutter — the Android app is the **same project**, not a separate rewrite.

Package id: `app.chatdent.mobile`  
App name on the home screen: **ChatDENT**

### 1. Install Android tools (once)

1. Install [Android Studio](https://developer.android.com/studio) (winget: `winget install Google.AndroidStudio`).
2. Open Android Studio → **More Actions → SDK Manager** and install:
   - Android SDK Platform (API 34 or newer)
   - Android SDK Build-Tools
   - Android SDK Command-line Tools
3. Accept licenses:

```powershell
flutter doctor --android-licenses
```

4. Confirm:

```powershell
flutter doctor
```

Android toolchain should show a check mark.

### 2. Run on a phone or emulator

USB debugging on a phone, or start an emulator from Android Studio, then:

```powershell
cd D:\ChatDENT
flutter devices
flutter run -d <device-id>
```

On login, set **Server** to your PocketBase URL (not `localhost` on a real phone — use the PC’s LAN IP, e.g. `http://192.168.1.20:8095`, or a cloud host).

### 3. Build an installable APK

```powershell
flutter build apk --release
```

APK path:

`build\app\outputs\flutter-apk\app-release.apk`

Copy that file to the phone and install it (allow unknown sources if needed).

For Play Store later:

```powershell
flutter build appbundle --release
```

### 4. Push notifications (optional)

Push needs a real Firebase project named for ChatDENT:

1. Create project at https://console.firebase.google.com  
2. Add Android app with package `app.chatdent.mobile`  
3. Download `google-services.json` into `android/app/`  
4. Run `flutterfire configure` (or paste values into `lib/firebase_options.dart`)  

Until then the app still runs; only FCM push is skipped.

## Build the Windows app

```powershell
flutter build windows --release
```

Optional MSIX:

```powershell
dart run msix:create
```

## Support

Report bugs against this ChatDENT clinic project. There is no public store listing required to run it locally.

## License

GNU General Public License v3.0. See [LICENSE.md](LICENSE.md).
