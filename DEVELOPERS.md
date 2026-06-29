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
        build: .
        restart: unless-stopped
        privileged: true
        pid: "host"
        depends_on:
            db:
                condition: service_healthy
            redis:
                condition: service_healthy
            adminer:
                condition: service_started
        ports:
            - "8000:8000"
        # Use the environment and/or the env_file as you like
        environment:
            FROXLOR_DB_CONNECTION: mariadb
            FROXLOR_DB_HOST: db
            FROXLOR_DB_PORT: 3306
            FROXLOR_DB_DATABASE: froxlor
            FROXLOR_DB_USERNAME: froxlor
            FROXLOR_DB_PASSWORD: CHANGEM3
        env_file:
            -   path: ../froxlor/.env
                required: false
        volumes:
            - ../froxlor:/var/www/html/froxlor
            - ../framework:/opt/froxlor/packages/framework
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
            retries: 5
        volumes:
            - ./database:/var/lib/mysql
    redis:
        image: redis:latest
        restart: unless-stopped
        healthcheck:
            test: [ "CMD", "redis-cli", "ping" ]
            start_period: 5s
            interval: 10s
            timeout: 5s
            retries: 5
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
