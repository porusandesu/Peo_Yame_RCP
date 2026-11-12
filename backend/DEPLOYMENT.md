# Backend deployment

Run `npm install` then `npm start`. The default listener uses loopback. Set `HOST` and `PORT` for a controlled private network deployment and set `PEO_YAME_DATA_DIR` to a persistent data directory. Enable the temporary Guided Demo endpoints only with `PEO_YAME_DEMO_ENABLED=true`.

## Database encryption key

The backend requires `PEO_YAME_DB_KEY` to be a 64-character hexadecimal
encoding of a random 256-bit key. Generate it with a cryptographically secure
secret manager or, for a local deployment, `openssl rand -hex 32`. Store it in
the deployment's secret manager and provide it to the process environment; do
not commit it, put it in a command-line argument, or write it to application
logs. Keep the same key across restarts. A missing, malformed, or incorrect key
prevents the backend from opening the database.

On the first start with an existing plaintext SQLite database, the backend
rekeys that database in place. Stop the old application and make a protected
backup before upgrading. Keep the backup encrypted and preserve its matching
key separately. For a consistent manual file backup, stop the backend first,
then copy `peo-yame.sqlite`; do not copy a live WAL database as a standalone
file. Restore by stopping the service, placing the database in
`PEO_YAME_DATA_DIR`, provisioning its original key, and starting the service.
An incorrect key is rejected; it does not create a replacement database.

The Windows installer stores its generated database key protected with Windows
DPAPI for the installing Windows user. Keep the Windows user profile and the
application data directory together when recovering that installation. The
installer's uninstall action leaves the data directory intact.

Plain HTTP is intended only for a controlled demonstration network. Use HTTPS
for deployment beyond that network. The Android client currently allows
cleartext traffic to support that documented LAN demo configuration.
