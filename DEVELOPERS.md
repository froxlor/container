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
        # FROXLOR_* end up in ../froxlor/.env without the prefix (bin/env.sh); no env_file of that
        # .env: compose would read it before bin/env.sh rewrites it, and its old values would win
        environment:
            FROXLOR_DB_CONNECTION: mariadb
            FROXLOR_DB_HOST: db
            FROXLOR_DB_PORT: 3306
            FROXLOR_DB_DATABASE: froxlor
            FROXLOR_DB_USERNAME: froxlor
            FROXLOR_DB_PASSWORD: CHANGEM3
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

`FROXLOR_DEV_PACKAGES` lists the packages to require (comma separated). `php artisan repositories:init` adds the
path repository for `/opt/froxlor/packages/*` and requires all of them at `dev-main` with one `composer require`; it
fails with Composer's error when they cannot be installed. A package mounted elsewhere names its directory:
`froxlor/example::/srv/example`.

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
    # services of the test node on the host (see below)
    ports:
      - "${FROXLOR_NODE_HTTP_PORT:-8081}:80"
      - "${FROXLOR_NODE_HTTPS_PORT:-8443}:443"
      - "${FROXLOR_NODE_SSH_PORT:-2222}:22"
      - "${FROXLOR_NODE_FTP_PORT:-2121}:21"
      - "30000-30019:30000-30019"
      - "${FROXLOR_NODE_SMTP_PORT:-2525}:25"
      - "${FROXLOR_NODE_SUBMISSION_PORT:-2587}:587"
      - "${FROXLOR_NODE_SMTPS_PORT:-2465}:465"
      - "${FROXLOR_NODE_IMAP_PORT:-2143}:143"
      - "${FROXLOR_NODE_IMAPS_PORT:-2993}:993"
      - "${FROXLOR_NODE_POP3_PORT:-2110}:110"
      - "${FROXLOR_NODE_POP3S_PORT:-2995}:995"
      - "${FROXLOR_NODE_DATABASE_PORT:-3307}:3306"
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
`jails`). The jails are built with bubblewrap for every session (SSH and the commands of the packages), nothing is
copied or mounted on the node; packages and the tools unlocked per environment (System → Tools) put programs, files
or jail users into them (`core/docs/environment-jails.md`). The test of the helper and the starter runs on the test
node, from `core/` (as root, `umask 022`):
`FROXLOR_JAIL_HELPER_B64=$(base64 -w0 resources/node/reconcile_jail.py) FROXLOR_JAIL_STARTER_B64=$(base64 -w0 resources/node/froxlor-jail) python3 tests/Feature/Environment/test_jail_filesystem.py -v`.
The programs of a tool have to be installed on the node first (e.g. `apt-get install nodejs`).

The services of the test node are published on the host (each port can be changed with its variable):

| Service                     | Host port | Node port | Variable                       |
|-----------------------------|-----------|-----------|--------------------------------|
| HTTP / HTTPS                | 8081 / 8443 | 80 / 443 | `FROXLOR_NODE_HTTP_PORT`, `FROXLOR_NODE_HTTPS_PORT` |
| SSH/SFTP of the environments | 2222     | 22        | `FROXLOR_NODE_SSH_PORT`        |
| FTP (passive 30000–30019)   | 2121      | 21        | `FROXLOR_NODE_FTP_PORT`        |
| SMTP / submission / SMTPS   | 2525 / 2587 / 2465 | 25 / 587 / 465 | `FROXLOR_NODE_SMTP_PORT`, `…_SUBMISSION_PORT`, `…_SMTPS_PORT` |
| IMAP / IMAPS                | 2143 / 2993 | 143 / 993 | `FROXLOR_NODE_IMAP_PORT`, `FROXLOR_NODE_IMAPS_PORT` |
| POP3 / POP3S                | 2110 / 2995 | 110 / 995 | `FROXLOR_NODE_POP3_PORT`, `FROXLOR_NODE_POP3S_PORT` |
| MariaDB                     | 3307      | 3306      | `FROXLOR_NODE_DATABASE_PORT`   |

Add the domains to `/etc/hosts` of your machine (`127.0.0.1 webtest.test`) and open `http://webtest.test:8081/`.
Applications that store their own address (WordPress `siteurl`) redirect to it, keeping only one of the two ports; for
HTTP and HTTPS side by side let the address follow the request (WordPress: `WP_HOME`/`WP_SITEURL` from `HTTP_HOST` in
`wp-config.php`, limited to the site's own host names).
Rootless Docker cannot bind ports below 1024; to use port 80, allow it once on the host
(`sudo sysctl net.ipv4.ip_unprivileged_port_start=80`) and start with
`FROXLOR_NODE_HTTP_PORT=80 FROXLOR_NODE_HTTPS_PORT=443 docker compose up -d node`.

What the node needs so that these services work from the host:

- FTP: the passive range is mapped 1:1; set the node setting `access.passive_ports` to `30000 30019`. ProFTPD announces
  the container's address in passive mode: FileZilla replaces it with the server address on its own, curl needs
  `--ftp-skip-pasv-ip`.
- Databases: the node setup lets MariaDB listen on all addresses (the panel reaches the node over the network) and
  creates the administrator froxlor uses (stored under the node's database server). For access from the host, add `%`
  to the access hosts there (`localhost,%`). Customers are shown `127.0.0.1` as host of a database on their own node:
  it works for the websites and inside the jail, which has no MariaDB socket.
- Mail: the node's host name `node` is no FQDN; the node setup asks for the host name of the mail server (or set the
  node setting `mail.hostname`).

The dev seed assigns the node to "Example Reseller" (may pass it on) and "Example Customer" (plan "Example Plan" of the
reseller); other tenants get nodes on their page under "Nodes" (or `PUT /api/tenants/{tenant}/node-assignments`).

The test node keeps its state in the volumes `node-etc`, `node-usr`, `node-var`, `node-srv`, `node-root` and
`node-home` (filled from the image on first start): installed services, environments, mailboxes and databases survive
restarts and recreating the container. Changes to `Dockerfile.node` only reach a node with fresh volumes.

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

### Usage of froxlor Packages

froxlor's package management (`froxlor/packages`) comes with these Artisan commands:

| Command                             | What it does                                                                                     |
|-------------------------------------|--------------------------------------------------------------------------------------------------|
| `packages:install <package>...`     | Runs `composer require` for one or more packages (optionally `vendor/name:^1.0`), then verifies the boot and syncs |
| `packages:remove <package> [--purge]` | Uninstalls a package (lifecycle hooks, then `composer remove`); `--purge` also deletes its data |
| `packages:enable <package>`         | Enables a package (`enabling`/`enabled` hooks); refused while a package it requires is disabled |
| `packages:disable <package>`        | Disables a package (`disabling`/`disabled` hooks); refused while enabled packages depend on it |
| `packages:update [<package>]`       | Runs `composer update` for one package, or for all of them without an argument, then verifies the boot and syncs |
| `packages:sync`                     | Runs pending migrations, `core:sync-registries` and the `installing/installed`, `updating/updated` hooks |
| `packages:verify`                   | Boots the application in a fresh process and reports whether it still starts with the installed packages |
| `packages:check-updates`            | Compares the installed packages with the marketplace and notifies the root tenants about updates |
| `repositories:init`                 | Adds the path repository `/opt/froxlor/packages/*` and requires the packages of `FROXLOR_DEV_PACKAGES` |

```shell
docker compose run froxlor php artisan packages:install froxlor/web froxlor/mail:^1.0
docker compose run froxlor php artisan packages:remove froxlor/example
docker compose run froxlor php artisan packages:remove froxlor/example --purge  # also delete its data
docker compose run froxlor php artisan packages:disable froxlor/example
docker compose run froxlor php artisan packages:enable froxlor/example
docker compose run froxlor php artisan packages:update                 # update all packages
docker compose run froxlor php artisan packages:update froxlor/example # update a single package
docker compose run froxlor php artisan packages:verify
docker compose run froxlor php artisan packages:check-updates
```

`packages:install` and `packages:update` boot the application in a fresh process after Composer (the same check as
`packages:verify`). If a package breaks the boot, it is disabled automatically (safe mode) and the command reports which
package and why. `packages:install` resolves all given packages with a single `composer require`, so packages that depend
on each other (e.g. `froxlor/domain` and `froxlor/web`) can be installed together.

`packages:remove` refuses `froxlor/framework`, `froxlor/core`, `froxlor/ui` and `froxlor/packages`, and any package
another installed froxlor package still requires (remove the dependants first). The package management (also the
"Uninstall" page and `DELETE api/packages/{package}`) then:

1. checks with `composer remove --dry-run` that Composer can remove the package, before anything is torn down,
2. disables the package (`disabling()`/`disabled()`) and calls its `uninstalling(bool $purge)` hook while its code is
   still loaded (there is no hook after the removal). The feature packages use `NodeUninstall::run()` there: without
   purge froxlor only stops managing their nodes (the drift check forgets the files, the nodes keep their
   configuration, a reinstall takes over again); with purge the node role is taken off the nodes and the configuration
   files froxlor wrote are removed there by the queued core job `RemoveNodeFiles`, followed by a reload: vhosts, PHP-FPM
   pools, certificates and password files (web), lookup maps, SQL configuration, rspamd settings and DKIM keys (mail;
   `main.cf`, `master.cf` and `dovecot.conf` stay), zones and the zone list with its include in `named.conf.local`
   (dns), the ProFTPD configuration and the managed SSH keys (ftp; the sshd configuration stays, it keeps password
   logins of the environment users off). The lookup database users of mail and FTP are dropped. Installed services
   and customer data (webspace, maildirs, customer databases, backups) are never touched,
3. with `--purge` (the "Delete data" toggle in the UI) rolls back the package's migrations (`migrate:reset` on its
   migration directories, so every `down()` must work), then calls `uninstalled(bool $purge)`, the last moment the
   package's code runs (symmetric to `installing()` → migrations → `installed()`),
4. runs `composer remove`,
5. forgets the package's lifecycle state (a reinstall starts enabled) and, with `--purge`, deletes the settings it owns
   (`owner_package`), its permissions (with their role assignments) and its resources (with plan limits, usage and
   reservations).

Without `--purge` the tables, settings, permissions and resources stay, so a reinstall picks them up again. If the
rollback fails, the package stays installed and disabled (`uninstalled()` is not called). If `composer remove` fails
after the rollback, `migrate` brings the schema back and the package stays disabled; if only a Composer script failed
after the package was removed (e.g. `package:discover`), the uninstall is completed and the error reported. Afterwards
the application is booted once in a fresh process (`packages:verify`); if it no longer starts, that is reported too. A package that safe mode keeps
from loading gets no hooks; its migrations and settings are purged all the same, its permissions and resources stay.
`--purge` asks for confirmation on a terminal (`--no-interaction` skips the question).

Run from a terminal, `packages:update` lets a package hook that needs administrator input (`requireCompletion()`) ask
for it on the command line. Otherwise (and always for `packages:install`) the input is requested in the web UI and the
package's migrations are held back until then.

`packages:sync` is normally not called by hand: the package management runs it as a subprocess after every Composer
change (with `--installed=<package>` / `--updated=<package>` for the packages that changed, so their new code is
autoloadable), and `bin/run.sh` runs it without options on startup to apply pending migrations. Call it yourself after
changing a mounted package by hand, e.g. after adding a migration:

```shell
docker compose exec froxlor php artisan packages:sync
```

`packages:check-updates` runs daily through the scheduler; when everything is up to date again it removes unread
update notifications.


### Usage of Composer

Sometimes you may wish to use Composer without using froxlor's package management. This can easily be done with the
following command:

```shell
docker compose run froxlor composer <...>
```

The package management never changes the skeleton's `composer.json` (which is under version control). It installs
packages and adds repositories in `composer.local.json` with the lock `composer.local.lock` (both git-ignored), which
it rebuilds from `composer.json` before every Composer run, keeping its own additions. The image sets
`COMPOSER=composer.local.json`, so Composer commands in the container work on the same files; the entrypoint creates
`composer.local.json` from `composer.json` when it is missing. Changes to the skeleton (scripts, requirements) therefore
belong in `composer.json`.

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

Without a command the image starts `bin/run.sh`: supervisord with Caddy in front of php-fpm (port 8000, with
`FROXLOR_HTTPS=true` also HTTPS on 8443, `FROXLOR_TRUSTED_PROXIES` for a reverse proxy in front, README; `bin/caddy.sh`, `config/php-fpm.conf`), the queue workers
(Horizon when `QUEUE_CONNECTION=redis`, otherwise `queue:work` for the `default`, `node-setup` and `environment-jails` queues) and the
scheduler, each restarted when it ends; `packages:sync` runs before. The development compose file overrides the
command with `composer run serve`. To try the production processes next to the development container:

```bash
docker compose build froxlor
docker compose run -d --rm --no-deps --name froxlor-prodtest -p 8099:8000 froxlor /opt/froxlor/bin/run.sh
docker exec froxlor-prodtest supervisorctl -c /tmp/froxlor-supervisord.conf status
docker rm -f froxlor-prodtest
```
