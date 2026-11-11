# DineCircle Deploy Runbook

Order matters. The apps cannot ship before the API exists, because their API
base URL is compiled into the binary. Nothing here is automated: every step is
a dashboard action or a command you run locally.

## Status as of this writing

| Piece | State |
| --- | --- |
| Express API (`DineCircle-master/server`) | **LIVE on Render** (`dinecircle-api.onrender.com`, Docker, free, Singapore). `/api/health` 200 with `database:"unified dinecircle"` and ~65 ms latency; `/api/restaurants` 401 unauth; unknown `Origin` 403; phone `POST /api/auth/signin` 403 in production. |
| Customer app (`DineCircle-master`) | Release keystore wired, analyze clean. `dart-defines.json` retargeted to the Render URL; release APK still needs rebuilding against it. |
| Partner app (`partnerapp`) | Release keystore generated, Business workspace redesigned, analyze clean. `dart-defines.json` already on the Render URL; APK rebuild pending. |
| Marketing site (`website`) | 29 pages built with canonical URLs, sitemap, robots, hosting rules. **No host**: `https://dinecircle.app` returns no HTTP response (it only resolves to a tailnet address on this machine). |

Both `dart-defines.json` files now point at
`https://dinecircle-api.onrender.com`, the URL the Render blueprint in step 1
produced. They are gitignored, so each build machine needs its own copy.

## 1. Deploy the API

1. Push `DineCircle-master` to GitHub.
2. Render → New → Blueprint → that repo. It reads `render.yaml` and creates the
   `dinecircle-api` web service (Docker, free plan, Singapore region,
   `rootDir: server`, health check `/api/health`).
3. The blueprint asks for two secrets once:
   - `DATABASE_URL` — the Supabase **session** pooler string, ending in
     `?sslmode=require`.
   - `CORS_ALLOWED_ORIGINS` — `https://dinecircle.app`. Browsers only; the
     mobile apps send no `Origin` header and need nothing here.
   Everything else (`NODE_ENV=production`, `TRUST_PROXY=1`, the CA bundle path,
   pool size) is already in the blueprint.
4. Wait for the build, then confirm:

   ```bash
   curl -s https://dinecircle-api.onrender.com/api/health
   ```

   Expect `{"status":"ok","database":"up",...}`. A `503` with
   `"database":"unreachable"` means the service is live but `DATABASE_URL` is
   wrong or the pooler is asleep. Do not continue until this returns 200.

If the URL ends up different from `dinecircle-api.onrender.com`, update
`API_BASE_URL` in both `dart-defines.json` files before step 2.

## 2. Build the release APKs

Run the two builds **sequentially**, never in parallel.

Gate check first:

```bash
cd DineCircle-master && curl -s -o /dev/null -w "%{http_code}\n" \
  "$(python3 -c "import json;print(json.load(open('dart-defines.json'))['API_BASE_URL'])")/api/health"
```

It must print `200`. Building against an unreachable host produces an APK that
installs, opens and then shows only errors.

```bash
export PATH="/home/til3fishnix001/flutter/bin:$PATH"

cd DineCircle-master && \
  flutter build apk --release --dart-define-from-file=dart-defines.json

cd ../partnerapp && \
  flutter build apk --release --dart-define-from-file=dart-defines.json
```

Each takes 4–6 minutes; artifacts land at
`build/app/outputs/flutter-apk/app-release.apk` (fat, all ABIs, ~110 MB).
`--target-platform android-arm64` is smaller but overwrites the same path.

Confirm the APK really is release-signed. `keytool -printcert -jarfile` is
useless here (it says "Not a signed jar file" for v2/v3-only signatures):

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Keystores: `DineCircle-master/android/app/dinecircle-release.jks` and
`partnerapp/android/app/dinecircle-partner-release.jks`, each read through a
gitignored `android/key.properties`. **Back both up plus their passwords now.**
Losing a keystore means no further updates to that app on Play.

## 3. Deploy the website

`website/` is static output; there is no build step at the host.

1. `cd website && python3 build.py` (regenerates all 29 pages, `robots.txt` and
   `sitemap.xml` from `seo-config.json`, whose `site_url` is
   `https://dinecircle.app`). To publish a different origin, set
   `DINECIRCLE_SITE_URL` or edit `seo-config.json`, then rebuild.
2. Upload the HTML, `assets/`, `robots.txt`, `sitemap.xml`, `_headers` and
   `_redirects` to any static host (Netlify, Cloudflare Pages and Render Static
   Sites all read the last two). Point `dinecircle.app` **and**
   `www.dinecircle.app` at it; `_redirects` folds www and HTTP onto the
   canonical HTTPS origin.
3. Do not upload `build.py`, `seo.py`, `seo-config.json` or `SEO.md`; they are
   build tooling, not the site.
4. After it is live: register the property in Google Search Console, submit
   `/sitemap.xml`, and spot-check one page in the Rich Results Test.
5. Verify the CSP that `_headers` installs actually suits the site:
   ```bash
   curl -I https://dinecircle.app/ | grep -i "content-security\|strict-trans"
   ```
   Then load the page and watch the console for blocked requests. The policy is
   tight (`default-src 'self'`, only Google Fonts allowed cross-origin), which
   matches what the pages do today: no inline handlers, no fetch calls.

## 4. Post-deploy checks

```bash
curl -s  https://dinecircle-api.onrender.com/api/health                 # 200, database up
curl -s  https://dinecircle-api.onrender.com/api/restaurants            # 401, auth is enforced
curl -s -H "Origin: https://evil.example" \
     -o /dev/null -w "%{http_code}\n" \
     https://dinecircle-api.onrender.com/api/health                     # 403, CORS allowlist works
curl -s -o /dev/null -w "%{http_code}\n" https://dinecircle.app/        # 200
```

Then install both APKs on a phone, sign in, and exercise one booking end to end
before announcing anything.

## Known outstanding issues

- **Partner test suite is not green, and none of the failures come from the
  Business workspace redesign.** Verified against git provenance:

  | Failures | Cause | Owner |
  | --- | --- | --- |
  | 11 × `test/integration/api_integration_test.dart` | Need a server on `localhost:4000`; none is running | Environmental |
  | 7 × `test/widget/home_screen_test.dart` | `pumpAndSettle` never returns: `Timer.periodic` at `home_screen.dart:113` and `Stream.periodic` at `home_hero.dart:501` keep animating. The last test in the file never completed and flooded 400 MB of log. Files last touched before this work | Pre-existing |
  | 6 × `test/widget/menu_tab_test.dart` | Expect text `STARTERS`; menu screens last touched before this work | Pre-existing |

  `test/widget/deals_tab_test.dart` did fail to compile (its fake `Repo.updateDeal`
  was missing the `kind` parameter the real repository now takes). That one is
  fixed. Everything touched by the redesign now passes: `workspace_tab_test.dart`
  (6 new), `profile_tab_test.dart`, `app_shell_test.dart`, `qr_tab_test.dart`,
  `premium_cards_test.dart`, `brand_test.dart`, `deals_tab_test.dart`.

- `home_screen_test.dart` can hang a full-suite run and write a huge log. Prefer
  `flutter test <file>` with `--timeout=60s` over the bare `flutter test`.
- The site has no branded `404.html`; unknown paths show the host default page.
- Footer social icons are suppressed rather than pointed at platform
  homepages. Add real profile URLs to `SOCIAL` in `website/build.py` to bring
  them back.
- `API_TIMEOUT_MS` is still present in both `dart-defines.json` files but no
  longer read by the customer app.
