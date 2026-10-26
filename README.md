![Diagram](doc/logo.png)

[![Rails](https://github.com/siegy22/synchronist/actions/workflows/rails.yml/badge.svg)](https://github.com/siegy22/synchronist/actions/workflows/rails.yml)

Synchronist is mirroring/sync tool which allows to send increments without having an active connection between them.

## Installation

Right now the only way to easily install synchronist would be using [docker](https://www.docker.com/). You can howevery deploy it from source if you want to. However instructions for that are not covered here.


Before you start, make sure you have docker (or podman) set up with [docker-compose](https://docs.docker.com/compose/). See https://docs.docker.com/get-docker/

### Choose location

We'll use `/opt/synchronist` in this example:

```
$ mkdir /opt/synchronist
$ cd /opt/synchronist
```

### Install script

Run the install script (or download it, for inspection and run it manually):

```
$ sh -c "$(curl https://raw.githubusercontent.com/siegy22/synchronist/main/setup-deployment.sh)"
```

You'll need to specify the folders that should be exposed to synchronist, use comma-separated values to have multiple values.

### Further configuration

The installation script prepared a `docker-compose.yml` in the current working directory. With the values pre-filled.
If you want to change those at any point, feel free! The script is only here to have a quick start.

You also might wanna put this behind a reverse proxy to support https, I recommend using [jwilder/nginx-proxy](https://hub.docker.com/r/jwilder/nginx-proxy)

### Starting up!

```bash
$ systemctl start synchronist

# Or if you want to have it always running also after rebooting:
$ systemctl enable --now synchronist
```

### Acess the web interface

Visit your server name with your configured port in a web browser and configure the application!

Background jobs can be inspected under `/jobs` (or "Jobs" in the sidebar).

### What's running?

Synchronist runs as a single container. There's no external database or Redis to operate:

- Data is stored in SQLite databases inside the `storage` volume (`production.sqlite3` for the app,
  `production_queue.sqlite3` for [Solid Queue](https://github.com/rails/solid_queue) and
  `production_cable.sqlite3` for [Solid Cable](https://github.com/rails/solid_cable)).
- Background jobs run inside the web server process through the Solid Queue Puma plugin (`SOLID_QUEUE_IN_PUMA`).
- Recurring jobs (checking for payloads/received files and sending payloads) are scheduled when saving the configuration.
  The check intervals can be changed using `SYNCHRONIST_CHECK_PAYLOAD_CRON` and `SYNCHRONIST_CHECK_RECEIVED_FILES_CRON` (default: every minute).

Back up the `storage` volume to back up synchronist.

### Upgrading from 1.0.0.beta or 1.0.0.beta2 (PostgreSQL/Redis)

Versions 1.0.0.beta and 1.0.0.beta2 stored their data in PostgreSQL and Redis. The new version starts with empty SQLite databases,
so the configuration needs to be entered again in the web interface after upgrading. The history of syncs/payloads
is not migrated. When upgrading an existing `docker-compose.yml`:

- Remove the `DATABASE_URL` and `REDIS_URL` environment variables (`DATABASE_URL` would override the SQLite configuration).
- Remove the `postgres`, `redis` and `synchronist-worker` services and the `depends_on` section.

Compare with [docker-compose.sample.yml](docker-compose.sample.yml).

## FAQ

### How?

- Using a so-called payload, the receiver generates the current state of the storage that it currently holds.
- The payload then needs to be sent to the sender (not covered by synchronist)
- The payload is parsed by the **sender** which will diff their current state with the payload
- The sender puts the increment into a configurable folder
- The increment then needs to be put into the receive folder on the receiver's end.
- The receiver will put all the received data into the storage folder.

