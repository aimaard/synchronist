![Diagram](doc/logo.png)

[![Rails](https://github.com/aimaard/synchronist/actions/workflows/rails.yml/badge.svg)](https://github.com/aimaard/synchronist/actions/workflows/rails.yml)

Synchronist is mirroring/sync tool which allows to send increments without having an active connection between them.

## How does it work?

Synchronist runs on both ends, once as **receiver** and once as **sender**:

1. The **receiver** regularly writes a so-called payload: the list of all files (and their modification times) in its storage folder.
2. The payload needs to get to the sender (not covered by synchronist, e.g. a data diode or a shared folder).
3. The **sender** notices the new payload, compares it with its source folder and puts all missing/changed files into the send folder.
4. The files in the send folder need to get to the receiver's receive folder (again not covered by synchronist).
5. The **receiver** notices the incoming files and moves them into its storage folder as soon as they're completely written.

Incoming files and payloads are picked up immediately: Synchronist watches the folders for changes (using inotify) instead of
checking them every minute. A file is only processed once its size and modification time didn't change for a few seconds,
so big files that are still being copied aren't picked up too early (or multiple times).

## Installation

Synchronist is distributed as a single [docker](https://docs.docker.com/get-docker/) image (podman works too) for
`linux/amd64` and `linux/arm64`: `ghcr.io/aimaard/synchronist`. It doesn't need any other services: Everything is stored
in SQLite databases inside the `/synchronist/storage` volume.

The image is tagged with each release version (see [Releases](https://github.com/aimaard/synchronist/releases)) and
`latest` for the newest release. The examples use `latest`, pin a version (e.g. `ghcr.io/aimaard/synchronist:1.0.0`) to
control when you upgrade.

The folders synchronist works with are mounted into the container under `/data`:

| Mode     | Container folder | Host folder to mount                                     |
|----------|------------------|----------------------------------------------------------|
| receiver | `/data/storage`  | The mirror, holding all files received so far            |
| receiver | `/data/receive`  | Where the files from the sender arrive                   |
| receiver | `/data/payload`  | Where the payload for the sender is written to           |
| receiver | `/data/relay`    | Optional: Also copy all received files into this folder  |
| sender   | `/data/source`   | The folder to mirror                                     |
| sender   | `/data/send`     | Where the missing/changed files for the receiver are put |
| sender   | `/data/payload`  | Where the payload from the receiver arrives              |

### Quick start with docker run

Receiver:

```bash
docker run -d --name synchronist --restart always -p 3000:3000 \
  -e SYNCHRONIST_MODE=receiver -e SYNCHRONIST_PASSWORD=change-me \
  -v synchronist:/synchronist/storage \
  -v /srv/mirror:/data/storage -v /mnt/from-sender:/data/receive -v /mnt/to-sender:/data/payload \
  ghcr.io/aimaard/synchronist:latest
```

Sender:

```bash
docker run -d --name synchronist --restart always -p 3000:3000 \
  -e SYNCHRONIST_MODE=sender -e SYNCHRONIST_PASSWORD=change-me \
  -v synchronist:/synchronist/storage \
  -v /srv/mirror:/data/source -v /mnt/to-receiver:/data/send -v /mnt/from-receiver:/data/payload \
  ghcr.io/aimaard/synchronist:latest
```

Then open http://localhost:3000 and log in with the user `synchronist` and your password.

### docker compose

The same receiver as `docker-compose.yml`:

```yaml
services:
  synchronist:
    image: ghcr.io/aimaard/synchronist:latest
    restart: always
    ports:
      - "3000:3000"
    environment:
      SYNCHRONIST_MODE: receiver
      SYNCHRONIST_PASSWORD: change-me
      # Optional, see "Configuration" below
      SYNCHRONIST_SYNC_CRON: "0 */6 * * *"
    volumes:
      - synchronist:/synchronist/storage
      - /srv/mirror:/data/storage
      - /mnt/from-sender:/data/receive
      - /mnt/to-sender:/data/payload

volumes:
  synchronist:
```

Start it with `docker compose up -d`, upgrade with `docker compose pull && docker compose up -d`.

### Install script

The install script asks a few questions and creates the `docker-compose.yml` and a systemd service in the current folder:

```bash
mkdir /opt/synchronist && cd /opt/synchronist
bash -c "$(curl -fsSL https://raw.githubusercontent.com/aimaard/synchronist/main/setup-deployment.sh)"

systemctl enable --now synchronist
```

Without internet access, save the image on a machine with internet access:

```bash
docker pull ghcr.io/aimaard/synchronist:latest
docker save -o synchronist.tar ghcr.io/aimaard/synchronist:latest
```

Copy the repository and `synchronist.tar` to the machine and run `setup-offline-deployment.sh` from the folder
containing the `.tar` file. It loads the image into docker.

You also might wanna put this behind a reverse proxy to support https, I recommend using [nginx-proxy](https://github.com/nginx-proxy/nginx-proxy).

## Configuration

Synchronist is configured with environment variables. The "Configuration" page in the web interface shows the current
configuration and what's missing or wrong. Restart the container after changing them.

| Variable                      | Default                             | Description                                                                        |
|-------------------------------|-------------------------------------|------------------------------------------------------------------------------------|
| `SYNCHRONIST_MODE`            |                                     | **Required**: `sender` or `receiver`                                               |
| `SYNCHRONIST_PASSWORD`        |                                     | **Required**: Password for the web interface                                       |
| `SYNCHRONIST_USERNAME`        | `synchronist`                       | Username for the web interface                                                     |
| `SYNCHRONIST_SYNC_CRON`       | `0 */6 * * *`                       | Receiver: How often to send a payload to the sender ([cron](https://crontab.guru)) |
| `SYNCHRONIST_RELAY_FOLDER`    |                                     | Receiver: Also copy all received files into this folder, e.g. `/data/relay`        |
| `SYNCHRONIST_SETTLE_SECONDS`  | `10`                                | How long an incoming file must stay unchanged before it's processed                |
| `SYNCHRONIST_WATCHER_POLLING` | `false`                             | Set to `true` for mounted network shares and Docker Desktop (see below)            |
| `SYNCHRONIST_PAYLOAD_PATH`    | `/data/payload/payload.synchronist` | Payload file                                                                       |
| `SYNCHRONIST_STORAGE_FOLDER`  | `/data/storage`                     | Receiver: Storage folder                                                           |
| `SYNCHRONIST_RECEIVE_FOLDER`  | `/data/receive`                     | Receiver: Receive folder                                                           |
| `SYNCHRONIST_SOURCE_FOLDER`   | `/data/source`                      | Sender: Source folder                                                              |
| `SYNCHRONIST_SEND_FOLDER`     | `/data/send`                        | Sender: Send folder                                                                |
| `RAILS_TIMEZONE`              | `Europe/Zurich`                     | Time zone used in the web interface                                                |

The folder defaults are set in the docker image, there's no need to change them when mounting the folders under `/data`.

### Network shares and Docker Desktop

Synchronist is notified about new files by the Linux kernel (inotify). This works for local folders, docker volumes and
folders this machine shares with others (e.g. with Samba) on a Linux host. It doesn't work reliably for:

- Network shares (SMB/CIFS, NFS) that are *mounted* on this machine and written to by other machines, the kernel doesn't see these changes.
- Folders of a macOS/Windows host mounted with Docker Desktop.

Set `SYNCHRONIST_WATCHER_POLLING=true` in these cases to check the incoming folder for changes every second instead.

## Operations

- Background jobs can be inspected under `/jobs` (or "Jobs" in the sidebar).
- `/up` is a health check (used by the docker `HEALTHCHECK`), it doesn't require a login.
- Back up the `/synchronist/storage` volume to back up synchronist. It contains the SQLite databases (`production.sqlite3`,
  `production_queue.sqlite3` for [Solid Queue](https://github.com/rails/solid_queue) and `production_cable.sqlite3` for
  [Solid Cable](https://github.com/rails/solid_cable)) and the `secret_key_base` generated on the first start (set `SECRET_KEY_BASE` to use your own).
- Everything runs in a single process: The web server, the background jobs (Solid Queue Puma plugin) and the folder watcher.

### Upgrading from 1.0.0.beta or 1.0.0.beta2

Earlier versions stored their data in PostgreSQL and Redis and were configured in the web interface. When upgrading:

- Use the `ghcr.io/aimaard/synchronist` image, new versions aren't published to Docker Hub (`siegy22/synchronist`) anymore.
- Configure synchronist with the environment variables above and mount the folders under `/data` (or set the folder variables to the paths used before).
- Remove the `DATABASE_URL` and `REDIS_URL` environment variables (`DATABASE_URL` would override the SQLite configuration).
- Remove the `postgres`, `redis` and `synchronist-worker` services and the `depends_on` section.
- `SYNCHRONIST_CHECK_PAYLOAD_CRON` and `SYNCHRONIST_CHECK_RECEIVED_FILES_CRON` aren't used anymore, the folders are watched instead.

The history of syncs/payloads is not migrated.

## Releasing

Releases are created by pushing a git tag named after the version:

```bash
git tag 1.0.0
git push origin 1.0.0
```

The [Release workflow](.github/workflows/release.yml) then runs the tests, builds the image for `linux/amd64` and
`linux/arm64`, pushes it to `ghcr.io/aimaard/synchronist` tagged with the version and `latest`, and creates a GitHub release
with generated release notes. Tags containing `alpha`, `beta` or `rc` (e.g. `1.0.0.beta3`) are marked as pre-releases.
The version is shown in the footer of the web interface.

After the very first release, make the package public once, so the image can be pulled without logging in: On GitHub,
open the `synchronist` package (Packages on the profile/repository page) → Package settings → Change visibility → Public.

## Development

Synchronist is a Rails app. With Ruby (see `.ruby-version`), Node.js, Yarn and rsync installed:

```bash
bin/setup
mkdir -p tmp/data/storage tmp/data/receive
cat > .env <<EOF
SYNCHRONIST_MODE=receiver
SYNCHRONIST_PAYLOAD_PATH=$PWD/tmp/data/payload.synchronist
SYNCHRONIST_STORAGE_FOLDER=$PWD/tmp/data/storage
SYNCHRONIST_RECEIVE_FOLDER=$PWD/tmp/data/receive
EOF
bin/dev
```

`bin/dev` (foreman) loads the `.env` file and starts the web server (including the folder watcher), the CSS build and the
job worker. Log in at http://localhost:3000 with `sync`/`sync`.

Run the tests with `bin/rails test test:system` and the benchmarks with `bin/benchmark`. macOS ships a different rsync
(openrsync) which doesn't support all the options synchronist uses, install the real one with `brew install rsync`.
