# Developer Guide

This guide describes how to set up a local development environment for the froxlor container and how to mount 
additional packages during development.

## Directory Structure

A typical local development setup may look like this:

```text
.
├── container
├── froxlor
├── framework
├── core
├── ui
├── packages
└── example
```

In this layout:

* `container` contains the Docker setup.
* `froxlor` contains the froxlor application.
* `framework` contains the froxlor framework metapackage, which requires `core`, `ui` and `packages`.
* `core`, `ui` and `packages` contain the framework packages (`froxlor/core`, `froxlor/ui`, `froxlor/packages`).
* `example` contains an additional package under development.

## Docker Compose

The following `compose.yml` example can be used for local development.

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
            - ../core:/opt/froxlor/packages/core
            - ../ui:/opt/froxlor/packages/ui
            - ../packages:/opt/froxlor/packages/packages
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
            - redis:/data
    adminer:
        image: adminer:latest
        restart: unless-stopped
        ports:
            - "8080:8080"
        depends_on:
            - db
volumes:
    database:
    redis:
```

> [!WARNING]
> This development setup runs the froxlor container in privileged mode and uses the host PID namespace. Use this 
> configuration only in trusted local development environments.

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

For example, to develop an additional package named `example`, add it as a volume:

```yaml
services:
  froxlor:
    # ...
    environment:
        FROXLOR_DEV_REPOSITORIES: framework,core,ui,packages,example
        FROXLOR_DEV_PACKAGES: froxlor/example
    volumes:
      - ../froxlor:/var/www/html/froxlor
      - ../framework:/opt/froxlor/packages/framework
      - ../core:/opt/froxlor/packages/core
      - ../ui:/opt/froxlor/packages/ui
      - ../packages:/opt/froxlor/packages/packages
      - ../example:/opt/froxlor/packages/example
```

## Test Node (`Dockerfile.node`)

To work on everything that runs *on* a node (node setup, service installation, web/mail/DNS configuration, environments)
without touching your machine, add a test node to the compose file. `Dockerfile.node` builds a Debian 13 (trixie)
container with systemd as PID 1, an SSH server and the user `frxlocal` (password-less sudo). froxlor reaches it through
the remote adapter (`froxlor/adapter-remote`) via SSH.

```yaml
services:
  froxlor:
    # ...
    depends_on:
      # ...
      node:
        condition: service_started
    environment:
      # ...
      FROXLOR_DEV_REPOSITORIES: framework,core,ui,packages,adapter-remote
      FROXLOR_DEV_PACKAGES: froxlor/adapter-remote
      # the seeder creates the root node as remote node "node" instead of the local one
      FROXLOR_DEV_NODE: remote
    volumes:
      # ...
      - ../adapter-remote:/opt/froxlor/packages/adapter-remote
  node:
    build:
      context: .
      dockerfile: Dockerfile.node
    restart: unless-stopped
    hostname: node
    # websites of the test node
    ports:
      - "${FROXLOR_NODE_HTTP_PORT:-8081}:80"
      - "${FROXLOR_NODE_HTTPS_PORT:-8443}:443"
    # systemd needs its own cgroup tree and tmpfs mounts
    privileged: true
    cgroup: host
    tmpfs:
      - /run
      - /run/lock
      - /tmp
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      # state of the node (see below)
      - node-etc:/etc
      - node-usr:/usr
      - node-var:/var
      - node-srv:/srv
      - node-root:/root
      - node-home:/home

volumes:
  node-etc:
  node-usr:
  node-var:
  node-srv:
  node-root:
  node-home:
```

With `FROXLOR_DEV_NODE: remote`, `php artisan migrate:fresh --seed` creates the root node with the remote adapter,
host name `node`, user `frxlocal` and the private key matching the public key baked into `Dockerfile.node`
(`NodesTableSeeder::remoteNode()`). Without reseeding, create a node with these values in the panel.

Useful checks:

```shell
docker compose exec node systemctl is-system-running   # "running" once the node has booted
docker compose exec node journalctl -f                 # what the node setup does
docker compose exec froxlor php artisan tinker --execute='echo Froxlor\Core\Models\Node::where("hostname", "node")->first()->adapter()->exec("id -u");'   # 0 = sudo works
```

Mail nodes read domains and mailboxes from the panel database through a read-only user per node, which froxlor
creates itself. The panel database user therefore needs `CREATE USER` and `GRANT OPTION`:
`db-init/10-froxlor-grants.sql` grants them when the database volume is created (mounted to
`/docker-entrypoint-initdb.d`). For an existing volume run it once:

```shell
docker compose exec -T db mariadb -uroot -pCHANGEM3 < db-init/10-froxlor-grants.sql
```

The test node's host name `node` is no FQDN; set the node setting `mail.hostname` (e.g. `mail.froxlor.test`) before
building its mail configuration.

The service wizard of a node (*Nodes → node → Configure services*) installs services on it through the queue
`node-setup`; in the development container the process `setup` (see `composer serve` of the skeleton) works on it, its
output appears in `docker compose logs froxlor`. What the setup did on the node is journaled under
`/var/lib/froxlor/node-setup/<run>/` (`status`, `phase`).

Environments are placed on a node and their jails reconciled through the queue `environment-jails` (process
`jails`). Packages put programs, files or jail users into the jails (`core/docs/environment-jails.md`);
the test of the root-side helper runs on the test node:
`FROXLOR_JAIL_HELPER_B64=$(base64 -w0 resources/node/reconcile_jail.py) python3 test_jail_filesystem.py -v` (as root,
`umask 022`).

Websites on the test node are published on port 8081 (HTTPS 8443). Add the domain to `/etc/hosts` of your machine
(`127.0.0.1 webtest.test`) and open `http://webtest.test:8081/`. Rootless Docker cannot bind ports below 1024; to use
port 80, allow it once on the host (`sudo sysctl net.ipv4.ip_unprivileged_port_start=80`) and start with
`FROXLOR_NODE_HTTP_PORT=80 FROXLOR_NODE_HTTPS_PORT=443 docker compose up -d node`.

The test node keeps its state in the volumes `node-etc`, `node-usr`, `node-var`, `node-srv`, `node-root` and
`node-home` (filled from the image on first start): installed services, environments, mailboxes and databases survive
restarts and recreating the container. The jail mounts of the environments are kept in its `/etc/fstab`. Changes to
`Dockerfile.node` only reach a node with fresh volumes.

Start from a clean system again (all installed services, environments and mailboxes on the node are gone; froxlor
still has the node as set up, run *Run setup again* on the node page or reseed):

```shell
docker compose rm -sf node
docker volume rm container_node-etc container_node-usr container_node-var container_node-srv container_node-root container_node-home
docker compose up -d --build node
```

> [!WARNING]
> The SSH key pair of the test node is public (it is in the repository) and the container runs privileged. Use it only
> for local development and never expose port 22 of the node.

## Helpful Commands

Here you'll find a list of helpful commands that you might need to use sometimes because of certain edge cases.

### Database migration and seeding

If you mount the source code without an existing database, startup may fail because database initialization will not 
run when the source code is present. To migrate and seed the database, run the following command:

```shell
docker compose run froxlor php artisan migrate:fresh --seed
```

### Fresh installation (setup page)

To try the setup page (`/init`) the panel database needs the baseline of a new installation (settings, roles and
permissions, resources, default plans) without the development data, which `APP_ENV=local` and
`DEV_SEED_DEVELOPMENT_DATA=true` always add:

```bash
docker compose exec -e APP_ENV=production -e DEV_SEED_DEVELOPMENT_DATA=false froxlor php artisan migrate:fresh --seed --force
```

A `migrate:fresh` without `--seed` is not enough: creating the administrator needs the "Platform Unlimited" plan and
the "Super-Admin" role. `docker compose exec froxlor php artisan migrate:fresh --seed` brings the development data back.

### Test database

The tests (`php artisan test`) run against the database `froxlor_testing`, not the panel database: the queue workers
and the scheduler of the dev stack work on `froxlor` and would hold locks the tests wait for. `db-init/20-froxlor-testing.sql`
creates it with a new database volume; for an existing volume create it once and seed it (again after new migrations):

```shell
docker compose exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"' < db-init/20-froxlor-testing.sql
docker compose exec -e DB_DATABASE=froxlor_testing froxlor php artisan migrate:fresh --seed
```

### Usage of Composer

Sometimes you may wish to use Composer without using froxlor's package management. This can easily be done with the
following command:

```shell
docker compose run froxlor composer <...>
```

## Test services

`compose.yml` also starts services for tests on the test node (all only reachable inside the Docker network):

| Service  | What                                                       | Access from the test node                                     |
|----------|------------------------------------------------------------|---------------------------------------------------------------|
| `pebble` | Let's Encrypt's ACME test server, DNS-01 against `node:53` | `https://pebble:14000/dir` (node setting `web.acme_ca`)       |
| `s3`     | S3 server (RustFS)                                         | `http://s3:9000`, key `froxlor` / `froxlor-s3-secret`         |
| `ftps`   | FTP server with TLS required (pure-ftpd)                   | `ftps:21`, user `backup` / `froxlor-ftps-secret`, explicit TLS |

The test node has to trust the TLS certificates of Pebble and the FTP server once (after a new test node or FTP
container):

```bash
docker compose cp pebble:/test/certs/pebble.minica.pem /tmp/pebble.pem
docker compose cp /tmp/pebble.pem node:/usr/local/share/ca-certificates/pebble-minica.crt
docker compose cp ftps:/etc/ssl/private/pure-ftpd.pem /tmp/ftps.pem && openssl x509 -in /tmp/ftps.pem -out /tmp/ftps.crt
docker compose cp /tmp/ftps.crt node:/usr/local/share/ca-certificates/froxlor-test-ftps.crt
docker compose exec node update-ca-certificates
```

(`docker compose cp` into `/tmp` of the test node does not work, it is a tmpfs.)

## Production processes

Without a command the image starts `bin/run.sh`: supervisord with Octane (Swoole, port 8000), the queue workers
(Horizon when `QUEUE_CONNECTION=redis`, otherwise `queue:work` for the `default`, `node-setup` and `environment-jails` queues) and the
scheduler, each restarted when it ends; `froxlor:packages:sync` runs before. The development compose file overrides the
command with `composer run serve`. To try the production processes next to the development container:

```bash
docker compose build froxlor
docker compose run -d --rm --no-deps --name froxlor-prodtest -p 8099:8000 froxlor /opt/froxlor/bin/run.sh
docker exec froxlor-prodtest supervisorctl -c /tmp/froxlor-supervisord.conf status
docker rm -f froxlor-prodtest
```
