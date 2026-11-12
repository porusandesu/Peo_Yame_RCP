# Peo Yame presenter script (11 minutes)

Use the Windows launcher and Android app on the same controlled Wi-Fi network.
This script uses the Instant Demo first, then a single Showcase account shared
between web and mobile. All readings and alerts are simulated; SMS is not sent.

## Before the audience arrives (2–3 minutes)

1. In the Windows notification-area menu, turn on **Demo mode**. Confirm the
   dashboard says Guided Demo is enabled. If it is off, the optional installer
   shortcut or `--demo` launch can enable it.
2. Open Android and choose **Demo mode**. Confirm Overview shows the shared
   simulated readings. Keep mobile **Settings → Before you present** open long
   enough to inspect the masked detected address and session status.
3. Keep the computer and phone on the same Wi-Fi. Accept the Windows Firewall
   prompt if shown. Do not use an untrusted public network.

## Presentation steps

| Time | Show and say | Expected result |
|---|---|---|
| 0:00–0:40 | **Welcome.** “Peo Yame gives a farmer a single place to review storage conditions, trends, locations, and alerts. I’ll show simulated data; this prototype is not connected to a physical sensor.” | The sign-in page offers **Demo mode**, account entry, and QR sign-in. Android Welcome has no backend-address control. |
| 0:40–1:35 | **Instant Demo Overview.** “This is an account-free preview. The reading is simulated, and the status compares it with the selected crop’s target band; it does not inspect the crop.” Point to the reading-age caption, status text, target band, and rough-estimate disclaimer. | Temperature/humidity and the age caption update as the shared feed appends readings. The status says **In range** or **Outside target band**. |
| 1:35–2:25 | **Trends.** “The same shared sample can be reviewed over a day, a month, or three months. The shaded band is the crop target; the figures remain estimates from synthetic readings.” Switch all three ranges and point out timestamps and the axis units. | Both charts show the selected interval, target-band shading, plain numeric ticks, and low/high summaries. |
| 2:25–3:05 | **Alerts and crop choice.** Switch to Alerts, then return to Overview and change the selected crop. “The alert list is a simulated history, and switching crops changes the comparison band only for this preview.” | Alerts are labelled simulated and say SMS is not sent. The status and trend band follow the crop selected on this device. |
| 3:05–3:35 | **Guided Demo setup.** From web, choose **Start Guided Demo → Showcase**. “Showcase starts with example storage locations, linked sensors, and reviewed alert history. The temporary password is shown once so normal re-checks remain possible.” Save the password securely for this session. | Showcase opens with populated My Crops and Alerts. Its session is temporary and the simulator remains stopped until started. |
| 3:35–4:35 | **Connect Android to the same account.** In web Settings choose **Connect phone by QR**. On Android use the sign-in QR action, scan, compare the match number, and approve on the computer. “The match number and explicit approval help prevent approving an unexpected request.” | Android receives a separate session for the same Guided Demo account. Do not start a second Guided Demo on the phone; that would create a different account. |
| 4:35–6:10 | **Locations and sensors.** On either device open My Crops. Show two storage locations, their crops, linked synthetic sensors, and the extra unlinked sensor. “These are records in the demo account, not discovered hardware.” | The location/sensor counts and simulated labels agree across paired devices. |
| 6:10–7:30 | **Changing readings and sync.** In Settings → Demo tools start the simulator. Keep both devices visible and return one to Overview, the other to Trends. “A new simulated reading is written every three seconds. The paired screens refresh from the same account.” | The reading age resets and temperature/humidity vary; the trend line advances on both sessions. The first reading is in-band. |
| 7:30–8:25 | **Alert handling.** Wait for the scheduled simulated breach or use **Simulate breach**. Open Alerts and review it; optionally use **Return to in-band**. “This is an app alert record only. No SMS or physical sensor action occurs.” | The alert is labelled simulated, can be reviewed, and updates across paired sessions. |
| 8:25–9:15 | **Account-backed walkthrough.** Show Settings refresh, CSV/Markdown export, active sessions, and authenticator setup without enabling or resetting security features unless appropriate for the presentation. Point out the automatic-alert switch and manual sensor-reading control. | Refresh is a fetch action; the simulator and event sync are separate. Security actions require normal credentials and authenticator checks. |
| 9:15–10:00 | **QR security and presenter checks.** Show the masked network address in the approval/preflight UI, reveal it deliberately, then hide it. “The backend reports the address and active sessions; it cannot tell whether this phone can reach the computer.” | The address is partially masked by default. The preflight explicitly says phone reachability is **Not verified from the backend**. |
| 10:00–11:00 | **Close.** Stop the simulator. “These screens demonstrate how the workflow behaves with generated data. Storage estimates are rough and must not replace manual crop checks.” Leave the demo account available for questions, or use **Reset demo** if it should be deleted. | Simulator stops for both paired sessions. Reset deletes the temporary profile and returns to Instant Demo. |

## Recovery when something goes wrong

- **Phone cannot reach the computer:** verify both devices are on the same Wi-Fi,
  reveal the address only long enough to check it, and accept the Windows
  Firewall prompt. Use the backend QR/manual address entry if the phone is
  connected to a different backend. The preflight cannot verify reachability.
- **Camera permission denied or no camera:** choose **Enter code manually** on
  the scanner screen and type the displayed short pairing code or backend
  address. If needed, allow camera access from Android Settings and retry.
- **QR code expired or already used:** request a new QR. Pairing codes expire
  after 90 seconds and work once. Do not keep retrying an old code.
- **Wrong match number:** re-check the number shown on the other device. The
  flow limits attempts; if it locks or expires, cancel and create a fresh code.
- **Guided Demo timed out:** the session has a two-hour absolute lifetime and a
  30-minute idle limit. Start a new Guided Demo and pair the phone again. The
  old temporary data is not a recovery backup.
- **Simulator appears paused:** use Settings → Demo tools → **Start simulated
  readings**. Instant Demo has no simulator control; its shared feeder runs
  only while anonymous clients are active.

## Manual checks still needed

Retake screenshots for web sign-in, Overview, Trends, My Crops, Alerts, and
Settings, plus the same five Android tabs. Confirm the camera permission prompt,
Flow A and Flow B approval, keyboard/screen-reader usability, Windows Firewall
behavior, and real-device Wi-Fi reachability. These are **Not verified** until
observed on the presentation devices.
