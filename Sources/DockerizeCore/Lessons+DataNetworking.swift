import Foundation

extension Curriculum {
    // MARK: - Data & Storage

    static let data = Category(
        id: "data", title: "Data & Storage", icon: "externaldrive",
        blurb: "Keep data alive past docker rm with volumes, and edit code live with bind mounts.",
        lessons: [volumes, bindMounts]
    )

    static let volumes = Lesson(
        id: "volumes",
        title: "Volumes",
        commands: ["docker volume create", "docker volume ls", "docker volume inspect", "docker volume rm", "docker volume prune"],
        topics: ["The writable layer", "Named volumes", "-v vs --mount", "Sharing a volume", "Anonymous volumes", "docker volume"],
        summary: "Anything a container writes to its own filesystem disappears with `docker rm`. A volume is storage Docker manages for you, outside the container, so the data outlives any one container.",
        sections: [
            S("The writable layer is temporary", """
            Every container gets a thin **writable layer** on top of its image. Files you create or change go there, and they survive `docker stop` and `docker start`.

            They do **not** survive `docker rm`. Remove the container and the layer goes with it. That's fine for scratch files and terrible for a database. The fix is to keep the data somewhere that isn't the container.
            """, example: Example("docker run --name dz-vol-tmp \(Img.alpine) sh -c 'echo hi > /note.txt'\ndocker rm dz-vol-tmp   # /note.txt is gone for good")),
            S("Named volumes", """
            A **volume** is a directory Docker creates and manages under `/var/lib/docker/volumes/`. You refer to it by name and never need to know where it lives.

            `docker volume create dz-data` makes one. `docker volume ls` lists them, `docker volume inspect` shows the details, and `docker volume rm` deletes one (only when no container is using it).
            """, example: Example("docker volume inspect dz-vol-data", output: "[\n    {\n        \"CreatedAt\": \"2026-10-17T09:12:44Z\",\n        \"Driver\": \"local\",\n        \"Labels\": null,\n        \"Mountpoint\": \"/var/lib/docker/volumes/dz-vol-data/_data\",\n        \"Name\": \"dz-vol-data\",\n        \"Options\": null,\n        \"Scope\": \"local\"\n    }\n]")),
            S("Mounting: -v or --mount", """
            `-v NAME:/path` mounts volume NAME at `/path` inside the container. If the volume doesn't exist yet, Docker creates it. If the volume is empty and the image already has files at `/path`, Docker copies them in first.

            `--mount type=volume,src=NAME,dst=/path` does the same thing with explicit keys. It's longer but easier to read in scripts, and it fails loudly on typos instead of guessing. Add `:ro` (or `,readonly`) to mount it read-only.
            """, example: Example("docker run --rm -v dz-vol-data:/data \(Img.alpine) sh -c 'echo hello > /data/hello.txt'\ndocker run --rm --mount type=volume,src=dz-vol-data,dst=/data \(Img.alpine) cat /data/hello.txt", output: "hello")),
            S("Volumes outlive containers", """
            Mount the same volume into as many containers as you like, at the same time or one after another. A throwaway container can write a file and a second one can read it back.

            This is how you upgrade a database: stop and remove the old container, start a new one from a newer image with the same volume, and the data is still there.
            """, example: Example("docker rm -f dz-vol-redis\ndocker volume ls", output: "DRIVER    VOLUME NAME\nlocal     dz-vol-data")),
            S("Anonymous volumes", """
            Some images declare `VOLUME /data` in their Dockerfile (redis and most databases do). If you don't mount anything there, Docker creates an **anonymous volume** with a long random name, so `docker volume ls` slowly fills with hex strings.

            `--rm` and `docker rm -v` delete a container's anonymous volumes with it. `docker volume prune` removes unused anonymous volumes. Add `-a` to also remove unused **named** ones, so check what you're about to lose first.
            """, example: Example("docker volume ls", output: "DRIVER    VOLUME NAME\nlocal     3f9c1e0b7a54d2c8e61f0a9b4d7e2c13a5b8f6e09d1c4a7b2e5f8c0d3a6b9e12\nlocal     dz-vol-data")),
        ],
        reference: [
            O("docker volume create NAME", "Create a named volume"),
            O("docker volume ls", "List volumes"),
            O("docker volume ls -f dangling=true", "List volumes no container uses"),
            O("docker volume inspect NAME", "Show driver, mountpoint, labels and options"),
            O("docker volume rm NAME", "Delete a volume (it must not be in use)"),
            O("docker volume prune", "Delete unused anonymous volumes"),
            O("docker volume prune -a", "Delete all unused volumes, named ones too"),
            O("-v NAME:/path", "Mount a named volume (created if missing)"),
            O("-v NAME:/path:ro", "Mount it read-only"),
            O("--mount type=volume,src=NAME,dst=/path", "Explicit form of -v NAME:/path"),
            O("-v /path", "Mount a new anonymous volume at /path"),
            O("docker rm -v CONTAINER", "Remove a container and its anonymous volumes"),
            O("docker run --volumes-from C ...", "Mount every volume container C uses"),
        ],
        macNote: "Volumes live inside Docker's Linux VM, not on your Mac's disk, so you won't find them in Finder. `/var/lib/docker/volumes` only exists in the VM. Because they never cross the VM boundary, volumes are much faster than bind mounts for databases and `node_modules`. To get files out, use `docker cp` or mount the volume next to a bind mount and copy across.",
        images: [Img.alpine, Img.redis],
        diagram: Diagram(
            "One volume, many containers",
            caption: "dockerd creates dz-vol-data inside the Linux VM. A throwaway container writes to it, a second reads it back and redis keeps its data there. Anything written outside the volume lands in the container's writable layer and is lost on rm.",
            nodes: [
                N("cli", "docker volume create", icon: "terminal", .cli, at: 0, 1, detail: "dz-vol-data"),
                N("dockerd", "dockerd", icon: "gearshape.2", .daemon, at: 1, 1, detail: "manages volumes"),
                N("vol", "dz-vol-data", icon: "cylinder", .storage, at: 2, 1, detail: "/var/lib/docker/volumes"),
                N("writer", "alpine (writer)", icon: "cube", .container, at: 2, 0, detail: "--rm, writes hello.txt"),
                N("layer", "Writable layer", icon: "square.stack.3d.up", .storage, at: 3, 0, detail: "gone on rm"),
                N("reader", "alpine (reader)", icon: "cube", .container, at: 3, 1, detail: "cat /data/hello.txt"),
                N("redis", "dz-vol-redis", icon: "cube.fill", .container, at: 2, 2, detail: "/data"),
            ],
            groups: [G("Linux VM", ["dockerd", "vol", "writer", "layer", "reader", "redis"])],
            edges: [
                E("cli", "dockerd", "create"),
                E("dockerd", "vol", "makes"),
                E("writer", "vol", "writes"),
                E("writer", "layer", "other files", dashed: true),
                E("reader", "vol", "reads"),
                E("redis", "vol", "-v dz-vol-data:/data"),
            ]
        ),
        missions: [
            Mission("Create a volume named dz-vol-data",
                    hint: "It's a `docker volume` subcommand.",
                    solution: "docker volume create dz-vol-data",
                    check: .volume("dz-vol-data")),
            Mission("From a throwaway alpine container, write a file into dz-vol-data",
                    hint: "Use `--rm`, mount the volume with `-v dz-vol-data:/data`, and run `sh -c 'echo ... > /data/hello.txt'`.",
                    solution: "docker run --rm -v dz-vol-data:/data \(Img.alpine) sh -c 'echo hello > /data/hello.txt'",
                    check: .all([.volume("dz-vol-data"), .ranOK(#"docker (container )?run\b.*dz-vol-data.*(>|\btee\b|\btouch\b)"#)])),
            Mission("Read the file back from a second container",
                    hint: "A brand-new container, the same volume, and `cat`.",
                    solution: "docker run --rm -v dz-vol-data:/data \(Img.alpine) cat /data/hello.txt",
                    check: .ranOK(#"docker (container )?run\b.*dz-vol-data.*\b(cat|ls|head|more|less)\b"#)),
            Mission("Run redis as dz-vol-redis with dz-vol-data mounted at /data",
                    hint: "Detach it with `-d`, name it, and mount the volume where redis keeps its data.",
                    solution: "docker run -d --name dz-vol-redis -v dz-vol-data:/data \(Img.redis)",
                    check: .all([.container("dz-vol-redis", .running), .mounts("dz-vol-redis", "dz-vol-data")])),
            Mission("Inspect dz-vol-data to see where it lives",
                    hint: "`docker volume` has an inspect subcommand too.",
                    solution: "docker volume inspect dz-vol-data",
                    check: .ranOK(#"docker volume inspect\b.*dz-vol-data"#)),
            Mission("Remove dz-vol-redis and show the volume is still there",
                    hint: "Force-remove the container, then list volumes.",
                    solution: "docker rm -f dz-vol-redis\ndocker volume ls",
                    check: .all([
                        .ranOK(#"docker (container )?rm\b.*dz-vol-redis"#),
                        .not(.container("dz-vol-redis", .exists)),
                        .volume("dz-vol-data"),
                        .ranOK(#"docker volume (ls|list)\b"#),
                    ])),
        ]
    )

    static let bindMounts = Lesson(
        id: "bind-mounts",
        title: "Bind mounts & tmpfs",
        commands: ["docker run -v", "docker run --mount", "docker run --tmpfs"],
        topics: ["Bind mounts", "Live editing", "Read-only mounts", "tmpfs", "Volume vs bind vs tmpfs", "File sharing on a Mac"],
        summary: "A bind mount puts a folder from your machine inside a container, so edits on the host show up instantly. tmpfs gives a container scratch space that lives only in memory.",
        sections: [
            S("Bind mounts", """
            A **bind mount** maps a host path straight into the container: `-v "$(pwd)/site":/usr/share/nginx/html`. There's no copy. The container sees your real files, and changes go both ways.

            The host side must be an absolute path (or start with `./`). Quote `"$(pwd)"`, because paths with spaces break otherwise. `--mount type=bind,src=...,dst=...` is the explicit form, and unlike `-v` it errors if the source folder doesn't exist instead of creating an empty one.
            """, example: Example("docker run -d --name dz-bind-web -p 8083:80 -v \"$(pwd)/site\":/usr/share/nginx/html \(Img.nginx)")),
            S("Edit on the host, see it in the container", """
            This is the everyday development loop. Keep your code on your Mac, edit it in your editor, and the server in the container picks up the change with no rebuild.

            For a static site that's instant. For an app server you still need it to reload (e.g. `flask --debug`, `nodemon`), but you never rebuild the image just to change a line.
            """, example: Example("echo '<h1>Hello from a bind mount (v2)</h1>' > site/index.html\ncurl -s localhost:8083", output: "<h1>Hello from a bind mount (v2)</h1>")),
            S("Read-only mounts", """
            Add `:ro` (or `,readonly` with `--mount`) when the container should read the files but never change them: config files, certificates, the code you're serving.

            A write then fails with _Read-only file system_. It's a cheap guard against a process scribbling over your source tree.
            """, example: Example("docker exec dz-bind-ro touch /usr/share/nginx/html/x", output: "touch: /usr/share/nginx/html/x: Read-only file system")),
            S("tmpfs mounts", """
            `--tmpfs /scratch` mounts an in-memory filesystem. It's fast, never touches disk and vanishes when the container stops. Use it for caches, temp files and secrets you don't want written anywhere.

            `--mount type=tmpfs,dst=/scratch,tmpfs-size=64m` caps its size.
            """, example: Example("docker run --rm --tmpfs /scratch \(Img.alpine) df -h /scratch", output: "Filesystem      Size  Used Available Use% Mounted on\ntmpfs           3.8G     0      3.8G   0% /scratch")),
            S("Which one when?", """
            **Volumes** for data the app owns: databases, uploads, anything that must survive. Docker manages them and they're fast.

            **Bind mounts** for things _you_ own and edit: source code during development, a config file, a folder of test fixtures. **tmpfs** for throwaway data that should never hit disk. Avoid bind mounts in production, because they tie the container to one machine's folder layout.
            """, example: Example("docker inspect -f '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}{{println}}{{end}}' dz-bind-web", output: "bind /Users/you/…/bind-mounts/site -> /usr/share/nginx/html")),
        ],
        reference: [
            O("-v \"$(pwd)\":/app", "Bind-mount the current folder at /app"),
            O("-v ./site:/srv", "Relative bind mount (the ./ is required)"),
            O("-v HOST:CTR:ro", "Bind mount, read-only inside the container"),
            O("--mount type=bind,src=HOST,dst=CTR", "Explicit bind mount (fails if HOST is missing)"),
            O("--mount type=bind,src=HOST,dst=CTR,readonly", "Explicit read-only bind mount"),
            O("--tmpfs /path", "In-memory mount, gone when the container stops"),
            O("--mount type=tmpfs,dst=/path,tmpfs-size=64m", "tmpfs with a size limit"),
            O("--read-only", "Make the container's root filesystem read-only"),
            O("docker inspect -f '{{json .Mounts}}' C", "Show a container's mounts"),
            O("docker cp C:/path ./here", "Copy files out of a container (no mount needed)"),
        ],
        macNote: "On a Mac, a bind mount crosses from macOS into Docker's Linux VM through a file-sharing layer (VirtioFS in Docker Desktop, its own fast sharing in OrbStack, virtiofs or sshfs in Colima). It works, but it's slower than a volume for heavy I/O: keep databases and dependency folders like `node_modules` in volumes and bind-mount only your source. Docker Desktop can only share folders listed in Settings → Resources → File sharing (`/Users`, `/Volumes`, `/private`, `/tmp` and `/var/folders` by default). tmpfs uses the VM's memory, not your Mac's directly.",
        images: [Img.nginx, Img.alpine],
        diagram: Diagram(
            "Four places a container's files can live",
            caption: "Your site folder lives on the Mac and is shared into the Linux VM, then bind-mounted into the container. The volume lives inside the VM, tmpfs lives in the VM's memory, and the writable layer is thrown away with the container.",
            nodes: [
                N("you", "You", icon: "person.fill", .actor, at: 0, 0, detail: "edit in your editor"),
                N("site", "./site", icon: "folder.fill", .storage, at: 0, 1, detail: "on your Mac"),
                N("share", "File sharing", icon: "cable.connector", .host, at: 1, 1, detail: "VirtioFS into the VM"),
                N("ctr", "dz-bind-web", icon: "cube.fill", .container, at: 2, 1, detail: "nginx"),
                N("layer", "Writable layer", icon: "square.stack.3d.up", .storage, at: 2, 0, detail: "lost on rm"),
                N("vol", "Volume", icon: "cylinder", .storage, at: 3, 1, detail: "managed by Docker"),
                N("tmpfs", "tmpfs", icon: "memorychip", .storage, at: 2, 2, detail: "RAM, lost on stop"),
            ],
            groups: [G("Your Mac", ["you", "site"]), G("Linux VM", ["share", "ctr", "layer", "vol", "tmpfs"])],
            edges: [
                E("you", "site", "edit"),
                E("site", "share", "shared"),
                E("share", "ctr", "bind mount"),
                E("ctr", "layer", "unmounted paths", dashed: true),
                E("ctr", "vol", "-v name:/data"),
                E("ctr", "tmpfs", "--tmpfs"),
            ]
        ),
        seed: Seed(files: [
            F("site/index.html", "<h1>Hello from a bind mount (v1)</h1>\n"),
            F("site/about.html", "<p>This page lives on your Mac, not in the image.</p>\n"),
        ]),
        missions: [
            Mission("Serve ./site with nginx as dz-bind-web on port 8083 using a bind mount",
                    hint: "Mount `\"$(pwd)/site\"` at `/usr/share/nginx/html` and publish `8083:80`. Quote the path: it may contain spaces.",
                    solution: "docker run -d --name dz-bind-web -p 8083:80 -v \"$(pwd)/site\":/usr/share/nginx/html \(Img.nginx)",
                    check: .all([.container("dz-bind-web", .running), .publishes("dz-bind-web", 8083), .mounts("dz-bind-web", "site")])),
            Mission("Show dz-bind-web's mounts with docker inspect",
                    hint: "`docker inspect` with `-f '{{json .Mounts}}'` keeps it short.",
                    solution: "docker inspect -f '{{json .Mounts}}' dz-bind-web",
                    check: .ranOK(#"docker (container )?inspect\b.*dz-bind-web"#)),
            Mission("Change site/index.html to say v2 on your Mac, then curl it",
                    hint: "Edit the file on the host (any editor, or `echo ... >`), then `curl localhost:8083`. No restart needed.",
                    solution: "echo '<h1>Hello from a bind mount (v2)</h1>' > site/index.html\ncurl -s localhost:8083",
                    check: .all([.contains("site/index.html", "v2"), .ranOK(#"curl\b.*(localhost|127\.0\.0\.1):8083"#)])),
            Mission("Run nginx as dz-bind-ro with ./site mounted read-only",
                    hint: "Same mount as before, with `:ro` on the end. Leave out `-p`: you don't need a port for this one.",
                    solution: "docker run -d --name dz-bind-ro -v \"$(pwd)/site\":/usr/share/nginx/html:ro \(Img.nginx)",
                    check: .all([
                        .container("dz-bind-ro", .running),
                        .mounts("dz-bind-ro", "site"),
                        .ranOK(#"docker (container )?run\b(?=.*dz-bind-ro)(?=.*(:ro\b|,ro\b|,readonly\b|[ =]readonly\b|[ =]ro,))"#),
                    ])),
            Mission("Try to write into dz-bind-ro's html folder and watch it fail",
                    hint: "`docker exec` a `touch` inside the mounted folder. A _Read-only file system_ error is the goal.",
                    solution: "docker exec dz-bind-ro sh -c 'touch /usr/share/nginx/html/x || echo read-only'",
                    check: .all([
                        .container("dz-bind-ro", .running),
                        .ran(#"docker (container )?exec\b.*dz-bind-ro\b.*(\btouch\b|>|\bmkdir\b|\btee\b|\bcp\b|\brm\b)"#),
                        .missing("site/x"),
                    ])),
            Mission("Give a throwaway alpine container an in-memory /scratch",
                    hint: "`--tmpfs /scratch`, then something like `df -h /scratch` to see it.",
                    solution: "docker run --rm --tmpfs /scratch \(Img.alpine) df -h /scratch",
                    check: .ranOK(#"docker (container )?run\b.*(--tmpfs|type=tmpfs)"#)),
        ]
    )

    // MARK: - Networking

    static let networking = Category(
        id: "networking", title: "Networking", icon: "network",
        blurb: "Publish ports to your Mac and let containers find each other by name.",
        lessons: [ports, networks]
    )

    static let ports = Lesson(
        id: "ports",
        title: "Publishing ports",
        commands: ["docker run -p", "docker run -P", "docker port"],
        topics: ["Container vs host ports", "-p host:container", "Binding to 127.0.0.1", "-P random ports", "docker port", "EXPOSE", "host.docker.internal"],
        summary: "A container has its own network stack, so a server listening on port 80 inside it is invisible until you publish that port on the host with `-p`.",
        sections: [
            S("Container ports vs host ports", """
            Each container gets its own IP address and its own set of ports. nginx listening on **80** inside `dz-port-web` doesn't take port 80 on your machine, and ten containers can all listen on 80 without clashing.

            To reach one from outside, **publish** it: `-p 8084:80` means "host port 8084 forwards to container port 80". The order is always **host:container**.
            """, example: Example("docker run -d --name dz-port-web -p 8084:80 \(Img.nginx)\ndocker ps --format '{{.Names}}  {{.Ports}}'", output: "dz-port-web  0.0.0.0:8084->80/tcp, [::]:8084->80/tcp")),
            S("Which address it listens on", """
            By default `-p 8084:80` listens on **every** interface (`0.0.0.0`), so anyone on your Wi-Fi can reach it. Prefix an IP to narrow it: `-p 127.0.0.1:8085:80` only accepts connections from your own machine. Do that for databases and admin tools.

            Add `/udp` for UDP (`-p 5353:53/udp`), and repeat `-p` to publish several ports.
            """, example: Example("docker run -d --name dz-port-local -p 127.0.0.1:8085:80 \(Img.nginx)\ncurl -s 127.0.0.1:8085 | head -4", output: "<!DOCTYPE html>\n<html>\n<head>\n<title>Welcome to nginx!</title>")),
            S("EXPOSE and -P", """
            `EXPOSE 80` in a Dockerfile is **documentation**: it says which port the app uses, but publishes nothing by itself.

            `-P` (capital) publishes every exposed port to a random free host port. Handy for running many copies side by side. `docker port` tells you which port you got.
            """, example: Example("docker run -d --name dz-port-rand -P \(Img.nginx)\ndocker port dz-port-rand", output: "80/tcp -> 0.0.0.0:55001\n80/tcp -> [::]:55001")),
            S("localhost is not your Mac", """
            Inside a container, `localhost` means **the container itself**. If your app in a container tries `localhost:5432` to reach a database running on your Mac, it finds nothing.

            Use `host.docker.internal` instead: Docker Desktop and OrbStack resolve it to your Mac. On a Linux engine add `--add-host=host.docker.internal:host-gateway`. To reach another _container_, don't go through the host at all: put both on a network (next lesson).
            """, example: Example("docker run --rm \(Img.alpine) wget -qO- http://host.docker.internal:8084 | head -4", output: "<!DOCTYPE html>\n<html>\n<head>\n<title>Welcome to nginx!</title>")),
            S("When the port is taken", """
            Only one process can hold a host port. If something already uses it, `docker run` fails with _port is already allocated_ (or _address already in use_), and the container is created but not started.

            Pick another host port; the container port stays the same. `lsof -i :8084` shows who has it on your Mac.
            """, example: Example("docker run -d --name dz-port-clash -p 8084:80 \(Img.nginx)", output: "docker: Error response from daemon: … Bind for 0.0.0.0:8084 failed: port is already allocated.")),
        ],
        reference: [
            O("-p 8080:80", "Publish container port 80 on host port 8080 (all interfaces)"),
            O("-p 127.0.0.1:8080:80", "Publish on localhost only"),
            O("-p 8080:80/udp", "Publish a UDP port"),
            O("-p 80", "Publish container port 80 on a random host port"),
            O("-p 8080-8082:80-82", "Publish a range of ports"),
            O("-P, --publish-all", "Publish every EXPOSEd port on random host ports"),
            O("docker port C", "List a container's published ports"),
            O("docker port C 80", "Which host port maps to container port 80"),
            O("docker ps --format '{{.Names}} {{.Ports}}'", "Names and port mappings at a glance"),
            O("EXPOSE 80", "Dockerfile: document the port (publishes nothing)"),
            O("host.docker.internal", "Hostname that reaches your Mac from a container"),
            O("--add-host=host.docker.internal:host-gateway", "Make host.docker.internal work on a Linux engine"),
            O("lsof -i :8080", "macOS: find what is using host port 8080"),
        ],
        macNote: "On Linux, `-p` sets up NAT rules on the host itself. On a Mac the containers live in a Linux VM, so Docker Desktop (or OrbStack, or Colima) also runs a forwarder that listens on your Mac's port and passes traffic into the VM. That's why `localhost:8084` works from Safari. Container IPs like 172.17.0.2 are inside the VM, so on Docker Desktop you can't reach them directly from macOS: always go through a published port. OrbStack does route container IPs to the Mac.",
        images: [Img.nginx],
        diagram: Diagram(
            "The path of a request to a published port",
            caption: "curl on your Mac hits port 8084, the Docker Desktop forwarder carries it into the Linux VM, dockerd's NAT rule maps 8084 to port 80 on the bridge, and nginx answers. From inside, host.docker.internal goes the other way, back to your Mac.",
            nodes: [
                N("curl", "curl localhost:8084", icon: "terminal", .cli, at: 0, 0, detail: "on your Mac"),
                N("mac", "Mac :8084", icon: "laptopcomputer", .network, at: 1, 0, detail: "Desktop forwarder"),
                N("nat", "dockerd NAT", icon: "gearshape.2", .daemon, at: 2, 0, detail: "8084 → 80"),
                N("bridge", "bridge", icon: "point.3.connected.trianglepath.dotted", .network, at: 3, 0, detail: "172.17.0.0/16"),
                N("ctr", "dz-port-web", icon: "cube.fill", .container, at: 4, 0, detail: "nginx on :80"),
                N("hdi", "host.docker.internal", icon: "desktopcomputer", .network, at: 4, 1, detail: "back to your Mac"),
            ],
            groups: [G("Your Mac", ["curl", "mac"]), G("Linux VM", ["nat", "bridge", "ctr", "hdi"])],
            edges: [
                E("curl", "mac", "TCP"),
                E("mac", "nat", "into the VM"),
                E("nat", "bridge", "forward"),
                E("bridge", "ctr", ":80"),
                E("ctr", "hdi", "outbound", dashed: true),
            ]
        ),
        missions: [
            Mission("Run nginx as dz-port-web, published on host port 8084",
                    hint: "`-p HOST:CONTAINER`. nginx listens on 80 inside.",
                    solution: "docker run -d --name dz-port-web -p 8084:80 \(Img.nginx)",
                    check: .all([.container("dz-port-web", .running), .publishes("dz-port-web", 8084)])),
            Mission("Ask Docker which ports dz-port-web publishes",
                    hint: "There's a `docker` subcommand named after exactly this.",
                    solution: "docker port dz-port-web",
                    check: .ranOK(#"docker (container )?port\b.*dz-port-web"#)),
            Mission("Run dz-port-local on port 8085, reachable only from 127.0.0.1",
                    hint: "Put the IP in front: `-p IP:HOST:CONTAINER`.",
                    solution: "docker run -d --name dz-port-local -p 127.0.0.1:8085:80 \(Img.nginx)",
                    check: .all([
                        .container("dz-port-local", .running),
                        .publishes("dz-port-local", 8085),
                        .ranOK(#"docker (container )?run\b.*127\.0\.0\.1:8085:80\b"#),
                    ])),
            Mission("Run dz-port-rand with every exposed port published on a random port",
                    hint: "It's a capital letter flag, the opposite of choosing the port yourself.",
                    solution: "docker run -d --name dz-port-rand -P \(Img.nginx)",
                    check: .all([
                        .container("dz-port-rand", .running),
                        .ranOK(#"docker (container )?run\b(?=.*dz-port-rand)(?=.*(\s-[a-zA-Z]*P\b|--publish-all))"#),
                    ])),
            Mission("Find out which host port dz-port-rand got",
                    hint: "`docker port`, optionally followed by the container port.",
                    solution: "docker port dz-port-rand 80",
                    check: .ranOK(#"docker (container )?port\b.*dz-port-rand"#)),
            Mission("curl dz-port-local through 127.0.0.1:8085",
                    hint: "`curl -s 127.0.0.1:8085` (or `localhost:8085`).",
                    solution: "curl -s 127.0.0.1:8085",
                    check: .all([.container("dz-port-local", .running), .ranOK(#"curl\b.*(localhost|127\.0\.0\.1):8085"#)])),
        ]
    )

    static let networks = Lesson(
        id: "networks",
        title: "Networks & DNS",
        commands: ["docker network create", "docker network ls", "docker network inspect", "docker network connect", "docker network disconnect", "docker network rm"],
        topics: ["Default bridge", "User-defined bridges", "DNS by container name", "docker network", "--network", "--network-alias", "host & none"],
        summary: "Containers on the same user-defined network can reach each other by name, with no published ports. This is how an app talks to its database.",
        sections: [
            S("The default bridge", """
            Every container you start without `--network` joins the network called **bridge**. Containers there get an IP and can reach the internet, and they can reach each other by IP.

            They **can't** reach each other by name. IPs change every time a container is recreated, so the default bridge is a poor place for anything that talks to anything else.
            """, example: Example("docker network ls", output: "NETWORK ID     NAME      DRIVER    SCOPE\n5f3c2a1b9e04   bridge    bridge    local\n8a71d0c4b2e6   host      host      local\nc19e4f7a3d58   none      null      local")),
            S("User-defined bridges", """
            `docker network create dz-net` makes your own bridge network. Start containers with `--network dz-net` and Docker's **embedded DNS server** (at `127.0.0.11` inside each container) answers lookups for every container name on that network.

            So the app just connects to `dz-net-cache:6379`. No IPs, no published ports. The cache is only reachable from containers on `dz-net`, which is exactly what you want for a database.
            """, example: Example("docker run --rm --network dz-net \(Img.redis) redis-cli -h dz-net-cache ping", output: "PONG")),
            S("Connect, disconnect, alias", """
            A container can be on several networks. `docker network connect dz-net dz-net-web` attaches a running container, and `disconnect` detaches it. Nothing restarts.

            `--network-alias cache` on `docker run` (or `--alias` on `connect`) adds an extra DNS name. Give two containers the same alias and lookups return both IPs, which is a crude load balancer.
            """, example: Example("docker network connect dz-net dz-net-web\ndocker exec dz-net-cache wget -qO- http://dz-net-web | head -4", output: "<!DOCTYPE html>\n<html>\n<head>\n<title>Welcome to nginx!</title>")),
            S("Inspecting a network", """
            `docker network inspect dz-net` shows the subnet, the gateway and every attached container with its IP. Use `-f` to pick out just the part you need.

            `docker network rm` refuses while containers are still attached, and `docker network prune` removes every network nothing is using.
            """, example: Example("docker network inspect -f '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}' dz-net", output: "dz-net-cache 172.18.0.2/16\ndz-net-web 172.18.0.3/16")),
            S("host and none", """
            `--network host` drops the container's network isolation: it shares the host's network stack, so a server on port 80 is on the host's port 80 with no `-p`. `--network none` gives it only a loopback interface, with no way in or out.

            Most of the time you want a user-defined bridge. Reach for `host` for network tools or raw speed on Linux, and `none` for jobs that should never touch the network.
            """, example: Example("docker run --rm --network none \(Img.alpine) ip -brief addr", output: "lo               UNKNOWN        127.0.0.1/8 ::1/128")),
        ],
        reference: [
            O("docker network create NAME", "Create a user-defined bridge network"),
            O("docker network ls", "List networks"),
            O("docker network inspect NAME", "Show subnet, gateway and attached containers"),
            O("docker network connect NET C", "Attach a running container to a network"),
            O("docker network connect --alias A NET C", "Attach with an extra DNS name"),
            O("docker network disconnect NET C", "Detach a container from a network"),
            O("docker network rm NAME", "Delete a network (nothing may be attached)"),
            O("docker network prune", "Delete all unused networks"),
            O("--network NET", "Start a container on NET"),
            O("--network-alias NAME", "Extra DNS name on a user-defined network"),
            O("--network host", "Share the host's network stack (no isolation)"),
            O("--network none", "Loopback only, no network access"),
            O("docker network create --subnet 10.10.0.0/24 NAME", "Choose the network's address range"),
        ],
        macNote: "All these networks live inside Docker's Linux VM, and their 172.x addresses usually aren't reachable from macOS (OrbStack is the exception), so use published ports to get in from your Mac. `--network host` means the **VM's** network, not your Mac's: a server on port 80 won't appear on your Mac's localhost unless you're on Docker Desktop 4.34+ with host networking turned on in Settings, or using OrbStack.",
        images: [Img.redis, Img.nginx, Img.alpine],
        diagram: Diagram(
            "Name lookups on a user-defined bridge",
            caption: "On dz-net the embedded DNS server turns dz-net-cache into an IP, so the client connects by name. dz-net-web sits on both networks after docker network connect. A container on the default bridge gets no name lookups at all.",
            nodes: [
                N("dns", "Embedded DNS", icon: "magnifyingglass", .daemon, at: 0, 0, detail: "127.0.0.11"),
                N("client", "redis-cli", icon: "cube", .container, at: 0, 1, detail: "-h dz-net-cache"),
                N("net", "dz-net", icon: "point.3.connected.trianglepath.dotted", .network, at: 1, 1, detail: "user-defined bridge"),
                N("cache", "dz-net-cache", icon: "cylinder.split.1x2", .container, at: 2, 1, detail: "redis :6379"),
                N("web", "dz-net-web", icon: "cube.fill", .container, at: 1, 2, detail: "on both networks"),
                N("bridge", "bridge", icon: "network", .network, at: 2, 2, detail: "default, no DNS"),
                N("lonely", "alpine", icon: "cube", .container, at: 3, 2, detail: "can't resolve names"),
            ],
            groups: [G("dz-net", ["dns", "client", "net", "cache"]), G("Default bridge", ["bridge", "lonely"])],
            edges: [
                E("client", "dns", "who is dz-net-cache?"),
                E("client", "net", "TCP 6379"),
                E("net", "cache", "172.18.0.2"),
                E("net", "web", "network connect", dashed: true),
                E("bridge", "web"),
                E("lonely", "bridge"),
            ]
        ),
        missions: [
            Mission("Create a network named dz-net",
                    hint: "It's a `docker network` subcommand.",
                    solution: "docker network create dz-net",
                    check: .network("dz-net")),
            Mission("Run redis as dz-net-cache on dz-net",
                    hint: "`--network dz-net` on `docker run`. No `-p` needed.",
                    solution: "docker run -d --name dz-net-cache --network dz-net \(Img.redis)",
                    check: .all([.container("dz-net-cache", .running), .onNetwork("dz-net-cache", "dz-net")])),
            Mission("From another container on dz-net, ping redis by name",
                    hint: "A throwaway redis container has `redis-cli`. Point `-h` at the container's name and send `ping`.",
                    solution: "docker run --rm --network dz-net \(Img.redis) redis-cli -h dz-net-cache ping",
                    check: .all([
                        .container("dz-net-cache", .running),
                        .ranOK(#"docker (container )?run\b.*--net(work)?[ =]dz-net\b.*\bdz-net-cache\b"#),
                    ])),
            Mission("Run nginx as dz-net-web, then attach it to dz-net with docker network connect",
                    hint: "Start it normally (it lands on the default bridge), then `docker network connect NETWORK CONTAINER`.",
                    solution: "docker run -d --name dz-net-web \(Img.nginx)\ndocker network connect dz-net dz-net-web",
                    check: .all([
                        .container("dz-net-web", .running),
                        .onNetwork("dz-net-web", "dz-net"),
                        .ranOK(#"docker network connect\b.*dz-net-web"#),
                    ])),
            Mission("Inspect dz-net to see who's attached",
                    hint: "`docker network inspect`. Look for the Containers section.",
                    solution: "docker network inspect dz-net",
                    check: .ranOK(#"docker network inspect\b.*dz-net\b"#)),
            Mission("Show that a container on the default bridge can't resolve dz-net-cache",
                    hint: "Start a throwaway alpine without `--network` and try `ping -c1 dz-net-cache`. The failure is the point.",
                    solution: "docker run --rm \(Img.alpine) ping -c1 -W2 dz-net-cache || echo 'no name lookups on the default bridge'",
                    check: .all([
                        .container("dz-net-cache", .running),
                        .ran(#"^(?!.*--net(work)?[ =]dz-net\b)(?!.*--name[ =]dz-net-cache\b).*docker (container )?run\b.*\b(ping|nslookup|wget|getent|redis-cli|nc)\b.*\bdz-net-cache\b"#),
                    ])),
        ]
    )
}
