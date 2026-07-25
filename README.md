# Project Zomboid dedicated server

A non-root Project Zomboid dedicated server image built on
[`ghcr.io/f0rkz/docker-steamcmd:2`](https://github.com/f0rkz/docker-steamcmd).
The image installs or updates the server at startup and keeps the installation,
configuration, saves, logs, and Workshop content under `/data`.

## Quick start

Set a real administrator password, then start the included Compose deployment:

```bash
export ADMIN_PASSWORD='replace-this-password'
docker compose up -d
docker compose logs -f zomboid
```

The default image follows Steam's `public` branch (currently Build 41). UDP ports
`16261` and `16262` are published. Persistent data is stored in the
`zomboid-data` volume and survives `docker compose down`.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `SERVER_NAME` | `zomboid` | Server and configuration name; letters, numbers, `_`, and `-` are accepted. |
| `ADMIN_PASSWORD` | `changeme` | Initial administrator password. Change this before exposing the server. |
| `ADMIN_PASSWORD_FILE` | unset | Read the administrator password from a mounted secret file. |
| `STEAM_VAC` | `true` | Enable or disable Steam VAC. |
| `STEAM_BRANCH` | public | Steam beta branch, such as `42.19`, `unstable`, or `legacy41`. |
| `STEAM_BRANCH_PASSWORD` | unset | Password for a protected Steam branch. |
| `SERVER_MEMORY` | launcher default (`8G`) | Maximum JVM heap, such as `4G` or `4096M`. |
| `STEAMCMD_VALIDATE` | `false` | Validate every server file during startup. This increases startup time. |
| `STEAMCMD_RETRIES` | `3` | Number of SteamCMD update attempts. |
| `WORKSHOP_ITEMS` | unset | Semicolon- or comma-separated Workshop item IDs. |
| `MOD_IDS` | unset | Semicolon- or comma-separated internal Project Zomboid mod IDs. |
| `MAPS` | unset | Exact semicolon-separated `Map` value for map mods. |

The old `SERVERNAME`, `ADMINPASSWORD`, and `STEAMVAC` names remain accepted for
migration, but the names above are preferred.

Additional arguments supplied to `docker run` are appended to the Project
Zomboid server command.

### Build 42

Build 42 has a separate mod format and is not compatible with all Build 41 mods.
Select it explicitly and verify every Workshop item supports that branch:

```yaml
environment:
  STEAM_BRANCH: "42.19"
```

Return to the stable Build 41 server with an empty `STEAM_BRANCH` or
`STEAM_BRANCH=legacy41`. Back up `/data/server` before changing branches; save
formats may not be backward compatible.

## Workshop mods

Project Zomboid uses both a numeric Workshop item ID and the mod's internal ID.
Map mods may additionally require the server's `Map` option. For example:

```yaml
environment:
  WORKSHOP_ITEMS: "1234567890;2345678901"
  MOD_IDS: "ExampleMod;ExampleMap"
  MAPS: "Example Map;Muldraugh, KY"
```

When these variables are present—even when empty—the entrypoint atomically
updates `WorkshopItems`, `Mods`, and `Map` in
`/data/server/Server/${SERVER_NAME}.ini`. Other server settings remain untouched.
Omit the variables if you want to manage those three options entirely by hand.

Workshop content is downloaded by Project Zomboid during server startup. Client
and server mod versions must match, and a large collection can make the first
startup take several minutes.

## Data layout

| Path | Contents |
| --- | --- |
| `/data/zomboid` | SteamCMD-managed dedicated server installation |
| `/data/server/Server` | Server INI, SandboxVars, spawn regions, and related configuration |
| `/data/server/Saves/Multiplayer` | World saves |
| `/data/server/Logs` | Project Zomboid logs |

The container runs as UID and GID `1000`. If you replace the named volume with a
bind mount, make that directory writable by `1000:1000`.

## Migrating from the pre-1.0 image

The previous image stored server state in `/root/Zomboid` and ran as root. Keep
the existing host directories and temporarily use nested bind mounts:

```yaml
volumes:
  - ./data:/data
  - ./zomboid:/data/server
```

Make both directories writable by UID 1000 before starting the new container.
After confirming the server, you may consolidate both directories into one
volume mounted at `/data`.

## Operations

```bash
docker compose logs -f zomboid
docker compose stop zomboid
docker compose start zomboid
docker compose down
```

Compose allows two minutes for the JVM to save and shut down. Do not use
`docker kill` for routine shutdowns.

## Local development

```bash
make test
make build
make integration
```

The integration test downloads the dedicated server (about 5 GB installed),
starts it with disposable storage, and verifies shutdown. It is intended for
manual and scheduled use rather than every pull request.

## License

[MIT](LICENSE)
