# Demo mode

## Modes

**Instant Demo** is the no-account preview. It reads the backend's shared,
synthetic sample readings (`user_id IS NULL`) and cannot be used to showcase
account-isolated features. Its sample history is seeded when the backend has no
shared readings; it does not continuously generate new readings.

**Guided Demo** creates a temporary demo user and a separate data set each time
it starts. It begins with no storage locations, one unlinked synthetic
`PY-DEMO-1` sensor, and 25 historical, timestamped synthetic readings. This
lets the presenter demonstrate adding a location and linking a sensor. The
generated password is shown once in the app; only its salted hash is stored.
The session expires after two hours absolute or 30 minutes idle. Reset deletes
the temporary user, its readings and alerts, and stops its live simulator.
Use the in-app QR flows to join the same demo profile on another device.

Neither mode connects to physical sensors or sends SMS. Readings, sensor
activity, and alerts are labeled as simulated.

## Live simulation and cross-device sync

The guided demo's **Start live simulation** action starts one backend
simulation for that temporary user. It writes an immediate reading and then
adds a new timestamped synthetic sensor reading every 3 seconds. Temperature
and humidity vary at each tick; every sixth reading is pushed beyond a
selected crop's target band when an out-of-band sensor value is available.
An out-of-band reading creates an account-scoped simulated alert and emits an
alert event. Another synthetic alert is held back while an earlier one is
unreviewed. The simulated sensor's last-seen time is updated, so the sensor
appears online. Overview, Trends, My Crops, and Alerts refresh when their
data changes.

The web and mobile clients receive user-scoped server-sent events. To see the
same live data on both:

- Start Guided Demo on one device.
- On the other device, sign in to that same temporary profile by QR: use
  **Connect phone by QR** from the web Settings when the web started the demo,
  or use the web sign-in QR and **Log in on computer** from mobile Settings
  when mobile started it.
- Start the live simulation from either device. The other signed-in device
  receives the same readings and updates its visible screen.

Creating a phone QR for Guided Demo uses the same password re-check as a
normal account. The presenter can use the generated password shown once when
Guided Demo starts; if an authenticator is enabled, its current code is also
required. The one-time code, short expiry, match-code verification, and
explicit approval are not bypassed.

## QR and backend connection

- **Connect phone by QR (Flow A):** an authenticated computer re-checks the
  password and, when enabled, the authenticator code. The phone scans the
  90-second QR, confirms a backend switch if needed, claims it with a
  verifier-bound request, and displays the match number. The computer
  approves or denies; approval creates a separate phone session.
- **Sign in on computer (Flow B):** the browser displays a 90-second QR and
  match number. A signed-in phone scans it, confirms the number with the
  presenter, and requires device authentication before approving. The browser
  redeems its verifier for its own session.
- **Backend connection QR:** Settings can display an address-only QR with no
  session token or pairing code. Mobile validates the address, asks before
  switching backends, checks the health endpoint, then saves it. The mobile
  app also allows the address to be entered manually in Settings. Backend
  setup is not shown on the mobile Welcome screen; its QR sign-in action can
  scan either a sign-in code or a backend connection QR for first-time setup.
- **Network address privacy:** backend addresses in mobile Settings and the
  web backend QR panel are masked by default. Flow A and Flow B approval
  dialogs also hide the other device's network address until the user chooses
  to reveal it. A backend connection QR still encodes the address needed to
  connect.
- **Custom crops:** My Crops lets an account add a crop, fruit, or vegetable,
  set its target bands and rough-estimate baseline, and select it immediately.
- Both sign-in flows accept the short manual pairing code. Camera permission
  is requested after an explanation; denial offers app Settings and manual
  entry. Canceling a phone claim notifies the computer and closes its approval
  prompt.

Starting Guided Demo independently on both devices creates two different
temporary users, so their readings do not sync. Starting the simulation again
for the same user is idempotent. Either device can stop it for both. The
simulator also stops after reset, when no valid demo session remains, or when
the backend process restarts.

## Guided Demo controls

- **Start/stop live simulation:** stream new synthetic readings at 3-second
  intervals and synchronize them to all connected sessions for the demo user.
- **Refresh demo data:** use the manual refresh action in Settings on web or
  mobile to fetch the latest server state. This does not create a reading or
  change the simulator; live events and polling continue automatically, and
  mobile also retains pull-to-refresh.
- **Automatic demo alerts:** changing simulated readings cross the selected
  crop's band and create a reviewable simulated alert.
- **Simulate sensor reading:** write one additional synthetic reading.
- **Simulate breach:** create an out-of-band reading and a simulated alert.
- **Switch crop:** change the selected crop and its target-band interpretation.
- **Simulate network loss:** disconnect that client's event stream to present
  offline behavior; it does not disable the server-side simulator.
- **Reset demo:** stop the simulator, delete the temporary demo data, and
  return to the no-account preview.

## Implementation and verification

The live simulator, QR sharing, event-driven screen refresh, and demo-session
idle policy are implemented in the active source. GitHub Actions v112 (run
[`43222452877`](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43222452877),
commit `c806d9a`) passed backend API tests, Android tests/analysis/release APK,
and Windows launch/lifecycle/installer acceptance. Backend coverage includes
the 3-second interval, changing temperature and humidity, generated demo
alerts, and QR-shared live readings. Artifacts `Peo Yame v112 Android` and
`Peo Yame v112 Windows` were uploaded. Visual presentation, camera
permissions, physical-device behavior, and real Wi-Fi reachability have not
been manually verified.

The web and mobile Settings screens now present sync status and controls in
organized sections/cards, with the manual refresh action in Settings rather
than the mobile app bar. GitHub Actions v114 (run
[`43224956617`](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43224956617),
commit `f73378d`) passed backend API tests, Android tests/analysis/release APK,
and Windows launch/lifecycle/installer checks. Visual and accessibility
review on real devices and browsers remains outstanding.
