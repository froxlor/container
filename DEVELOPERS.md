# Developer Guide

This guide describes how to set up a local development environment for the froxlor container and how to mount additional packages during development.

## Directory Structure

A typical local development setup may look like this:

```text
.
├── container
├── froxlor
├── framework
└── example-package
```

In this layout:

* `container` contains the Docker setup.
* `froxlor` contains the froxlor application.
* `framework` contains the froxlor framework package.
* `example-package` contains an additional package under development.

## Docker Compose

The following `docker-compose.yml` example can be used for local development.

```yaml
services:
  froxlor:
    image: hub.froxlor.io/froxlor/froxlor:latest
    build: docs
    restart: unless-stopped
    privileged: true
    pid: "host"
    depends_on:
      - node
      - db
      - redis
      - adminer
    ports:
      - "8000:8000"
    env_file:
      - ../froxlor/.env
    volumes:
      - ../froxlor:/var/www/html/froxlor
      - ../framework:/opt/froxlor/packages/framework
  node:
    build:
      dockerfile: Dockerfile.testbox
  db:
    image: mariadb:latest
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: CHANGEM3
      MARIADB_DATABASE: froxlor
      MARIADB_USER: froxlor
      MARIADB_PASSWORD: CHANGEM3
    healthcheck:
      test: [ "CMD", "healthcheck.sh", "--connect", "--innodb_initialized" ]
      start_period: 30s
      interval: 10s
      timeout: 5s
      retries: 20
    volumes:
      - ./database:/var/lib/mysql
  redis:
    image: redis:latest
    restart: unless-stopped
    volumes:
      - ./redis:/data
  adminer:
    image: adminer:latest
    restart: unless-stopped
    ports:
      - "8080:8080"
    depends_on:
      - db
```

> [!WARNING]
> This development setup runs the froxlor container in privileged mode and uses the host PID namespace. Use this configuration only in trusted local development environments.

## Start the Development Environment

Start all services with:

```bash
docker compose up -d
```

After the services have started, open froxlor in your browser:

```text
http://localhost:8000
```

Adminer is available at:

```text
http://localhost:8080
```

## Package Development

Additional packages can be mounted into the container under `/opt/froxlor/packages`.

For example, to develop an additional package named `example-package`, add it as a volume:

```yaml
services:
  froxlor:
    # ...
    environment:
        FROXLOR_DEV_REPOSITORIES: framework,example-package
        FROXLOR_DEV_PACKAGES: froxlor/example-package
    volumes:
      - ../froxlor:/var/www/html/froxlor
      - ../framework:/opt/froxlor/packages/framework
      - ../example-package:/opt/froxlor/packages/example-package
```
