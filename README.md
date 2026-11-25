# zap2xml-js (container build)

The [jef/zap2xml](https://github.com/jef/zap2xml) engine (MIT, © Jeffrey LeCompte) packaged as an
Unraid-ready container. Same XMLTV output as running `node dist/index.js` on a desktop — the build in
`dist/` is byte-identical to upstream v2.2.0 apart from one added env override (see *Differences*).

It is fast because it asks Gracenote for **6 hours of grid per request** and fires the whole timespan
in parallel: a 15-day guide (`TIMESPAN=360`) is 60 requests and takes about 30 seconds.

## Image

```
ghcr.io/bob-walker-012/zap2xml-js:latest   (linux/amd64, linux/arm64)
ghcr.io/bob-walker-012/zap2xml-js:2.2.0
```

## Run

```bash
docker run -d --name zap2xml-js \
  -v /mnt/user/appdata/zap2xml-js:/data \
  -e LINEUP_ID=USA-lineupId-DEFAULT \
  -e POSTAL_CODE=00000 \
  -e TIMESPAN=360 \
  -e TZ=America/Denver \
  ghcr.io/bob-walker-012/zap2xml-js:latest
```

Output: `/data/xmltv.xml` (plus `status.json`).

## Environment

| Variable | Default | Meaning |
| --- | --- | --- |
| `LINEUP_ID` | `USA-lineupId-DEFAULT` | Lineup, e.g. `USA-XXXXX-X`; the OTA placeholder works with a postal code |
| `POSTAL_CODE` | `30309` | ZIP / postal code for provider lookup |
| `COUNTRY` | `USA` | `USA` or `CAN` |
| `TIMESPAN` | `6` | Hours of guide per run (360 = 15 days) |
| `PREF` | *empty* | `m` music, `p` PPV, `h` HD — comma separated |
| `USER_AGENT` | *random* | Pin a UA instead of a random real browser one per run |
| `OUTPUT_FILE` | `/data/xmltv.xml` | Guide path (keep it under `/data`) |
| `SLEEP_TIME` | `21600` | Seconds between runs |
| `RUN_ONCE` | `false` | One grab then exit (CI / manual test) |
| `PUID` / `PGID` / `UMASK` | `99` / `100` / `022` | Unraid ownership of the output |
| `TZ` | `America/New_York` | Container timezone |

## Unraid

```bash
wget -O /boot/config/plugins/dockerMan/templates-user/my-zap2xml-js.xml \
  https://raw.githubusercontent.com/bob-walker-012/zap2xml-js/master/unraid/zap2xml-js.xml
```

Docker → Add Container → **zap2xml-js**. Fill in `POSTAL_CODE` (and `LINEUP_ID` if you know it), Apply.
Guide appears at `/mnt/user/appdata/zap2xml-js/xmltv.xml`.

## Watching it work

```bash
docker logs -f zap2xml-js
```
```
[2026-11-25 12:40:02 MST] Starting grab (lineup=USA-lineupId-DEFAULT, postal=00000, 360h)
[2026-11-25 12:40:31 MST] Guide ready: 98 channels, 48422 programmes, 25M in 29s
[2026-11-25 12:40:31 MST] Next run in 21571s
```

`/data/status.json` carries the same information for scripts. The container healthcheck is green while
the guide exists, parses as XMLTV, and is younger than two refresh cycles.

## Differences from upstream

1. `ZAP2XML_BASE_URL` overrides the API base URL — CI points it at a fixture server so the image can be
   tested without hitting Gracenote (whose CDN blocks datacenter IPs).
2. The entrypoint writes to `.xmltv.tmp` and renames on success, so a failed grab never replaces a good
   guide, and stamps `status.json`.
3. Runs as root to `chown` `/data`, then drops to `PUID:PGID`.

Everything else — request shape, parsing, XMLTV layout — is upstream code, unmodified.

## Licence

MIT, see [LICENSE](LICENSE). Upstream: https://github.com/jef/zap2xml