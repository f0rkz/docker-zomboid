# Project Zomboid

This docker deployment is a simple docker compose deployment of project zomboid.

## Usage

Create a project directory somewhere on your system:

```
mkdir /opt/zomboid
```

Create a docker-compose.yml file in the project directory:

```
cd /opt/zomboid
vim docker-compose.yml
```

Fill in your content:

```
services:
  zomboid:
    image: ghcr.io/f0rkz/docker-zomboid:latest
    restart: always
    environment:
      - ADMINPASSWORD=changeme
      - STEAMVAC=true
      - SERVERNAME=zomboid
    ports:
      - "16261:16261/udp"
      - "16262:16262/udp"
    volumes:
      - ./data:/data
      - ./zomboid:/root/Zomboid
```

Start your server:

```
docker compose up -d
```

## Configuration

Zomboid will create a save directory for your saves as well as a server directory for your configs.

Your server save can be found in `zomboid/Saves/Multiplayer/${SERVERNAME}`

The zomboid.ini file can be found in `zomboid/Server/zomboid.ini`

## Shut down

To shut down or restart your zomboid server, issue any required save commands to save your game, and run:

```
docker compose down
```

## Start up

Starting up is as simple as:

```
docker compose up -d
```

## Logs

To see your server logs:

```
docker compose logs -f
```
