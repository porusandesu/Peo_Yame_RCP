# Backend deployment

Run `npm install` then `npm start`. The default listener uses loopback. Set `HOST` and `PORT` for a controlled private network deployment and set `PEO_YAME_DATA_DIR` to the persistent data directory. Enable the temporary Guided demo endpoints only with `PEO_YAME_DEMO_ENABLED=true`.

Plain HTTP is intended only for a controlled demonstration network. Use HTTPS for deployment beyond that network. The Android client currently allows cleartext traffic to support that documented LAN demo configuration.
