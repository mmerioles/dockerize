import Foundation

extension Curriculum {
    // MARK: - Docker Compose

    static let compose = Category(
        id: "compose", title: "Docker Compose", icon: "square.3.layers.3d",
        blurb: "Describe a whole app in one compose.yaml and run it with one command.",
        lessons: [composeBasics, composeApp, composeWorkflow]
    )

    static let composeBasics = Lesson(
        id: "compose-basics",
        title: "Compose basics",
        commands: ["docker compose up", "docker compose ps", "docker compose logs", "docker compose down"],
        topics: ["Why Compose", "compose.yaml", "services", "image & ports", "environment", "Project names", "docker compose up -d", "docker compose ps", "docker compose logs", "docker compose stop", "docker compose down", "docker compose config"],
        summary: "Compose turns a long list of `docker run` flags into a file. You describe services in compose.yaml, and `docker compose up` creates the containers, network and volumes for you.",
        sections: [
            S("Why Compose?", """
            A real app is rarely one container. Even a single nginx needs a name, a port, some environment and a mount, and typing all of that every time is how mistakes happen.

            **Compose** reads those settings from `compose.yaml`, so the whole setup is versioned with your code. Anyone on the team runs `docker compose up -d` and gets the same thing. Compose v2 is a CLI plugin: the command is `docker compose` (with a space). The old Python `docker-compose` is retired.
            """),
            S("Anatomy of compose.yaml", """
            The top-level `services:` key lists the containers you want. Each service says which `image` to run, which `ports` to publish (`"HOST:CONTAINER"`, quoted so YAML doesn't read them as numbers), its `environment`, and its `volumes`.

            `name:` at the top sets the **project name**. Without it, Compose uses the folder name. Everything Compose creates is named after the project, so pick something unique.
            """, example: Example("cat compose.yaml", output: "name: dz-basics\n\nservices:\n  web:\n    image: nginx:1.27-alpine\n    ports:\n      - \"8089:80\"\n    environment:\n      NGINX_ENTRYPOINT_QUIET_LOGS: \"1\"\n    volumes:\n      - ./site:/usr/share/nginx/html:ro")),
            S("Up, in the background", """
            `docker compose up -d` creates a network called `<project>_default`, then one container per service, named `<project>-<service>-1`. `-d` detaches, just like `docker run -d`. Without it, Compose streams every service's logs in your terminal until Ctrl+C.

            Run `up -d` again and Compose only touches what changed. Unchanged containers are left alone.
            """, example: Example("docker compose up -d", output: "[+] Running 2/2\n ✔ Network dz-basics_default  Created\n ✔ Container dz-basics-web-1  Started")),
            S("Status and logs", """
            `docker compose ps` lists only this project's containers. `docker compose logs` merges the logs of every service, prefixed by container name. Name a service to narrow it, and add `--tail 20` or `-f` to follow.

            These are ordinary containers underneath, so `docker ps` shows them too.
            """, example: Example("docker compose ps", output: "NAME              IMAGE               COMMAND                  SERVICE   CREATED          STATUS          PORTS\ndz-basics-web-1   nginx:1.27-alpine   \"/docker-entrypoint.…\"   web       12 seconds ago   Up 11 seconds   0.0.0.0:8089->80/tcp")),
            S("Stop vs down", """
            `docker compose stop` stops the containers but keeps them, so `docker compose start` brings them straight back. `docker compose down` stops **and removes** the containers and the default network. Named volumes survive `down` unless you add `-v`.

            Compose commands find the project from `compose.yaml` in the current folder. Run them from somewhere else with `-f path/to/compose.yaml` or `-p dz-basics`.
            """, example: Example("docker compose down", output: "[+] Running 2/2\n ✔ Container dz-basics-web-1  Removed\n ✔ Network dz-basics_default  Removed")),
            S("See what Compose sees", """
            `docker compose config` parses the file, fills in variables and defaults, and prints the final result. If the YAML is broken, this is where you find out, with a line number. It's the first command to run when Compose doesn't behave the way the file looks like it should.
            """, example: Example("docker compose config --services", output: "web")),
        ],
        reference: [
            O("docker compose up -d", "Create and start every service in the background"),
            O("docker compose up -d SERVICE", "Start one service (and what it depends on)"),
            O("docker compose ps", "List this project's containers"),
            O("docker compose ps -a", "Include stopped containers"),
            O("docker compose logs SERVICE", "Show one service's logs"),
            O("docker compose logs -f --tail 50", "Follow the last 50 lines from every service"),
            O("docker compose stop / start", "Stop containers without removing them, then start them again"),
            O("docker compose down", "Remove the project's containers and networks"),
            O("docker compose down -v", "Also remove the project's named volumes"),
            O("docker compose config", "Print the fully resolved compose file"),
            O("docker compose config --services", "List service names"),
            O("docker compose -f FILE CMD", "Use a compose file that isn't ./compose.yaml"),
            O("docker compose -p NAME CMD", "Override the project name"),
            O("docker compose ls", "List running Compose projects on this engine"),
        ],
        macNote: "Relative bind mounts like `./site` are shared from your Mac into Docker's Linux VM. Docker Desktop, OrbStack and Colima all share your home folder by default; a project outside it may need adding under Docker Desktop's Settings → Resources → File sharing.",
        images: [Img.nginx],
        diagram: Diagram(
            "From compose.yaml to a running project",
            caption: "docker compose reads compose.yaml and turns it into Engine API calls. Everything it creates belongs to the project dz-basics: a default network and one container per service, named project-service-1.",
            nodes: [
                N("you", "You", icon: "person.fill", .actor, at: 0, 0, detail: "edit, then up -d"),
                N("yaml", "compose.yaml", icon: "doc.text", .file, at: 0, 1, detail: "name: dz-basics"),
                N("cli", "docker compose", icon: "terminal", .cli, at: 1, 1, detail: "plans the changes"),
                N("engine", "dockerd", icon: "gearshape.2", .daemon, at: 2, 1, detail: "Engine API"),
                N("net", "dz-basics_default", icon: "network", .network, at: 3, 1, detail: "project network"),
                N("web", "dz-basics-web-1", icon: "shippingbox.fill", .container, at: 4, 1, detail: "service: web"),
                N("port", "localhost:8089", icon: "globe", .network, at: 4, 0, detail: "→ port 80"),
                N("site", "./site", icon: "folder", .storage, at: 4, 2, detail: "bind mount, read-only"),
            ],
            groups: [G("Project dz-basics", ["net", "web"])],
            edges: [
                E("you", "yaml", "writes"),
                E("yaml", "cli", "reads"),
                E("cli", "engine", "API calls"),
                E("engine", "net", "creates"),
                E("net", "web", "attaches"),
                E("port", "web", "publishes"),
                E("site", "web", "mounted", dashed: true),
            ]
        ),
        seed: Seed(files: [
            F("compose.yaml", """
            name: dz-basics

            services:
              web:
                image: \(Img.nginx)
                ports:
                  - "8089:80"
                environment:
                  NGINX_ENTRYPOINT_QUIET_LOGS: "1"
                volumes:
                  - ./site:/usr/share/nginx/html:ro

            """),
            F("site/index.html", "<!doctype html>\n<title>dz-basics</title>\n<h1>Served by Compose</h1>\n"),
        ]),
        missions: [
            Mission("Check the file with docker compose config",
                    hint: "Compose can print the file the way it understands it.",
                    solution: "docker compose config",
                    check: .ranOK(#"docker[ -]compose\b.*\bconfig\b"#)),
            Mission("Start the project in the background",
                    hint: "`up`, plus the same flag that detaches `docker run`.",
                    solution: "docker compose up -d",
                    check: .all([.composeService("dz-basics", "web"), .publishes("dz-basics-web-1", 8089)])),
            Mission("List the project's containers",
                    hint: "Compose has its own `ps`.",
                    solution: "docker compose ps",
                    check: .all([.ranOK(#"docker[ -]compose\b.*\bps\b"#), .composeService("dz-basics", "web")])),
            Mission("Read the logs of the web service",
                    hint: "`docker compose logs` takes a service name. Load localhost:8089 first to have something to read.",
                    solution: "curl -s localhost:8089\ndocker compose logs --tail 20 web",
                    check: .ranOK(#"docker[ -]compose\b.*\blogs\b.*\bweb\b"#)),
            Mission("Stop the project without removing it",
                    hint: "One verb keeps the containers around, the other deletes them.",
                    solution: "docker compose stop",
                    check: .all([.ranOK(#"docker[ -]compose\b.*\bstop\b"#), .container("dz-basics-web-1", .stopped)])),
            Mission("Tear the project down completely",
                    hint: "This one removes the containers and the network.",
                    solution: "docker compose down",
                    check: .all([
                        .ranOK(#"docker[ -]compose\b.*\bdown\b"#),
                        .not(.container("dz-basics-web-1", .exists)),
                        .not(.network("dz-basics_default")),
                    ])),
        ]
    )

    static let composeApp = Lesson(
        id: "compose-multi-service",
        title: "A multi-service app",
        commands: ["docker compose up --build", "docker compose exec", "docker compose down -v"],
        topics: ["build:", "depends_on", "healthcheck", "service_healthy", "Service-name DNS", "Named volumes", "--wait", "docker compose exec", "docker compose down -v"],
        summary: "A Python web app and redis, defined together. Compose builds the app image, waits for redis to be healthy, wires them onto one network, and keeps the data in a named volume.",
        sections: [
            S("Build instead of pull", """
            `build: .` tells Compose to build the service from the Dockerfile in this folder. Add `image: dz-counter-web:dev` and the result is tagged with that name, otherwise Compose names it `<project>-<service>`.

            `docker compose up` only builds when the image is missing. After you change code, use `up -d --build` so it rebuilds first. The build cache makes that fast when little changed.
            """, example: Example("docker compose up -d --build --wait", output: "[+] Building 3.1s (8/8) FINISHED\n[+] Running 5/5\n ✔ Network dz-counter_default        Created\n ✔ Volume \"dz-counter_redis-data\"    Created\n ✔ Container dz-counter-redis-1      Healthy\n ✔ Container dz-counter-web-1        Healthy")),
            S("Services find each other by name", """
            Every service joins the project network, and Docker's DNS resolves each **service name** to its container. The web app connects to `redis:6379`, never to an IP or localhost. Inside a container, `localhost` is that container itself.

            Only `web` publishes a port. redis is reachable from `web` but not from your Mac, which is exactly what you want for a database.
            """),
            S("Start order with depends_on", """
            `depends_on: [redis]` only means "start redis first". redis may still be loading when web connects. Give redis a `healthcheck` and use `condition: service_healthy`, and Compose waits until the check passes before starting web.

            `up --wait` goes one step further and doesn't return until every service is running or healthy. That's handy in scripts and CI.
            """, example: Example("docker compose ps --format \"table {{.Service}}\\t{{.Status}}\"", output: "SERVICE   STATUS\nredis     Up 20 seconds (healthy)\nweb       Up 14 seconds (healthy)")),
            S("Data in a named volume", """
            The top-level `volumes:` key declares `redis-data`, and Compose creates it as `dz-counter_redis-data`. redis writes to `/data`, so the counter lives in the volume, not in the container.

            `docker compose down` removes containers but keeps the volume, so the next `up` picks up where you left off. `docker compose down -v` deletes the volume too. Use it when you really want a clean slate.
            """, example: Example("docker volume ls --filter name=dz-counter", output: "DRIVER    VOLUME NAME\nlocal     dz-counter_redis-data")),
            S("Get inside a service", """
            `docker compose exec redis redis-cli` runs a command in the running redis container, using the service name instead of the container name. Add `-T` when you're piping or scripting and don't want a terminal.

            `docker compose logs web` shows one service's output, which is where request logs and stack traces end up.
            """, example: Example("docker compose exec redis redis-cli GET hits", output: "\"3\"")),
        ],
        reference: [
            O("build: .", "Build the service from ./Dockerfile instead of pulling"),
            O("image: NAME:TAG (with build:)", "Tag the built image with this name"),
            O("depends_on: [svc]", "Start svc before this service"),
            O("condition: service_healthy", "Wait for svc's healthcheck to pass first"),
            O("healthcheck: test: [CMD, ...]", "Command the engine runs to decide if the service is healthy"),
            O("volumes: (top level)", "Declare named volumes, created as <project>_<name>"),
            O("docker compose up -d --build", "Rebuild images that have a build: section, then start"),
            O("docker compose up -d --wait", "Return only once services are running/healthy"),
            O("docker compose build SERVICE", "Build without starting anything"),
            O("docker compose exec SERVICE CMD", "Run a command in a running service"),
            O("docker compose exec -T SERVICE CMD", "Same, without a TTY (scripts, pipes)"),
            O("docker compose logs SERVICE", "One service's logs"),
            O("docker compose down -v", "Remove containers, networks and named volumes"),
        ],
        macNote: "Only `web` is published, on localhost:8086. Docker Desktop and OrbStack forward published ports from the Linux VM to your Mac's localhost. Service-name DNS like `redis` only works between containers, not from macOS.",
        images: [Img.python, Img.redis],
        diagram: Diagram(
            "Two services, one network, one volume",
            caption: "curl reaches web through the published port. web finds redis by its service name on the project network and runs INCR. redis keeps the count in a named volume, and its healthcheck gates web's start.",
            nodes: [
                N("you", "curl", icon: "terminal", .cli, at: 0, 1, detail: "localhost:8086"),
                N("port", ":8086", icon: "globe", .network, at: 1, 1, detail: "→ web:8000"),
                N("dockerfile", "Dockerfile", icon: "doc.text", .file, at: 2, 0, detail: "build: ."),
                N("web", "web", icon: "shippingbox.fill", .container, at: 2, 1, detail: "Python, stdlib only"),
                N("net", "dz-counter_default", icon: "network", .network, at: 3, 0, detail: "DNS: redis"),
                N("redis", "redis", icon: "cylinder", .container, at: 3, 1, detail: "INCR hits"),
                N("health", "healthcheck", icon: "heart.text.square", .daemon, at: 3, 2, detail: "redis-cli ping"),
                N("vol", "redis-data", icon: "externaldrive.fill", .storage, at: 4, 1, detail: "dz-counter_redis-data"),
            ],
            groups: [G("Project dz-counter", ["web", "net", "redis", "health", "vol"])],
            edges: [
                E("you", "port", "GET /"),
                E("port", "web"),
                E("dockerfile", "web", "builds"),
                E("web", "redis", "redis:6379"),
                E("net", "redis", "resolves", dashed: true),
                E("health", "redis", "every 2s", dashed: true),
                E("redis", "vol", "/data"),
            ]
        ),
        seed: Seed(files: [
            F("compose.yaml", """
            name: dz-counter

            services:
              web:
                build: .
                image: dz-counter-web:dev
                ports:
                  - "8086:8000"
                environment:
                  REDIS_HOST: redis
                  GREETING: Hello from Compose
                depends_on:
                  redis:
                    condition: service_healthy
                healthcheck:
                  test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
                  interval: 2s
                  timeout: 2s
                  retries: 10

              redis:
                image: \(Img.redis)
                command: ["redis-server", "--appendonly", "yes"]
                volumes:
                  - redis-data:/data
                healthcheck:
                  test: ["CMD", "redis-cli", "ping"]
                  interval: 2s
                  timeout: 2s
                  retries: 10

            volumes:
              redis-data:

            """),
            F("Dockerfile", """
            FROM \(Img.python)
            WORKDIR /app
            ENV PYTHONUNBUFFERED=1
            COPY app.py .
            EXPOSE 8000
            CMD ["python", "app.py"]

            """),
            F("app.py", #"""
            import os
            import signal
            import socket
            import sys
            from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

            REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
            GREETING = os.environ.get("GREETING", "Hello")


            def incr(key):
                """Send INCR to redis over the raw RESP protocol, so no client library is needed."""
                command = f"*2\r\n$4\r\nINCR\r\n${len(key)}\r\n{key}\r\n"
                with socket.create_connection((REDIS_HOST, 6379), timeout=2) as conn:
                    conn.sendall(command.encode())
                    reply = conn.recv(64).decode()  # an integer reply looks like ":7\r\n"
                if not reply.startswith(":"):
                    raise RuntimeError(f"redis said {reply.strip()}")
                return int(reply[1:].strip())


            class Handler(BaseHTTPRequestHandler):
                def do_GET(self):
                    if self.path == "/health":
                        self.reply(200, "ok\n")
                        return
                    try:
                        hits = incr("hits")
                        self.reply(200, f"{GREETING}! This page has been viewed {hits} times.\n")
                    except (OSError, RuntimeError) as err:
                        self.reply(503, f"cannot reach redis at {REDIS_HOST}: {err}\n")

                def reply(self, status, body):
                    data = body.encode()
                    self.send_response(status)
                    self.send_header("Content-Type", "text/plain")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)

                def log_message(self, fmt, *args):
                    if self.path != "/health":  # keep healthchecks out of the logs
                        super().log_message(fmt, *args)


            # PID 1 ignores SIGTERM unless it installs a handler, so stop promptly on `docker compose down`.
            signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
            print(f"listening on :8000, redis at {REDIS_HOST}")
            ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()

            """#),
        ]),
        missions: [
            Mission("Build and start the whole stack in the background",
                    hint: "`up` with flags to rebuild the image and detach. `--wait` returns once everything is healthy.",
                    solution: "docker compose up -d --build --wait",
                    check: .all([
                        .image("dz-counter-web:dev"),
                        .composeService("dz-counter", "web"),
                        .composeService("dz-counter", "redis"),
                    ])),
            Mission("Hit the counter on localhost:8086 twice",
                    hint: "curl it, then press ↑ and run it again. The number should go up.",
                    solution: "curl -s localhost:8086\ncurl -s localhost:8086",
                    check: .all([.composeService("dz-counter", "web"), .ranOK(#"curl\b.*(localhost|127\.0\.0\.1):8086"#)])),
            Mission("Show the logs of just the web service",
                    hint: "`docker compose logs` takes a service name.",
                    solution: "docker compose logs --tail 20 web",
                    check: .ranOK(#"docker[ -]compose\b.*\blogs\b.*\bweb\b"#)),
            Mission("Read the counter straight from redis with redis-cli",
                    hint: "`docker compose exec` into the redis service, then `redis-cli GET hits`.",
                    solution: "docker compose exec -T redis redis-cli GET hits",
                    check: .ranOK(#"docker[ -]compose\b.*\bexec\b.*\bredis\b.*redis-cli"#)),
            Mission("Take the stack down (keeping the volume) and bring it back",
                    hint: "Plain `down` keeps named volumes. Start it again and curl: the count carries on.",
                    solution: "docker compose down\ndocker compose up -d --wait\ncurl -s localhost:8086",
                    check: .all([
                        .ranOK(#"docker[ -]compose\b(?!.*\s(-v|--volumes)\b).*\sdown\b"#),
                        .composeService("dz-counter", "web"),
                        .volume("dz-counter_redis-data"),
                    ])),
            Mission("Remove everything, including the data volume",
                    hint: "`down` has a flag for volumes.",
                    solution: "docker compose down -v",
                    check: .all([
                        .ranOK(#"docker[ -]compose\b.*\sdown\b.*\s(-v|--volumes)\b"#),
                        .not(.volume("dz-counter_redis-data")),
                        .not(.container("dz-counter-redis-1", .exists)),
                    ])),
        ]
    )

    static let composeWorkflow = Lesson(
        id: "compose-workflow",
        title: "Everyday Compose workflow",
        commands: ["docker compose run --rm", "docker compose restart", "docker compose up --scale", "docker compose -f"],
        topics: [".env files", "Variable substitution", "up -d --build", "restart", "exec", "run --rm", "--scale", "Profiles", "Override files", "compose watch"],
        summary: "The loop you'll actually run all day: change config, re-apply with `up -d`, run one-off commands, scale workers, and layer extra files for local tweaks.",
        sections: [
            S("Edit, then up -d again", """
            After changing `compose.yaml` or `.env`, just run `docker compose up -d` again. Compose compares each service to what's running and **recreates only the ones whose config changed**. Changed code in a `build:` service needs `up -d --build`.

            `docker compose restart web` restarts the existing container without re-reading the file. It's for a stuck process, not for applying changes.
            """, example: Example("docker compose up -d", output: "[+] Running 2/2\n ✔ Container dz-flow-web-1     Running\n ✔ Container dz-flow-worker-1  Recreated")),
            S(".env and variable substitution", """
            Compose reads `.env` from the project folder and substitutes `${VAR}` anywhere in the file. `${WEB_PORT:-8087}` means "WEB_PORT, or 8087 if it's unset". Variables exported in your shell win over `.env`.

            Substitution happens when Compose reads the file, not inside the container. To pass a value into the container, put it under `environment:`. `docker compose config` shows the file after substitution, which settles every "which value did it use?" question.
            """, example: Example("docker compose config | grep APP_MODE", output: "      APP_MODE: development\n      dz.flow.mode: development")),
            S("One-offs: exec vs run", """
            `exec` runs a command inside an **already running** service container. `run` starts a **new** container from a service's config, runs one command and, with `--rm`, deletes it afterwards. Use `run --rm` for migrations, test suites and debugging shells.

            When a service is scaled, `exec --index 2 worker ...` picks a replica.
            """, example: Example("docker compose run --rm tools", output: "mode=development\n<!DOCTYPE html>\n<html>\n<head>\n<title>Welcome to nginx!</title>")),
            S("Scaling and profiles", """
            `docker compose up -d --scale worker=3` runs three copies, named `dz-flow-worker-1` to `-3`. That only works for services without a fixed host port or `container_name`. A plain `up -d` later scales back to what the file says.

            A service with `profiles: [tools]` is skipped by `up` unless you pass `--profile tools`. Targeting it directly with `run` works without the flag. Profiles keep admin tools and test helpers in the same file without starting them every time.
            """, example: Example("docker compose ps --format \"{{.Name}}\"", output: "dz-flow-web-1\ndz-flow-worker-1\ndz-flow-worker-2\ndz-flow-worker-3")),
            S("Layering files", """
            `docker compose -f compose.yaml -f compose.debug.yaml up -d` merges the second file over the first. Maps like `environment` and `labels` are merged key by key, and single values are replaced.

            If a `compose.override.yaml` sits next to `compose.yaml`, Compose loads it **automatically** with no `-f`. Teams use it for local-only tweaks (debug ports, bind-mounted source) and keep it out of git.
            """),
            S("compose watch", """
            `docker compose watch` follows the `develop.watch` rules in the file and syncs or rebuilds as you save files, a live-reload loop for containers. It runs in the foreground until you stop it, so treat it as a dev-time convenience rather than something to script.
            """),
        ],
        reference: [
            O("docker compose up -d", "Apply changes: recreate only services whose config changed"),
            O("docker compose up -d --build", "Rebuild images first, then apply"),
            O("docker compose restart SERVICE", "Restart containers without re-reading the file"),
            O("docker compose exec SERVICE CMD", "Run a command in a running service"),
            O("docker compose exec --index 2 SERVICE CMD", "Pick one replica of a scaled service"),
            O("docker compose run --rm SERVICE [CMD]", "One-off container from a service's config, removed after"),
            O("docker compose up -d --scale SVC=N", "Run N replicas of a service"),
            O("docker compose --profile NAME up -d", "Also start services in that profile"),
            O("${VAR:-default}", "Substitute VAR from the shell or .env, with a fallback"),
            O("docker compose --env-file FILE CMD", "Read variables from FILE instead of .env"),
            O("docker compose -f A.yaml -f B.yaml CMD", "Merge B over A"),
            O("compose.override.yaml", "Merged automatically when it sits next to compose.yaml"),
            O("docker compose watch", "Sync or rebuild on file changes (foreground)"),
        ],
        macNote: "Bind-mounting a large source tree on a Mac crosses the VM boundary on every file read, which can make hot-reloading slow. `compose watch` sidesteps that by syncing changed files into the container instead of mounting them.",
        images: [Img.nginx, Img.alpine, Img.busybox],
        diagram: Diagram(
            "Many inputs, one effective config",
            caption: "Compose merges compose.yaml with any -f files, substitutes ${VARS} from .env, and applies the result. The worker service scales to three containers, and the tools service only runs when you ask for it.",
            nodes: [
                N("env", ".env", icon: "doc.plaintext", .file, at: 0, 0, detail: "APP_MODE, WEB_PORT"),
                N("yaml", "compose.yaml", icon: "doc.text", .file, at: 0, 1, detail: "base"),
                N("debug", "compose.debug.yaml", icon: "doc.text", .file, at: 0, 2, detail: "-f overlay"),
                N("cli", "docker compose", icon: "terminal", .cli, at: 1, 1, detail: "merge + substitute"),
                N("web", "web", icon: "shippingbox.fill", .container, at: 1, 0, detail: ":8087"),
                N("worker", "worker", icon: "square.on.square", .container, at: 2, 1, detail: "--scale worker=3"),
                N("tools", "tools", icon: "wrench.and.screwdriver", .container, at: 1, 2, detail: "profile, run --rm"),
                N("w1", "dz-flow-worker-1", icon: "shippingbox", .container, at: 2, 0),
                N("w2", "dz-flow-worker-2", icon: "shippingbox", .container, at: 3, 1),
                N("w3", "dz-flow-worker-3", icon: "shippingbox", .container, at: 2, 2),
            ],
            groups: [G("worker × 3", ["worker", "w1", "w2", "w3"])],
            edges: [
                E("env", "yaml", "fills ${VARS}"),
                E("debug", "yaml", "merged over", dashed: true),
                E("yaml", "cli", "reads"),
                E("cli", "web"),
                E("cli", "worker"),
                E("cli", "tools", "on demand", dashed: true),
                E("worker", "w1"),
                E("worker", "w2"),
                E("worker", "w3"),
            ]
        ),
        seed: Seed(files: [
            F(".env", """
            # Compose reads this file automatically and substitutes ${VARS} in compose.yaml.
            WEB_PORT=8087
            APP_MODE=development

            """),
            F("compose.yaml", """
            name: dz-flow

            services:
              web:
                image: \(Img.nginx)
                ports:
                  - "${WEB_PORT:-8087}:80"

              worker:
                image: \(Img.alpine)
                init: true
                environment:
                  APP_MODE: ${APP_MODE:-development}
                labels:
                  dz.flow.mode: ${APP_MODE:-development}
                command:
                  - sh
                  - -c
                  - |
                    while true; do
                      echo "$$(hostname) [$${LOG_LEVEL:-info}] working in $$APP_MODE mode"
                      sleep 5
                    done

              tools:
                image: \(Img.busybox)
                profiles: ["tools"]
                environment:
                  APP_MODE: ${APP_MODE:-development}
                command: ["sh", "-c", "echo mode=$$APP_MODE; wget -qO- -T 3 http://web/ | head -n 5"]

            """),
            F("compose.debug.yaml", """
            # Layer this over compose.yaml with:
            #   docker compose -f compose.yaml -f compose.debug.yaml up -d
            services:
              worker:
                environment:
                  LOG_LEVEL: debug
                labels:
                  dz.flow.debug: "true"

            """),
        ]),
        missions: [
            Mission("Start the dz-flow stack in the background",
                    hint: "The usual `up` with detach.",
                    solution: "docker compose up -d",
                    check: .all([
                        .composeService("dz-flow", "web"),
                        .composeService("dz-flow", "worker"),
                        .publishes("dz-flow-web-1", 8087),
                    ])),
            Mission("Switch APP_MODE to production in .env, check it with config, and apply it",
                    hint: "Edit .env (nano works, or sed/perl), confirm with `docker compose config`, then `up -d` recreates what changed.",
                    solution: "perl -pi -e 's/^APP_MODE=.*/APP_MODE=production/' .env\ndocker compose config | grep APP_MODE\ndocker compose up -d",
                    check: .all([
                        .contains(".env", "APP_MODE=production"),
                        .ranOK(#"docker[ -]compose\b.*\bconfig\b"#),
                        .labeled("dz.flow.mode", "production"),
                    ])),
            Mission("Layer compose.debug.yaml on top with -f and apply it",
                    hint: "Pass both files with `-f`, base first, then `up -d`.",
                    solution: "docker compose -f compose.yaml -f compose.debug.yaml up -d",
                    check: .all([
                        .ranOK(#"docker[ -]compose\b.*(-f|--file)[ =]\S*compose\.debug\.yaml.*\bup\b"#),
                        .labeled("dz.flow.debug", "true"),
                    ])),
            Mission("Run the tools service as a one-off that removes itself",
                    hint: "`run` starts a fresh container from a service. One flag deletes it when it exits.",
                    solution: "docker compose run --rm -T tools",
                    check: .ranOK(#"docker[ -]compose\b.*\brun\b(?=.*\s--rm\b).*\btools\b"#)),
            Mission("Scale the worker service to 3 replicas",
                    hint: "`up -d` takes `--scale SERVICE=N`.",
                    solution: "docker compose up -d --scale worker=3",
                    check: .all([
                        .container("dz-flow-worker-1", .running),
                        .container("dz-flow-worker-2", .running),
                        .container("dz-flow-worker-3", .running),
                    ])),
            Mission("Run hostname inside the second worker replica",
                    hint: "`exec` has an option to pick which replica.",
                    solution: "docker compose exec -T --index 2 worker hostname",
                    check: .ranOK(#"docker[ -]compose\b.*\bexec\b.*--index[ =]?2\b.*\bworker\b"#)),
        ]
    )

    // MARK: - Sharing Images

    static let shipping = Category(
        id: "shipping", title: "Sharing Images", icon: "shippingbox",
        blurb: "Tag, push and pull images through a registry, or carry them as a tar file.",
        lessons: [registries]
    )

    static let registries = Lesson(
        id: "registries",
        title: "Registries, push & pull",
        commands: ["docker tag", "docker push", "docker pull", "docker save", "docker load"],
        topics: ["Registries & repositories", "Docker Hub, GHCR, ECR", "Image names", "docker login", "Local registry", "docker tag", "docker push", "docker pull", "Registry API", "docker save / load"],
        summary: "A registry is where images live between machines. The image name says which registry to talk to, so pushing is really just tagging with the right name and running `docker push`.",
        sections: [
            S("Registries and repositories", """
            A **registry** is a server that stores images: Docker Hub, GitHub's `ghcr.io`, AWS ECR, Google Artifact Registry, or one you run yourself. Inside it, a **repository** holds the versions of one image, and each version is a **tag** (and an immutable `sha256:` digest).

            CI builds and pushes, servers and teammates pull. The registry is the hand-off point.
            """),
            S("The name is the address", """
            A full image name is `host[:port]/path/repo:tag`. If there's no host, Docker assumes Docker Hub, so `nginx:1.27-alpine` really means `docker.io/library/nginx:1.27-alpine`. `ghcr.io/acme/api:2.1` lives on GitHub. `localhost:5001/dz-alpine:1.0` lives on a registry on your own machine.

            `docker tag` adds a new name to an existing image without copying anything. One image can have many names.
            """, example: Example("docker tag \(Img.alpine) localhost:5001/dz-alpine:1.0\ndocker images localhost:5001/dz-alpine", output: "REPOSITORY              TAG       IMAGE ID       CREATED       SIZE\nlocalhost:5001/dz-alpine   1.0       91ef0af61f39   6 weeks ago   7.8MB")),
            S("Logging in", """
            `docker login ghcr.io` asks for a username and token and stores the credential in your OS keychain via a credential helper. Use access tokens, not your account password, and `docker logout` on shared machines. Pulling public images needs no login. Docker Hub does rate-limit anonymous pulls, though.

            You won't log in during this lesson. A registry on `localhost` needs no credentials, and Docker allows plain HTTP to `localhost` registries by default. Any other host must use HTTPS or be listed as an insecure registry.
            """),
            S("Run your own registry", """
            The `registry:2` image is a complete registry in one container. It listens on port 5000 inside, published here on host port **5001**. Push sends only the layers the registry doesn't have yet, and pull fetches only the ones you're missing.

            The registry speaks a simple HTTP API, so `curl` can show what's stored.
            """, example: Example("docker push localhost:5001/dz-alpine:1.0\ncurl -s localhost:5001/v2/_catalog", output: "The push refers to repository [localhost:5001/dz-alpine]\n63ca1fbb43ae: Pushed\n1.0: digest: sha256:33735bd6… size: 528\n{\"repositories\":[\"dz-alpine\"]}")),
            S("No registry? Use a tar file", """
            `docker save -o file.tar IMAGE` writes an image, with all its layers and tags, to a tar file. `docker load -i file.tar` reads it back on another machine. It's the way to move images onto air-gapped servers or attach one to a bug report. Pipe it through `gzip` to shrink it.

            Don't confuse it with `docker export`, which flattens a _container's_ filesystem and loses the image history.
            """, example: Example("docker save -o dz-alpine.tar localhost:5001/dz-alpine:1.0\ndocker load -i dz-alpine.tar", output: "Loaded image: localhost:5001/dz-alpine:1.0")),
        ],
        reference: [
            O("docker tag SRC NEW", "Give an image another name (no copy)"),
            O("docker push NAME:TAG", "Upload an image to the registry in its name"),
            O("docker push --all-tags NAME", "Push every tag of a repository"),
            O("docker pull NAME:TAG", "Download an image"),
            O("docker pull --platform linux/amd64 NAME", "Pull a specific architecture"),
            O("docker pull NAME@sha256:…", "Pull an exact, immutable digest"),
            O("docker login HOST", "Store credentials for a registry"),
            O("docker logout HOST", "Forget them"),
            O("docker run -d -p 5001:5000 registry:2", "Run a local registry"),
            O("curl HOST/v2/_catalog", "List repositories in a registry"),
            O("curl HOST/v2/REPO/tags/list", "List a repository's tags"),
            O("docker save -o FILE.tar IMAGE", "Write an image to a tar file"),
            O("docker load -i FILE.tar", "Load images from a tar file"),
            O("docker image inspect --format '{{.RepoDigests}}' IMG", "Show the digest an image was pulled by"),
        ],
        macNote: "Port 5000 is taken by AirPlay Receiver on macOS, which is why the registry is published on 5001. On an Apple silicon Mac, images you build are arm64. Servers are usually amd64, so build with `--platform linux/amd64` (or both, with `docker buildx build --platform linux/amd64,linux/arm64 --push`) before pushing images meant for them.",
        images: [Img.registry, Img.alpine],
        diagram: Diagram(
            "How an image travels",
            caption: "The name decides the destination: push to localhost:5001, Docker Hub, GHCR or ECR, and pull it anywhere that can reach that registry. Without a network, save to a tar and load it on the other side.",
            nodes: [
                N("cli", "docker tag", icon: "tag", .cli, at: 0, 1, detail: "name = address"),
                N("local", "Local image", icon: "square.stack.3d.up.fill", .image, at: 1, 1, detail: "localhost:5001/dz-alpine:1.0"),
                N("hub", "Docker Hub · GHCR · ECR", icon: "cloud", .registry, at: 1, 0, detail: "needs docker login"),
                N("reg", "dz-registry", icon: "server.rack", .registry, at: 2, 1, detail: "localhost:5001"),
                N("tar", "dz-alpine.tar", icon: "doc.plaintext", .file, at: 1, 2, detail: "docker save"),
                N("remote", "Another engine", icon: "desktopcomputer", .image, at: 2, 0, detail: "CI, server, teammate"),
                N("offline", "Offline machine", icon: "desktopcomputer", .image, at: 2, 2, detail: "no registry access"),
            ],
            groups: [G("Your machine", ["cli", "local"])],
            edges: [
                E("cli", "local", "names"),
                E("local", "hub", "push", dashed: true),
                E("local", "reg", "push"),
                E("local", "tar", "save", dashed: true),
                E("hub", "remote", "pull", dashed: true),
                E("reg", "remote", "pull"),
                E("tar", "offline", "load", dashed: true),
            ]
        ),
        missions: [
            Mission("Run a registry named dz-registry on host port 5001",
                    hint: "The registry image listens on 5000 inside the container. Map host 5001 to it.",
                    solution: "docker run -d --name dz-registry -p 5001:5000 \(Img.registry)",
                    check: .all([.container("dz-registry", .running), .publishes("dz-registry", 5001)])),
            Mission("Tag alpine as localhost:5001/dz-alpine:1.0",
                    hint: "`docker tag SOURCE TARGET`. The registry host goes at the front of the name.",
                    solution: "docker pull \(Img.alpine)\ndocker tag \(Img.alpine) localhost:5001/dz-alpine:1.0",
                    check: .image("localhost:5001/dz-alpine:1.0")),
            Mission("Push it to your registry",
                    hint: "`docker push` reads the destination from the name.",
                    solution: "docker push localhost:5001/dz-alpine:1.0",
                    check: .all([.container("dz-registry", .running), .ranOK(#"docker (image )?push\b.*localhost:5001/dz-alpine"#)])),
            Mission("List the registry's repositories with curl",
                    hint: "The registry API has a `/v2/_catalog` endpoint.",
                    solution: "curl -s localhost:5001/v2/_catalog",
                    check: .ranOK(#"curl\b.*(localhost|127\.0\.0\.1):5001/v2/_catalog"#)),
            Mission("Delete the local copy, then pull it back from the registry",
                    hint: "`docker rmi` the tag, then `docker pull` the same name.",
                    solution: "docker rmi localhost:5001/dz-alpine:1.0\ndocker pull localhost:5001/dz-alpine:1.0",
                    check: .all([
                        .ranOK(#"docker (rmi|image (rm|remove))\b.*localhost:5001/dz-alpine"#),
                        .ranOK(#"docker (image )?pull\b.*localhost:5001/dz-alpine"#),
                        .image("localhost:5001/dz-alpine:1.0"),
                    ])),
            Mission("Save the image to dz-alpine.tar, then load it back",
                    hint: "`docker save -o FILE IMAGE`, then `docker load -i FILE`.",
                    solution: "docker save -o dz-alpine.tar localhost:5001/dz-alpine:1.0\ndocker load -i dz-alpine.tar",
                    check: .all([
                        .exists("dz-alpine.tar", .file),
                        .ranOK(#"docker (image )?load\b.*dz-alpine\.tar"#),
                    ])),
        ]
    )

    // MARK: - Day-to-Day Operations

    static let operations = Category(
        id: "operations", title: "Day-to-Day Operations", icon: "wrench.and.screwdriver",
        blurb: "Reclaim disk space, debug crashing containers, and set limits and restart policies.",
        lessons: [cleanup, debugging, resources]
    )

    static let cleanup = Lesson(
        id: "cleanup",
        title: "Cleaning up disk space",
        commands: ["docker system df", "docker container prune", "docker image prune", "docker volume prune", "docker system prune"],
        topics: ["docker system df", "Dangling images", "container prune", "image prune", "volume prune", "network prune", "builder prune", "system prune", "--filter label=", "--filter until=", "Remove by name"],
        summary: "Docker never deletes anything on its own. Stopped containers, old images, unused volumes and build cache pile up until you prune them, and filters let you prune exactly what you mean.",
        sections: [
            S("Where the disk goes", """
            `docker system df` totals space by type: images, containers, local volumes and build cache. The **RECLAIMABLE** column is what nothing currently uses. Add `-v` for a per-item breakdown.

            The usual culprits are old image versions after many rebuilds and the BuildKit cache. Volumes come next, because databases grow.
            """, example: Example("docker system df", output: "TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE\nImages          14        3         2.31GB    1.87GB (80%)\nContainers      9         2         1.2MB     1.1MB (91%)\nLocal Volumes   6         2         410MB     380MB (92%)\nBuild Cache     52        0         1.04GB    1.04GB")),
            S("Prune, one type at a time", """
            Each type has its own `prune`: `docker container prune` removes **stopped** containers, `docker image prune` removes **dangling** images, `docker network prune` removes unused networks, and `docker builder prune` clears build cache. `-f` skips the "Are you sure?" prompt.

            `docker volume prune` only removes **anonymous** volumes since Docker 23. Named volumes need `-a`. That's deliberate, because volumes hold data.
            """, example: Example("docker container prune -f", output: "Deleted Containers:\n4f1c2a9e0b7d…\n9a8e7f6d5c4b…\n\nTotal reclaimed space: 1.1MB")),
            S("Dangling vs unused images", """
            When you rebuild `app:1.0`, the tag moves to the new image and the old one is left with no name: `<none>:<none>`. That's a **dangling** image, and `docker image prune` removes those.

            `docker image prune -a` goes further and removes every image **no container uses**, including ones you pulled on purpose. You'll be re-downloading them later.
            """, example: Example("docker images --filter dangling=true", output: "REPOSITORY   TAG       IMAGE ID       CREATED          SIZE\n<none>       <none>    5d2b1c8e9f0a   2 minutes ago    7.8MB")),
            S("Filters: prune only what you mean", """
            Every prune takes `--filter`. `label=dz.lesson=cleanup` limits it to resources carrying that label, and `until=24h` to things older than a day. Label what you create (`docker run --label team=api`) and cleanup becomes precise.

            To remove containers by name, feed IDs into `rm`: `docker rm -f $(docker ps -aq --filter name=dz-)`. The `name` filter matches a substring, so check the list with `docker ps -a --filter name=dz-` first.
            """, example: Example("docker ps -a --filter label=dz.lesson=cleanup --format \"{{.Names}}\\t{{.Status}}\"", output: "dz-clean-junk-3\tExited (0) 8 seconds ago\ndz-clean-junk-2\tExited (0) 9 seconds ago\ndz-clean-junk-1\tExited (0) 9 seconds ago")),
            S("The big hammer", """
            `docker system prune` removes stopped containers, unused networks, dangling images and build cache in one go. `docker system prune -a --volumes` also removes **every unused image and every unused volume**, which can include a database you meant to keep.

            Read the warning it prints before you type `y`. In this lesson you'll stick to labelled resources so your own work is never touched.
            """),
        ],
        reference: [
            O("docker system df [-v]", "Disk usage by type (verbose: per item)"),
            O("docker container prune -f", "Remove all stopped containers"),
            O("docker image prune -f", "Remove dangling (<none>) images"),
            O("docker image prune -a -f", "Remove every image no container uses"),
            O("docker volume prune -f", "Remove unused anonymous volumes"),
            O("docker volume prune -a -f", "Remove unused named volumes too"),
            O("docker network prune -f", "Remove unused networks"),
            O("docker builder prune -f", "Clear the BuildKit cache"),
            O("docker system prune", "Containers, networks, dangling images, build cache"),
            O("docker system prune -a --volumes", "Everything unused, including images and volumes (careful!)"),
            O("--filter label=KEY=VALUE", "Only resources with that label"),
            O("--filter until=24h", "Only resources older than 24 hours"),
            O("docker images --filter dangling=true", "List dangling images"),
            O("docker rm -f $(docker ps -aq --filter name=PREFIX)", "Remove every container whose name contains PREFIX"),
        ],
        macNote: "Docker on a Mac stores everything in one Linux VM disk image, which grows but doesn't always shrink by itself. After a big prune, Docker Desktop and OrbStack usually hand the space back to macOS; on Colima you may need to restart the VM. Docker Desktop's Troubleshoot → Clean / Purge data wipes all of it.",
        images: [Img.alpine],
        diagram: Diagram(
            "What each prune removes",
            caption: "Each prune command targets one kind of leftover. They all free space on the engine's disk, which on a Mac is the Linux VM's disk image. Filters narrow any of them to labelled or older resources.",
            nodes: [
                N("cp", "container prune", icon: "terminal", .cli, at: 0, 0),
                N("ip", "image prune", icon: "terminal", .cli, at: 0, 1),
                N("vp", "volume prune -a", icon: "terminal", .cli, at: 0, 2),
                N("stopped", "Stopped containers", icon: "shippingbox", .container, at: 1, 0, detail: "Exited (…)"),
                N("dangling", "Dangling images", icon: "square.stack.3d.up", .image, at: 1, 1, detail: "<none>:<none>"),
                N("vols", "Unused volumes", icon: "externaldrive", .storage, at: 1, 2, detail: "no container uses them"),
                N("disk", "Engine disk", icon: "internaldrive", .host, at: 2, 1, detail: "docker system df"),
                N("cache", "Build cache", icon: "hammer", .daemon, at: 3, 1, detail: "BuildKit layers"),
                N("bp", "builder prune", icon: "terminal", .cli, at: 4, 1),
            ],
            groups: [G("Reclaimable", ["stopped", "dangling", "vols"])],
            edges: [
                E("cp", "stopped", "removes"),
                E("ip", "dangling", "removes"),
                E("vp", "vols", "removes"),
                E("dangling", "disk", "frees"),
                E("bp", "cache", "removes"),
                E("cache", "disk", "frees"),
            ]
        ),
        seed: Seed(files: [
            F("Dockerfile", """
            FROM \(Img.alpine)
            LABEL dz.lesson=cleanup-image
            RUN echo v1 > /version
            CMD ["cat", "/version"]

            """),
        ]),
        missions: [
            Mission("See how much disk Docker is using",
                    hint: "It's a `system` subcommand named like the Unix `df`.",
                    solution: "docker system df",
                    check: .ranOK(#"docker system df\b"#)),
            Mission("Create three stopped containers labelled dz.lesson=cleanup",
                    hint: "Run alpine with `--label dz.lesson=cleanup` and a command that exits at once. A for loop saves typing.",
                    solution: "for i in 1 2 3; do docker run --name dz-clean-junk-$i --label dz.lesson=cleanup \(Img.alpine) echo junk $i; done",
                    check: .all([
                        .ranOK(#"docker (container )?(run|create)\b.*--label[ =]dz\.lesson=cleanup\b"#),
                        .labeled("dz.lesson", "cleanup"),
                    ])),
            Mission("List them with a label filter, then prune only those",
                    hint: "`docker ps -a --filter ...` to look, then `docker container prune -f` with the same filter.",
                    solution: "docker ps -a --filter label=dz.lesson=cleanup\ndocker container prune -f --filter label=dz.lesson=cleanup",
                    check: .all([
                        .ranOK(#"docker container prune\b.*--filter[ =]\"?label=dz\.lesson=cleanup\b"#),
                        .not(.labeled("dz.lesson", "cleanup")),
                    ])),
            Mission("Build dz-clean:1, change the Dockerfile, and build it again",
                    hint: "Change the RUN line (or add another) so the rebuild produces a new image. The old one becomes dangling.",
                    solution: "docker build -t dz-clean:1 .\necho 'RUN echo v2 > /version' >> Dockerfile\ndocker build -t dz-clean:1 .",
                    check: .all([.image("dz-clean:1"), .contains("Dockerfile", "v2")])),
            Mission("Find the dangling image and prune it by label",
                    hint: "`docker images --filter dangling=true`, then `docker image prune -f` filtered on the Dockerfile's label.",
                    solution: "docker images --filter dangling=true\ndocker image prune -f --filter label=dz.lesson=cleanup-image",
                    check: .all([
                        .ranOK(#"docker image prune\b.*--filter[ =]\"?label=dz\.lesson=cleanup-image\b"#),
                        .image("dz-clean:1"),
                    ])),
            Mission("Create a labelled volume dz-clean-cache, then prune it",
                    hint: "`docker volume create --label ...`. Named volumes only go with `volume prune -a`.",
                    solution: "docker volume create --label dz.lesson=cleanup dz-clean-cache\ndocker volume prune -a -f --filter label=dz.lesson=cleanup",
                    check: .all([
                        .ranOK(#"docker volume create\b.*dz-clean-cache"#),
                        .ranOK(#"docker volume prune\b.*label=dz\.lesson=cleanup\b"#),
                        .not(.volume("dz-clean-cache")),
                    ])),
        ]
    )

    static let debugging = Lesson(
        id: "debugging",
        title: "Debugging containers",
        commands: ["docker ps -a", "docker logs --tail", "docker inspect", "docker exec", "docker events"],
        topics: ["Exit codes", "docker logs --tail", "docker inspect --format", "docker wait", "docker exec", "--entrypoint sh", "docker events", "HEALTHCHECK", "Health status"],
        summary: "When a container won't stay up, the engine already knows why: the exit code, the last log lines and the event history. Read those first, then get a shell in the image to look around.",
        sections: [
            S("Read the exit code", """
            `docker ps -a` shows `Exited (N)` for stopped containers. The code tells you where to look. **0** finished normally. **1** (or 2) is the app's own error, so read the logs. **126/127** means the command couldn't be run or wasn't found, so check CMD, ENTRYPOINT and PATH. **137** is SIGKILL: out of memory or `docker kill`. **143** is SIGTERM from a normal `docker stop`.

            `docker inspect --format '{{.State.ExitCode}}' NAME` prints just the number, and `{{.State.OOMKilled}}` confirms a memory kill.
            """, example: Example("docker ps -a --filter name=dz-debug", output: "CONTAINER ID   IMAGE             COMMAND                  CREATED          STATUS                      NAMES\n3e1d0c9b8a7f   dz-debug:broken   \"python /app/server.…\"   20 seconds ago   Exited (2) 19 seconds ago   dz-debug-broken")),
            S("Logs first", """
            A crashed container's logs are still there until you remove it. `docker logs --tail 20 NAME` shows the end, where the error usually is. `--timestamps` helps match events, and `-f` follows a live one.

            `docker wait NAME` blocks until the container stops and prints its exit code. It's useful in scripts and for catching a container that dies right after starting.
            """, example: Example("docker logs --tail 5 dz-debug-broken", output: "python: can't open file '/app/server.py': [Errno 2] No such file or directory")),
            S("Look inside", """
            For a **running** container, `docker exec -it NAME sh` gives you a shell next to the app: check files, env (`env`), and connectivity (`wget -qO- localhost:8000`).

            A container that crashes at start can't be exec'd into. Start a new one from the same image with `--entrypoint sh` to replace the command, then look around for what the CMD expected.
            """, example: Example("docker run --rm --entrypoint sh dz-debug:broken -c 'ls /app'", output: "app.py")),
            S("The event timeline", """
            `docker events` streams what the engine does: create, start, die, kill, oom, health_status. With `--since 10m --until 0s` it replays the last ten minutes and exits. Filter with `--filter container=NAME` or `--filter event=die`.

            A crash loop under a restart policy shows up as die → start → die, over and over.
            """, example: Example("docker events --since 10m --until 0s --filter container=dz-debug-broken", output: "2026-10-17T09:12:03 container create 3e1d… (image=dz-debug:broken, name=dz-debug-broken)\n2026-10-17T09:12:03 container start 3e1d… (image=dz-debug:broken, name=dz-debug-broken)\n2026-10-17T09:12:04 container die 3e1d… (exitCode=2, image=dz-debug:broken, name=dz-debug-broken)")),
            S("Health checks", """
            A process can be running and still broken. `HEALTHCHECK CMD ...` in a Dockerfile (or `healthcheck:` in Compose) tells the engine how to test it. The status moves from `starting` to `healthy`, or to `unhealthy` after N failures in a row, and shows in `docker ps`.

            Docker itself doesn't restart unhealthy containers. Compose's `service_healthy`, orchestrators and your monitoring act on the status.
            """, example: Example("docker inspect --format '{{.State.Health.Status}}' dz-debug-ok", output: "healthy")),
        ],
        reference: [
            O("docker ps -a", "Show stopped containers and their exit codes"),
            O("docker ps -a --filter status=exited", "Only containers that have stopped"),
            O("docker logs --tail N NAME", "Last N log lines"),
            O("docker logs --since 5m -t NAME", "Recent lines with timestamps"),
            O("docker inspect --format '{{.State.ExitCode}}' NAME", "Exit code of the last run"),
            O("docker inspect --format '{{.State.OOMKilled}}' NAME", "Whether the kernel killed it for memory"),
            O("docker inspect --format '{{json .State.Health}}' NAME", "Health status and recent probe output"),
            O("docker wait NAME", "Block until the container stops; print its exit code"),
            O("docker exec -it NAME sh", "Shell inside a running container"),
            O("docker run --rm -it --entrypoint sh IMAGE", "Shell in an image whose CMD crashes"),
            O("docker events --since 10m --until 0s", "Replay recent engine events and exit"),
            O("docker events --filter event=die", "Watch for containers dying"),
            O("HEALTHCHECK --interval=5s CMD …", "Dockerfile: how the engine probes the app"),
            O("docker cp NAME:/path ./here", "Copy a file out of a (even stopped) container"),
        ],
        macNote: "Containers run in a Linux VM, so `ps` or Activity Monitor on your Mac won't show the app's processes. Use `docker top NAME` or `docker exec NAME ps` instead. Exit code 137 often means the container hit the VM's memory limit, which is set in Docker Desktop's Settings → Resources.",
        images: [Img.python],
        diagram: Diagram(
            "Where to look when a container dies",
            caption: "The image starts a container, the process exits, and a restart policy may start it again: a crash loop. The exit code, the logs and inspect each tell part of the story. Fix the Dockerfile, rebuild, and the healthcheck confirms it's really working.",
            nodes: [
                N("hc", "HEALTHCHECK", icon: "stethoscope", .daemon, at: 1, 0, detail: "starting → healthy"),
                N("logs", "docker logs --tail", icon: "list.bullet.rectangle", .cli, at: 2, 0, detail: "the error message"),
                N("img", "dz-debug:broken", icon: "square.stack.3d.up", .image, at: 0, 1),
                N("ctr", "Running", icon: "shippingbox.fill", .container, at: 1, 1, detail: "python …"),
                N("dead", "Exited (2)", icon: "shippingbox", .container, at: 2, 1, detail: "docker ps -a"),
                N("inspect", "docker inspect", icon: "magnifyingglass", .cli, at: 3, 1, detail: ".State.ExitCode"),
                N("fix", "Dockerfile", icon: "doc.text", .file, at: 4, 1, detail: "fix CMD, rebuild"),
            ],
            edges: [
                E("img", "ctr", "run"),
                E("ctr", "dead", "process exits"),
                E("dead", "ctr", "restart policy", dashed: true, loopBack: true),
                E("hc", "ctr", "probes", dashed: true),
                E("dead", "logs", "why?"),
                E("dead", "inspect", "how?"),
                E("inspect", "fix"),
            ]
        ),
        seed: Seed(files: [
            F("Dockerfile", """
            FROM \(Img.python)
            WORKDIR /app
            ENV PYTHONUNBUFFERED=1
            COPY app.py .
            EXPOSE 8000
            HEALTHCHECK --interval=3s --timeout=2s --retries=3 \\
              CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"
            CMD ["python", "/app/server.py"]

            """),
            F("app.py", #"""
            import signal
            import sys
            from http.server import BaseHTTPRequestHandler, HTTPServer


            class Handler(BaseHTTPRequestHandler):
                def do_GET(self):
                    body = b"ok\n" if self.path == "/health" else b"dz-debug is up\n"
                    self.send_response(200)
                    self.send_header("Content-Type", "text/plain")
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)

                def log_message(self, fmt, *args):
                    if self.path != "/health":
                        super().log_message(fmt, *args)


            signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
            print("dz-debug listening on :8000")
            HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()

            """#),
        ]),
        missions: [
            Mission("Build the image as dz-debug:broken",
                    hint: "A normal build of this folder with that tag.",
                    solution: "docker build -t dz-debug:broken .",
                    check: .image("dz-debug:broken")),
            Mission("Run it as dz-debug-broken in the background and wait for it to die",
                    hint: "`docker run -d --name ...`, then `docker wait` blocks until it stops and prints the exit code.",
                    solution: "docker run -d --name dz-debug-broken dz-debug:broken\ndocker wait dz-debug-broken",
                    check: .all([
                        .ranOK(#"docker (container )?run\b.*--name[ =]dz-debug-broken\b"#),
                        .container("dz-debug-broken", .stopped),
                    ])),
            Mission("Read its last log lines and its exit code",
                    hint: "`docker logs --tail`, then `docker inspect --format` with `{{.State.ExitCode}}`.",
                    solution: "docker logs --tail 20 dz-debug-broken\ndocker inspect --format '{{.State.ExitCode}}' dz-debug-broken",
                    check: .all([
                        .ranOK(#"docker (container )?logs\b.*dz-debug-broken"#),
                        .ranOK(#"docker (container )?inspect\b.*State\.ExitCode.*dz-debug-broken|docker (container )?inspect\b.*dz-debug-broken.*State\.ExitCode"#),
                    ])),
            Mission("Open the image with --entrypoint sh and list /app",
                    hint: "Replace the crashing command: `docker run --rm --entrypoint sh IMAGE -c 'ls /app'`.",
                    solution: "docker run --rm --entrypoint sh dz-debug:broken -c 'ls -l /app'",
                    check: .ranOK(#"docker (container )?run\b.*--entrypoint[ =]\"?(/bin/)?sh\b.*dz-debug:broken"#)),
            Mission("Fix the CMD, build dz-debug:fixed and run it as dz-debug-ok on port 8088",
                    hint: "The file in /app isn't called server.py. Edit the Dockerfile, rebuild with the new tag, and run it with `-d -p 8088:8000`.",
                    solution: "perl -pi -e 's/server\\.py/app.py/' Dockerfile\ndocker build -t dz-debug:fixed .\ndocker run -d --name dz-debug-ok -p 8088:8000 dz-debug:fixed",
                    check: .all([
                        .not(.contains("Dockerfile", "server.py")),
                        .image("dz-debug:fixed"),
                        .container("dz-debug-ok", .running),
                        .publishes("dz-debug-ok", 8088),
                    ])),
            Mission("Check dz-debug-ok's health, then replay the last 10 minutes of events",
                    hint: "Health is under `.State.Health.Status`. `docker events` needs `--until` to stop on its own.",
                    solution: "docker inspect --format '{{.State.Health.Status}}' dz-debug-ok\ndocker events --since 10m --until 0s --filter container=dz-debug-broken",
                    check: .all([
                        .ranOK(#"docker (container )?inspect\b.*Health"#),
                        .ranOK(#"docker (system )?events\b.*--until"#),
                    ])),
        ]
    )

    static let resources = Lesson(
        id: "resources-and-restarts",
        title: "Limits, restarts & hardening",
        commands: ["docker run --memory", "docker run --cpus", "docker stats", "docker update", "docker run --restart"],
        topics: ["--memory", "--cpus", "docker stats --no-stream", "docker update", "Restart policies", "--read-only", "--cap-drop", "--user", "--init", "Labels"],
        summary: "By default a container can use all the memory and CPU it likes and runs as root. A few flags cap its resources, keep it running through crashes, and take away privileges it doesn't need.",
        sections: [
            S("Cap memory and CPU", """
            `--memory 64m` (or `-m`) is a hard ceiling. A process that goes over is killed by the kernel and the container exits with **137**, with `OOMKilled: true` in inspect. `--cpus 0.5` allows half a CPU's worth of time. Going over that doesn't kill anything, the process is just throttled.

            Both are enforced by Linux **cgroups**, the same kernel feature that every container already runs in.
            """, example: Example("docker run -d --name dz-limits-web --memory 64m --cpus 0.5 \(Img.nginx)\ndocker inspect --format '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' dz-limits-web", output: "67108864 500000000")),
            S("Watch and adjust", """
            `docker stats` shows live CPU, memory against the limit, network and disk I/O. Add `--no-stream` for a single snapshot you can paste or script.

            `docker update` changes limits on a running container without restarting it: `docker update --memory 128m --memory-swap 256m NAME`. It can change the restart policy too.
            """, example: Example("docker stats --no-stream dz-limits-web", output: "CONTAINER ID   NAME            CPU %     MEM USAGE / LIMIT   MEM %     NET I/O       BLOCK I/O   PIDS\n7c2d9e1f0a3b   dz-limits-web   0.00%     3.1MiB / 64MiB      4.84%     1.2kB / 0B    0B / 4kB    5")),
            S("Restart policies", """
            `--restart` tells the engine what to do when the main process exits. `no` (the default) leaves it stopped. `on-failure[:N]` restarts only after a non-zero exit, at most N times. `always` restarts no matter what, and also when the engine starts. `unless-stopped` is like `always`, but stays down after you `docker stop` it.

            Restarts back off (100ms, 200ms, 400ms… up to a minute), so a crash loop doesn't eat the CPU. `docker inspect --format '{{.RestartCount}}'` tells you how many it has done.
            """, example: Example("docker ps -a --filter name=dz-limits-crash", output: "STATUS                                  NAMES\nRestarting (1) Less than a second ago   dz-limits-crash")),
            S("Take away what it doesn't need", """
            `--read-only` mounts the root filesystem read-only, so an attacker (or a bug) can't modify the app. Add `--tmpfs /tmp` if it needs scratch space. `--cap-drop ALL` removes Linux capabilities like changing file ownership or binding ports below 1024. Add back only what's needed with `--cap-add`.

            `--user 65534:65534` runs as an unprivileged user instead of root. `--init` puts a tiny init process at PID 1 that forwards signals and reaps zombies, so `docker stop` is instant instead of waiting 10 seconds.
            """, example: Example("docker exec dz-limits-locked sh -c 'id; touch /x'", output: "uid=65534(nobody) gid=65534(nobody) groups=65534(nobody)\ntouch: /x: Read-only file system")),
            S("Label everything", """
            `--label team=payments --label env=dev` costs nothing and makes every later command precise: `docker ps --filter label=team=payments`, `docker stats $(docker ps -q --filter label=env=dev)`, and pruning by label. Compose already labels its containers with the project and service names.
            """),
        ],
        reference: [
            O("--memory 256m  /  -m 256m", "Hard memory limit (exceeding it → OOM kill, exit 137)"),
            O("--memory-swap 512m", "Memory + swap limit (equal to --memory: no swap)"),
            O("--cpus 1.5", "Limit to 1.5 CPUs' worth of time"),
            O("--pids-limit 100", "Cap the number of processes (stops fork bombs)"),
            O("docker stats --no-stream", "One snapshot of CPU, memory, I/O per container"),
            O("docker update --memory 512m --memory-swap 1g NAME", "Change limits on a running container"),
            O("docker update --restart unless-stopped NAME", "Change the restart policy"),
            O("--restart on-failure:3", "Restart after non-zero exits, at most 3 times"),
            O("--restart always / unless-stopped", "Keep it running, also across engine restarts"),
            O("--read-only [--tmpfs /tmp]", "Read-only root filesystem, optional scratch space"),
            O("--cap-drop ALL [--cap-add NET_BIND_SERVICE]", "Drop all capabilities, add back only what's needed"),
            O("--user UID:GID", "Run as a non-root user"),
            O("--security-opt no-new-privileges", "Block setuid privilege escalation"),
            O("--init", "Tiny init as PID 1: forwards signals, reaps zombies"),
            O("--label KEY=VALUE", "Tag a container for filtering and cleanup"),
        ],
        macNote: "Limits apply inside Docker's Linux VM, which has its own CPU and memory budget (Docker Desktop: Settings → Resources; Colima: `colima start --cpu 4 --memory 8`). A container can never use more than the VM has, and without `--memory`, `docker stats` shows the VM's total as the limit. `always` and `unless-stopped` containers come back when the VM starts, not when your Mac boots.",
        images: [Img.nginx, Img.alpine],
        diagram: Diagram(
            "cgroups around a container",
            caption: "The kernel puts every container in a cgroup. --memory and --cpus set that cgroup's limits: too much memory means an OOM kill (137), too much CPU means throttling. When the process exits, the engine's restart policy decides whether it comes back.",
            nodes: [
                N("stats", "docker stats / update", icon: "waveform.path.ecg", .cli, at: 1, 0, detail: "watch, adjust live"),
                N("mem", "memory.max", icon: "memorychip", .host, at: 2, 0, detail: "--memory 64m"),
                N("kernel", "Linux kernel", icon: "cpu", .host, at: 0, 1, detail: "in the Docker VM"),
                N("cg", "cgroup", icon: "square.stack.3d.up", .host, at: 1, 1, detail: "one per container"),
                N("ctr", "dz-limits-web", icon: "shippingbox.fill", .container, at: 2, 1, detail: "--read-only, --cap-drop ALL"),
                N("engine", "dockerd", icon: "gearshape.2", .daemon, at: 3, 1, detail: "--restart on-failure:3"),
                N("cpu", "cpu.max", icon: "cpu", .host, at: 2, 2, detail: "--cpus 0.5"),
            ],
            groups: [G("cgroup limits", ["mem", "ctr", "cpu"])],
            edges: [
                E("kernel", "cg", "enforces"),
                E("stats", "cg", "reads / updates"),
                E("cg", "ctr", "contains"),
                E("mem", "ctr", "OOM kill → 137", dashed: true),
                E("cpu", "ctr", "throttles", dashed: true),
                E("ctr", "engine", "exits"),
                E("engine", "ctr", "restarts", dashed: true, loopBack: true),
            ]
        ),
        missions: [
            Mission("Run nginx as dz-limits-web with 64 MB of memory and half a CPU",
                    hint: "`docker run -d` with `--memory` and `--cpus`. Add `--label dz.lesson=limits` while you're at it.",
                    solution: "docker run -d --name dz-limits-web --memory 64m --cpus 0.5 --label dz.lesson=limits \(Img.nginx)",
                    check: .all([
                        .container("dz-limits-web", .running),
                        .ranOK(#"docker (container )?run\b(?=.*dz-limits-web).*(--memory|\s-m)[ =]"#),
                        .ranOK(#"docker (container )?run\b(?=.*dz-limits-web).*--cpus[ =]"#),
                    ])),
            Mission("Confirm the limits with docker inspect",
                    hint: "They live under `.HostConfig.Memory` and `.HostConfig.NanoCpus`.",
                    solution: "docker inspect --format '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' dz-limits-web",
                    check: .ranOK(#"docker (container )?inspect\b.*HostConfig\.(Memory|NanoCpus)"#)),
            Mission("Take one snapshot of its resource usage",
                    hint: "`docker stats` streams forever unless you tell it not to.",
                    solution: "docker stats --no-stream dz-limits-web",
                    check: .ranOK(#"docker (container )?stats\b.*--no-stream"#)),
            Mission("Raise its memory limit to 128 MB without restarting it",
                    hint: "`docker update`. Raise `--memory-swap` along with it so it stays above the memory limit.",
                    solution: "docker update --memory 128m --memory-swap 256m dz-limits-web",
                    check: .all([
                        .ranOK(#"docker (container )?update\b.*(--memory|\s-m)[ =].*dz-limits-web|docker (container )?update\b.*dz-limits-web.*(--memory|\s-m)"#),
                        .container("dz-limits-web", .running),
                    ])),
            Mission("Run a crashing dz-limits-crash with --restart on-failure:3 and count its restarts",
                    hint: "Use alpine with `sh -c 'sleep 1; exit 1'`, then read `{{.RestartCount}}` with inspect.",
                    solution: "docker run -d --name dz-limits-crash --restart on-failure:3 --label dz.lesson=limits \(Img.alpine) sh -c 'echo crashing; sleep 1; exit 1'\ndocker inspect --format '{{.RestartCount}} {{.State.Status}}' dz-limits-crash",
                    check: .all([
                        .container("dz-limits-crash", .exists),
                        .ranOK(#"docker (container )?run\b.*--restart[ =]on-failure"#),
                        .ranOK(#"docker (container )?inspect\b.*RestartCount"#),
                    ])),
            Mission("Run a locked-down dz-limits-locked: read-only, no capabilities, non-root, with --init",
                    hint: "`--read-only --cap-drop ALL --user 65534:65534 --init` on an alpine running `sleep 3600`. Then try writing a file with exec.",
                    solution: "docker run -d --name dz-limits-locked --read-only --cap-drop ALL --user 65534:65534 --init --restart unless-stopped --label dz.lesson=limits \(Img.alpine) sleep 3600\ndocker exec dz-limits-locked sh -c 'id; touch /x || echo blocked'",
                    check: .all([
                        .container("dz-limits-locked", .running),
                        .ranOK(#"docker (container )?run\b(?=.*dz-limits-locked).*--read-only\b"#),
                        .ranOK(#"docker (container )?run\b(?=.*dz-limits-locked).*--cap-drop[ =]\"?ALL"#),
                    ])),
        ]
    )
}
