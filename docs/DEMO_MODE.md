# Demo mode

## What the two demo modes do

**Instant Demo** is an account-free preview. It reads shared synthetic
temperature, humidity, trend, and alert data. On backend startup the sample
history is filled with hourly points for up to 90 days. While an anonymous
client is active, the backend appends a varied simulated reading every 10
seconds, publishes a reading event, prunes data older than 90 days, and caps
the shared history. A request after a quiet period wakes the feed with a fresh
reading when the newest point is older than 10 seconds. The feed does not
create alerts. Crop selection is local to each anonymous client; the shared
sample is not changed for everyone when one presenter switches crops.

Instant Demo is read-only except for selecting a crop. It cannot add locations
or crops, link sensors, review alerts, create demo checklist entries, or use
account/security features. Screens that need an account explain that boundary
and offer Guided Demo when it is enabled.

**Guided Demo** creates a temporary account with a separate dataset. Its
session expires after two hours absolute or 30 minutes idle. Reset removes
the temporary account and its data. It does not start the simulator by itself.
The generated password is shown once so normal password and authenticator
re-checks remain possible for pairing.

Guided Demo is off by default. On Windows, enable it explicitly through the
notification-area **Demo mode** checkbox, launch with `--demo`, or choose the
optional installer shortcut **Peo Yame (Demo mode)**. The installer option is
unchecked by default. An explicit `PEO_YAME_DEMO_ENABLED` environment setting
takes precedence. With Guided Demo off, its API returns 404 and the web and
mobile Settings screens explain how to enable it.

## Guided Demo profiles

- **Showcase** is preselected. It seeds two example locations, two linked
  synthetic sensors, one unlinked sensor, 30 days of hourly synthetic history
  for both locations, and reviewed historical alerts. The tabs have useful
  content as soon as the profile starts.
- **Walkthrough** starts with no locations, one unlinked `PY-DEMO-1` sensor,
  and 30 days of hourly synthetic history. Use it to demonstrate creating a
  location and linking a sensor.

All readings and alerts are explicitly synthetic. Neither profile discovers
physical sensors or sends SMS.

## Simulation and synchronized views

The presenter starts the simulator manually from Settings → Demo tools. It
writes an immediate in-band reading, then a new varied temperature/humidity
reading every three seconds. The readings are shared by all sessions for that
temporary account and update Overview, Trends, My Crops, and Alerts through
server-sent events. A first automatic out-of-band point occurs on the sixth
reading. Automatic breach alerts default to on; a pending unreviewed alert
prevents another automatic alert until it is reviewed. The presenter can turn
automatic alerts off, manually simulate a breach or sensor reading, and
return readings to the crop's target band. A simulated offline control affects
only that client's event connection.

The sample and simulator show target-band comparisons, not crop safety.
Estimate values are rough, unvalidated ranges based only on temperature and
humidity; follow the manual crop-check reminder.

To share one Guided Demo between web and mobile, pair the second device with
the temporary account:

- From web Settings, use **Connect phone by QR**; scan on the phone and approve
  the match number on the computer (Flow A).
- From mobile Settings, use **Log in on computer**; scan the browser QR, type
  the number displayed in the browser, and confirm the request on the phone
  (Flow B).

Starting Guided Demo separately on both devices creates separate accounts.
It does not synchronize their data.

## Guide and presenter preflight

The **Demo guide** button stays available on every demo screen. Its Part A
steps cover the shared preview; Part B covers the account-backed walkthrough.
Each step includes a presenter prompt, expected result when supplied by the
backend, and a **Take me there** action. It navigates only; it does not perform
security-sensitive actions for the presenter. Server-detectable progress is
shown automatically, with manual completion retained for client-only steps.

Settings → **Before you present** reports whether Guided Demo is enabled,
whether the simulator is running, the active session count for the current
demo account, and the backend-detected network address (masked until revealed).
The app cannot prove that a phone can reach that address; it says **Not
verified from the backend**. Keep both devices on the same Wi-Fi, allow the
Windows Firewall prompt, and use plain HTTP only on a controlled network.

Guided Demo's expiry countdown is based on the absolute session expiry. The
backend still enforces the two-hour absolute and 30-minute idle limits; an
open event stream counts as activity only if the backend records the session
request as active.

## QR and connection notes

- **Flow A — computer connects a phone:** the computer re-checks the account
  password and enabled authenticator code. The phone scans the 90-second
  one-time QR, confirms a backend change if needed, claims with a
  verifier-bound request, and waits for explicit computer approval.
- **Flow B — phone approves a computer sign-in:** the browser displays a
  90-second QR and match number. A signed-in phone scans it, displays a partial
  network address by default, asks the farmer to enter the browser's number,
  requires device authentication, and then approves or denies.
- **Backend connection QR:** Settings can show an address-only QR without a
  session token or pairing code. Mobile validates the address and asks before
  switching. Backend configuration is not shown on the Android Welcome page;
  its QR sign-in path accepts a backend QR or a manually entered address/code.
- **Finding the backend QR:** on the PC web dashboard, choose **Demo mode**
  from the welcome screen, then open Settings → **Backend connection** →
  **Show backend connection QR**. On Android Welcome, tap **Scan sign-in or
  backend QR** and allow camera access. The Android emulator default
  `10.0.2.2:3000` is not the physical phone's PC address; use the QR to get the
  correct private-network address and port.
- **Address privacy:** network addresses are partially hidden by default in
  approval prompts and presenter preflight. Reveal is an explicit user action.

## Evidence and known limits

- **Source inspection:** the `exe-work` changes at `ef61f46` add explicit
  tray web-app launch, Guided Demo pairing guidance, phone-side QR failure
  handling, and integration coverage for both QR directions and live sync.
- **Automated test:** GitHub Actions run
  [v128](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43309830523)
  passed backend API tests, Android tests/analyze/release packaging, and
  Windows launch, restart, installer, and encrypted-storage checks. The
  integration test exercises both QR directions and cross-session live sync.
- **Manual observation:** Windows tray use, QR camera prompts, visual layout,
  screen-reader/keyboard behavior, and real Wi-Fi reachability remain **Not
  verified**.

Use `DEMO_SCRIPT.md` for a timed presentation and recovery steps.
