<p align="center">
    <a href="https://froxlor.org" target="_blank">
        <img src="https://raw.githubusercontent.com/froxlor/framework/refs/heads/main/packages/ui/resources/img/icon.png" width="80" alt="froxlor logo">
    </a>
</p>

<p align="center">
    <a href="https://github.com/froxlor/container/actions/workflows/build-and-push.yml"><img src="https://github.com/froxlor/container/actions/workflows/build-and-push.yml/badge.svg" alt="Container build status"></a>
    <a href="https://github.com/froxlor/framework/actions/workflows/run-unit-tests.yml"><img src="https://github.com/froxlor/framework/actions/workflows/run-unit-tests.yml/badge.svg" alt="Framework unit test status"></a>
    <a href="https://github.com/froxlor/container"><img src="https://img.shields.io/badge/container%20version-develop-orange" alt="Container version"></a>
    <a href="https://github.com/froxlor/container"><img src="https://img.shields.io/badge/froxlor%20version-develop-orange" alt="froxlor version"></a>
    <a href="https://github.com/froxlor/container"><img src="https://img.shields.io/badge/status-in%20development-orange" alt="Project status"></a>
    <a href="https://github.com/froxlor/container/blob/main/LICENSE"><img src="https://img.shields.io/github/license/froxlor/container" alt="License"></a>
</p>

# froxlor Container

This repository provides the official froxlor container image for Docker, Kubernetes, and other container platforms.

> [!NOTE]
> This container image is currently in development and is **not yet recommended for production use**.
> It contains the latest development version of froxlor.
>
> If you want to install froxlor directly on a bare-metal or virtual server, use the main [froxlor repository](https://github.com/froxlor/froxlor).

## Quick Start

The following example starts a minimal froxlor container using Docker Compose.

> [!TIP]
> Check the [developer guide](DEVELOPERS.md) for information on setting up a development environment.

### Minimal `docker-compose.yml`

Create a `docker-compose.yml` file:

```yaml
services:
    froxlor:
        image: hub.froxlor.io/froxlor/froxlor:latest
        restart: unless-stopped
        privileged: true
        pid: "host"
        ports:
            - "8000:8000"
```

Start the container:

```bash
docker compose up -d
```

Open froxlor in your browser:

```text
http://localhost:8000
```

## Extended Docker Compose Example

The following example includes environment variables and a persistent volume.

```yaml
services:
    froxlor:
        image: hub.froxlor.io/froxlor/froxlor:latest
        restart: unless-stopped
        privileged: true
        pid: "host"
        environment:
            FROXLOR_DB_CONNECTION: mariadb
            FROXLOR_DB_HOST: db
            FROXLOR_DB_PORT: 3306
            FROXLOR_DB_DATABASE: froxlor
            FROXLOR_DB_USERNAME: froxlor
            FROXLOR_DB_PASSWORD: CHANGEM3
        ports:
            - "8000:8000"
        volumes:
            - froxlor:/var/www/html/froxlor
volumes:
    froxlor:
```

> [!WARNING]
> The extended example uses `privileged: true` and `pid: "host"`.
> These options grant the container elevated host access and is required to use the host as local node.

## Running Without Privileged Host Access

Some froxlor features require elevated host access. Running the container without `privileged` and `pid: "host"` may disable functionality that depends on local node management.

To run the container without privileged host access, remove these lines from your `docker-compose.yml`:

```yaml
privileged: true
pid: "host"
```

### Consequences

When privileged host access is disabled:

* Local node management will be disabled.
* Features that require direct host-level access may not work.
* To continue managing services remotely, install and configure the **froxlor Remote Adapter** package.

## Production Recommendations

For production deployments, consider the following recommendations:

* **Use persistent volumes**
  Store froxlor data outside the container to prevent data loss during container recreation.

* **Use a reverse proxy**
  Place froxlor behind a reverse proxy such as Caddy, Nginx, or Traefik.

* **Enable HTTPS**
  Secure all browser-to-panel communication with TLS.

* **Pin image versions**
  Avoid using the `latest` tag in production. Use a specific image version once stable tags are available.

* **Review privileged access**
  Only run the container with privileged host access when your deployment explicitly requires it.

## License

This project is licensed under the **GNU Lesser General Public License v2.1**.

See the [LICENSE](LICENSE) file for details.
