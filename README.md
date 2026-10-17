<p align="center">
    <a href="https://froxlor.org" target="_blank">
        <img src="https://froxlor.org/img/brand/logo_gradient_text_white.png" width="80" alt="froxlor logo">
    </a>
</p>

<p align="center">
    <a href="https://github.com/froxlor/container/actions/workflows/build-and-push.yml"><img src="https://github.com/froxlor/container/actions/workflows/build-and-push.yml/badge.svg" alt="Container build status"></a>
    <a href="https://github.com/froxlor/container"><img src="https://img.shields.io/badge/container%20version-develop-orange" alt="Container version"></a>
    <a href="https://github.com/froxlor/container"><img src="https://img.shields.io/badge/froxlor%20version-develop-orange" alt="froxlor version"></a>
    <a href="https://github.com/froxlor/container"><img src="https://img.shields.io/badge/status-in%20development-orange" alt="Project status"></a>
    <a href="https://github.com/froxlor/container/blob/main/COPYING.LESSER"><img src="https://img.shields.io/badge/license-LGPL--3.0--or--later-blue" alt="License"></a>
</p>

# froxlor Container

This repository provides the official froxlor container image for Docker, Kubernetes, and other container platforms.

> [!NOTE]
> This container image is currently in development and is **not yet recommended for production use**.
> It contains the latest development version of froxlor.
>
> If you want to install froxlor directly on a bare-metal or virtual server, without a container platform, use the main [froxlor repository](https://github.com/froxlor/froxlor).

## Quick Start

The following example starts a minimal froxlor container using Docker Compose.

> [!TIP]
> Check the [developer guide](DEVELOPERS.md) for information on setting up a development environment.

### Single Node Installation

Start by creating a fresh `froxlor` directory for your configuration files.

```bash
mkdir froxlor
cd froxlor
```

```bash
wget https://raw.githubusercontent.com/froxlor/froxlor/refs/heads/main/.env.example -O .env
```

Setup `DB_*` environment variables to match with the `compose.yml` `db` service. Example:

```dotenv
DB_CONNECTION=mariadb
DB_HOST=db
DB_PORT=3306
DB_DATABASE=froxlor
DB_USERNAME=froxlor
DB_PASSWORD=CHANGEM3
```

Create a `compose.yml` file:

```yaml
services:
    froxlor:
        image: hub.froxlor.io/froxlor/froxlor:latest
        restart: unless-stopped
        # options grant the container elevated host access
        # and is required to use the host as local node
        privileged: true
        pid: "host"
        # Use the environment and/or the env_file as you like
        environment:
            FROXLOR_HTTPS: true
        env_file: .env
        # These ports are used for the froxlor ui
        ports:
            - "8000:8000" # HTTP
            - "8443:8443" # HTTPS
        volumes:
            - froxlor:/var/www/html/froxlor
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
            - database:/var/lib/mysql
volumes:
    froxlor:
    database:
```

Start the container:

```bash
docker compose up -d
```

Open froxlor in your browser:

```text
https://<your-server-ip>:8443
```

## Behind a Reverse Proxy

When a reverse proxy in front of the container ends TLS (e.g. Apache on another server), name its
address in `FROXLOR_TRUSTED_PROXIES` (IPs or CIDR ranges, comma separated, `*` for every address).
Only from these addresses Caddy in the container and froxlor accept the `X-Forwarded-For`,
`X-Forwarded-Host`, `X-Forwarded-Port` and `X-Forwarded-Proto` headers (client address, host and
`https`); from every other client they are ignored. `Forwarded` and `X-Forwarded-Prefix` are never
used.

```yaml
        environment:
            FROXLOR_TRUSTED_PROXIES: 192.0.2.10
            FROXLOR_APP_URL: https://panel.example.com
        ports:
            - "8000:8000"
```

Name the address the container sees as the source of the proxy's requests. Docker usually keeps the
source address of requests to published ports; with Docker's userland proxy (e.g. for IPv6) it is
the address of the Docker bridge instead (`172.17.0.1` by default). `FROXLOR_HTTPS` is not needed
for this.

Apache as the proxy (modules `proxy`, `proxy_http`, `headers`, `ssl`):

```apache
<VirtualHost *:443>
    ServerName panel.example.com
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/panel.example.com.pem
    SSLCertificateKeyFile /etc/ssl/private/panel.example.com.key

    ProxyPreserveHost On
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
    ProxyPass / http://froxlor.internal:8000/
    ProxyPassReverse / http://froxlor.internal:8000/
</VirtualHost>
```

`mod_proxy` adds `X-Forwarded-For` and `X-Forwarded-Host` itself.

## Database Privileges

Mail and FTP nodes look up domains, mailboxes and FTP accounts directly in the froxlor database (like
froxlor v2). froxlor creates a read-only database user per node that may only read the views of that node.
For this, the froxlor database user needs `CREATE USER` and `GRANT OPTION`:

```sql
GRANT CREATE USER ON *.* TO 'froxlor'@'%';
GRANT ALL PRIVILEGES ON `froxlor`.* TO 'froxlor'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```

Without these privileges, run `php artisan mail:node-access <node>` or `php artisan ftp:node-access <node>`
and execute the printed statements as database administrator.

The nodes connect to the database over the network: the database has to be reachable from them
(node settings `mail.lookup_db_host`/`access.lookup_db_host` if they see it under another address). For
remote nodes, enable TLS for these connections (`mail.lookup_db_tls`, `access.lookup_db_tls`) and restrict the host the lookup
users may connect from (`mail.lookup_user_host`, `access.lookup_user_host`).

## Running Without Privileged Host Access

Some froxlor features require elevated host access. Running the container without `privileged` and `pid: "host"` may disable functionality that depends on local node management.

To run the container without privileged host access, remove these lines from your `compose.yml`:

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
  Place froxlor behind a reverse proxy such as Apache, Caddy, Nginx, or Traefik and trust only its address
  (`FROXLOR_TRUSTED_PROXIES`, see "Behind a Reverse Proxy").

* **Enable HTTPS**
  Secure all browser-to-panel communication with TLS.

* **Pin image versions**
  Avoid using the `latest` tag in production. Use a specific image version once stable tags are available.

* **Review privileged access**
  Only run the container with privileged host access when your deployment explicitly requires it.

## License

This project is licensed under the **GNU Lesser General Public License, version 3 or (at your option) any later
version**, with the **froxlor Extension Package Exception** (SPDX: `LGPL-3.0-or-later WITH LicenseRef-froxlor-Extension-Package-Exception`).

- [COPYING.LESSER](COPYING.LESSER): GNU Lesser General Public License, version 3
- [COPYING](COPYING): GNU General Public License, version 3 (incorporated by the LGPL)
- [LICENSE-EXCEPTION](LICENSE-EXCEPTION): froxlor Extension Package Exception
- [AUTHORS](AUTHORS): the copyright holders

The license of each file is stated in its header or in [REUSE.toml](REUSE.toml)
([REUSE](https://reuse.software/) layout, license texts in [LICENSES/](LICENSES)).
