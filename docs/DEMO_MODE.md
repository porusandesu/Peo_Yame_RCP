# Demo mode

## Modes

**Instant Demo** is the no-account preview. It reads the backend's shared,
synthetic sample readings (`user_id IS NULL`) and cannot be used to showcase
account-isolated features. Its sample history is seeded when the backend has no
shared readings; it does not continuously generate new readings.

**Guided Demo** creates a temporary demo user and a separate data set each time
it starts. The profile includes Maize and Sorghum storage locations, a
simulated `PY-DEMO-1` sensor linked to the Maize store, and 25 historical,
timestamped synthetic readings. The session expires after two hours absolute
or 30 minutes idle. Reset deletes the temporary user, its readings and alerts,
and stops its live simulator. The temporary phone and password are not intended
for reuse; use the in-app QR flows to join the same demo profile on another
device.

Neither mode connects to physical sensors or sends SMS. Readings, sensor
activity, and alerts are labeled as simulated.

## Live simulation and cross-device sync

The guided demo's **Start live simulation** action starts one backend
simulation for that temporary user. It writes an immediate reading and then
adds a new timestamped synthetic sensor reading every 10 seconds. The
simulated sensor's last-seen time is updated, so the sensor appears online.
Overview, Trends, My Crops, and Alerts refresh when their data changes.

The web and mobile clients receive user-scoped server-sent events. To see the
same live data on both:

- Start Guided Demo on one device.
- On the other device, sign in to that same temporary profile by QR: use
  **Connect phone by QR** from the web Settings when the web started the demo,
  or use the web sign-in QR and **Log in on computer** from mobile Settings
  when mobile started it.
- Start the live simulation from either device. The other signed-in device
  receives the same readings and updates its visible screen.

For a temporary demo profile, creating a phone QR skips the password
re-check because its generated password is not available to the user. The
one-time code, short expiry, match-code verification, and explicit approval
remain in place. Normal accounts still require password re-authentication.

Starting Guided Demo independently on both devices creates two different
temporary users, so their readings do not sync. Starting the simulation again
for the same user is idempotent. Either device can stop it for both. The
simulator also stops after reset, when no valid demo session remains, or when
the backend process restarts.

## Guided Demo controls

- **Start/stop live simulation:** stream new synthetic readings at 10-second
  intervals and synchronize them to all connected sessions for the demo user.
- **Simulate sensor reading:** write one additional synthetic reading.
- **Simulate breach:** create an out-of-band reading and a simulated alert.
- **Switch crop:** change the selected crop and its target-band interpretation.
- **Simulate network loss:** disconnect that client's event stream to present
  offline behavior; it does not disable the server-side simulator.
- **Reset demo:** stop the simulator, delete the temporary demo data, and
  return to the no-account preview.

## Implementation and verification

The live simulator, QR sharing, event-driven screen refresh, and demo-session
idle policy are implemented in the active source. GitHub Actions v103 passed
backend tests for live reading generation and delivery to a second QR session,
as well as Android and Windows checks. GitHub Actions v104 verified that
QR-created demo sessions have the demo profile's two-hour absolute lifetime.
Visual presentation and physical-device behavior have not yet been manually
verified.
