# Reproducible local browser smoke checks

Use the already installed Node 26 toolchain and Chrome; no Playwright/browser download is required.
Run from separate terminals. Never run the RSpec suite concurrently with a fixture server on the
same disposable database: specs deliberately clean their own data.

## Read-only smoke on the existing development dataset

Start normal local Rails 3000 and Vite 5173 per the root README. Start an isolated Chrome instance:

```sh
# macOS example; use your existing Chrome binary on another platform.
'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
  --headless=new --disable-gpu --no-first-run --no-default-browser-check \
  --user-data-dir=/tmp/acme-smoke-chrome --remote-debugging-port=9232 \
  --remote-debugging-address=127.0.0.1 about:blank
```

In `frontend/`:

```sh
node script/local-smoke.mjs
```

Defaults are frontend 5173, API 3000, CDP 9232, all loopback. The script verifies dashboard,
directory/search focus/continue/clear, filter/page reset, empty results, profile/history, filtered
CSV, mobile 390 and visible keyboard focus. It rejects remote origins, captures no keys/headers/body
values in output, and fails if a write occurs in read-only mode. A failure may leave the isolated
browser open for inspection; stop only your own Chrome/Vite process afterward.

## Disposable write/stale/long-history smoke

1. In a dedicated backend test terminal, run the database-free safety specs first. Then run
   `ruby script/prepare_test_database.rb` to create a **new** local target, and source the exact
   environment file it prints. Do not source it into the development server's shell.
2. Run the full specs if desired, then, with that same verified test environment, execute:

   ```sh
   bin/rails runner script/local_qa_fixture.rb
   ```

   It verifies the marker/owner through the same guard, refuses nonempty targets, creates 300
   synthetic employees and adds `QA-LOCAL-10001` (id 10001) with 1,000 contiguous records. It never
   alters development. If you need another clean run after writes, provision another **new** target;
   do not delete/reset user data to reuse this fixture.
3. Choose a temporary QA-only write key privately:

   ```sh
   read -r -s QA_WRITE_KEY
   export QA_WRITE_KEY
   DEMO_WRITE_KEY="$QA_WRITE_KEY" bin/rails server -b 127.0.0.1 -p 3102 -P /tmp/acme-qa-rails.pid
   ```

4. Stop your own previous Vite process, then start another frontend terminal:

   ```sh
   cd frontend
   VITE_API_BASE_URL=http://127.0.0.1:3102 npm run dev -- --host 127.0.0.1 --port 5173 --strictPort
   ```

5. Start the isolated Chrome above. In a separate smoke terminal, source the same test-target file
   and privately enter/export the same `QA_WRITE_KEY` (never a VITE variable). From `frontend/`:

   ```sh
   QA_API_ORIGIN=http://127.0.0.1:3102 QA_DISPOSABLE_WRITES=1 node script/local-smoke.mjs
   ```

   Writes require the explicit flag, test-target declaration, key, and the special fixture identity
   returned by the API. The script writes only that fixture, never seeded employee 1. It exercises
   required validation, 255 supplementary Unicode codepoints, real 401 clearing, successful revision,
   route-persistent memory-only key and independent edit→stale 409→explicit review/reset. All 1,000
   original history rows render; two test revisions make the later history length 1,002.

The script reports a navigation-to-render observation for the long table. This includes Vite/CDP
and polling overhead and is not an isolated React render benchmark. The current API timings and
response size are recorded in `final-local-qa.md`. Do not treat one local fixture as evidence that
unbounded history or a hosted instance has unlimited capacity.

## Human keyboard/accessibility checklist

- Tab from the browser content start to the skip link, navigation, filters and search; confirm a
  visible focus outline and that Enter/Space activates appropriate controls.
- Type, pause over 300 ms, continue typing without clicking; use Back/Forward and Clear.
- Tab to contained tables and scroll horizontally; verify columns remain readable on narrow screens.
- On the disposable revision page, submit missing fields, find labeled error messages, correct them,
  and use Cancel and the explicit stale-review button. Avoid write tests on development.
- Inspect 390px and desktop; check zoom, long names and large amounts manually as appropriate.
- If available, perform a real screen-reader review and record tool/version/results separately.

Automated checks confirm focus movement/styles and basic responsive containment; they do not
certify screen-reader behavior or every browser/device. G1, DR-20 and DR-22 remain unchanged.
