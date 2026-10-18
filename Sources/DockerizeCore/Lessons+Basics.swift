import Foundation

extension Curriculum {
    // MARK: - Getting Started

    static let gettingStarted = Category(
        id: "getting-started", title: "Getting Started", icon: "flag",
        blurb: "What Docker is, how the pieces talk to each other, and the difference between an image and a container.",
        lessons: [whatIsDocker, imagesAndContainers]
    )

    static let whatIsDocker = Lesson(
        id: "what-is-docker",
        title: "What is Docker?",
        commands: ["docker version", "docker info", "docker run hello-world"],
        topics: ["Why containers", "Containers vs VMs", "Namespaces & cgroups", "Client and daemon", "The Linux VM on a Mac", "docker version", "docker info", "hello-world"],
        summary: "Docker packages an app with everything it needs to run, then runs it as an isolated process. The `docker` command you type is only a client: the real work happens in a daemon.",
        sections: [
            S("Why Docker exists", """
            "It works on my machine" happens because your laptop, CI and production all have slightly different OS packages, language runtimes and config. Docker fixes that by shipping the app **together with its filesystem**: the exact Python, the exact libraries, the exact config. If it runs in the container on your laptop, it runs the same way on the server.

            The same trick gives you clean, throwaway environments. Need Redis for an afternoon? Run it, use it, delete it. Nothing gets installed on your machine.
            """),
            S("Containers are not VMs", """
            A **virtual machine** emulates hardware and boots a whole guest OS with its own kernel. A **container** is just a normal Linux process that the kernel fences off. There is no second kernel, so containers start in milliseconds and cost almost nothing when idle.

            The fencing comes from two kernel features. **Namespaces** control what a process can _see_: its own process list, network interfaces, hostname and filesystem root. **cgroups** control what it can _use_: CPU, memory, I/O. Docker is a friendly layer that sets these up for you.
            """),
            S("Client and daemon", """
            Docker is a client/server system. `docker` is the **CLI**. It turns your command into a REST API call and sends it to **dockerd**, the Docker daemon. dockerd manages images, networks and volumes, and hands containers to **containerd**, which uses **runc** to actually create the namespaced process.

            `docker version` shows both halves. If the `Server` section is missing or you see _Cannot connect to the Docker daemon_, the CLI is fine but the engine isn't running.
            """, example: Example("docker version", output: "Client:\n Version:           28.3.2\n API version:       1.51\n OS/Arch:           darwin/arm64\n\nServer: Docker Desktop 4.43.2\n Engine:\n  Version:          28.3.2\n  OS/Arch:          linux/arm64\n containerd:\n  Version:          1.7.27\n runc:\n  Version:          1.2.5")),
            S("What the engine knows", """
            `docker info` prints the engine's view of the world: how many containers are running or stopped, how many images it has, the storage driver, the kernel version, CPUs and memory it can use.

            Notice the **Operating System** and **Kernel Version** lines: they describe Linux, even on a Mac. Containers always need a Linux kernel (Windows containers aside).
            """, example: Example("docker info", output: "Containers: 0\n Running: 0\n Paused: 0\n Stopped: 0\nImages: 0\nServer Version: 28.3.2\nStorage Driver: overlayfs\nKernel Version: 6.10.14-linuxkit\nOperating System: Docker Desktop\nArchitecture: aarch64\nCPUs: 8\nTotal Memory: 7.654GiB")),
            S("Your first container", """
            `docker run hello-world` asks the daemon to run the `hello-world` image. The daemon doesn't have it yet, so it **pulls** it from Docker Hub, creates a container, starts it, and streams its output back to your terminal. The program prints a message and exits, and so does the container.

            The container is now **stopped**, not gone. `docker ps` only lists running containers; `docker ps -a` shows stopped ones too.
            """, example: Example("docker run hello-world", output: "Unable to find image 'hello-world:latest' locally\nlatest: Pulling from library/hello-world\n198f93fd5094: Pull complete\nStatus: Downloaded newer image for hello-world:latest\n\nHello from Docker!\nThis message shows that your installation appears to be working correctly.")),
        ],
        reference: [
            O("docker version", "Client and server (engine) versions; shows whether the daemon is reachable"),
            O("docker --version", "Client version only, one line"),
            O("docker info", "Engine-wide details: counts, storage driver, kernel, CPUs, memory"),
            O("docker run hello-world", "Smoke-test the install: pull, create, start, print, exit"),
            O("docker ps", "List running containers"),
            O("docker ps -a", "List all containers, including stopped ones"),
            O("docker help  /  docker CMD --help", "List commands, or the flags for one command"),
            O("docker context ls", "Show which engines the CLI can talk to and which is active"),
            O("docker system df", "Disk used by images, containers, volumes and build cache"),
            O("docker container ls", "Long form of docker ps (newer CLI grouping: docker container …, docker image …)"),
        ],
        macNote: "macOS has no Linux kernel, so Docker Desktop, OrbStack and Colima all run a small Linux VM and put dockerd inside it. The `docker` CLI runs on your Mac and talks to that VM over a socket. That's why `docker info` reports a Linux kernel, and why images and containers live in the VM's disk image rather than in your Mac's filesystem. `docker context ls` shows which engine you're pointed at.",
        images: [Img.hello],
        diagram: Diagram(
            "From your command to a running container",
            caption: "The CLI sends a REST call to dockerd. dockerd pulls the image if it's missing, then asks containerd and runc to start a process that the Linux kernel isolates with namespaces and cgroups. On a Mac, everything right of the CLI lives in a Linux VM.",
            nodes: [
                N("you", "You", icon: "person.fill", .actor, at: 0, 0, detail: "docker run …"),
                N("cli", "docker CLI", icon: "terminal", .cli, at: 1, 0, detail: "the client"),
                N("dockerd", "dockerd", icon: "gearshape.2", .daemon, at: 2, 0, detail: "the daemon"),
                N("containerd", "containerd", icon: "gearshape.2", .daemon, at: 3, 0, detail: "container runtime"),
                N("runc", "runc", icon: "wrench.and.screwdriver", .daemon, at: 4, 0, detail: "creates the process"),
                N("image", "Image cache", icon: "square.stack.3d.up.fill", .image, at: 2, 1, detail: "hello-world"),
                N("kernel", "Linux kernel", icon: "cpu", .host, at: 3, 1, detail: "namespaces + cgroups"),
                N("ctr", "Container", icon: "cube.fill", .container, at: 4, 1, detail: "an isolated process"),
                N("hub", "Docker Hub", icon: "cloud", .registry, at: 2, 2, detail: "public images"),
            ],
            groups: [G("Linux VM (Docker Desktop / OrbStack / Colima)", ["dockerd", "containerd", "runc", "image", "kernel", "ctr"])],
            edges: [
                E("you", "cli", "types"),
                E("cli", "dockerd", "REST API"),
                E("dockerd", "containerd", "start"),
                E("containerd", "runc", "spawn"),
                E("runc", "ctr", "creates"),
                E("hub", "image", "pull if missing"),
                E("dockerd", "image", "uses"),
                E("ctr", "kernel", "isolated by", dashed: true),
            ]
        ),
        missions: [
            Mission("Check that both the client and the engine are running", hint: "One command prints a Client section and a Server section.", solution: "docker version", check: .ranOK(#"^\s*docker\s+version\b"#)),
            Mission("Ask the engine to describe itself", hint: "It's the command for engine-wide information.", solution: "docker info", check: .ranOK(#"^\s*docker\s+(system\s+)?info\b"#)),
            Mission("Run the hello-world image as a container named dz-hello", hint: "docker run, then --name dz-hello, then the image name. Docker pulls it for you.", solution: "docker run --name dz-hello \(Img.hello)", check: .all([.image(Img.hello), .ranOK(#"docker\s+(container\s+)?run\b.*hello-world"#)])),
            Mission("List every container, including the one that just exited", hint: "docker ps only shows running containers. There's a flag for all of them.", solution: "docker ps -a", check: .ranOK(#"docker\s+(ps|container\s+(ls|ps|list))\b.*\s(-[a-zA-Z]*a[a-zA-Z]*|--all)\b"#)),
        ]
    )

    static let imagesAndContainers = Lesson(
        id: "images-and-containers",
        title: "Images & containers",
        commands: ["docker run", "docker ps -a", "docker images"],
        topics: ["Images", "Layers", "Containers", "Writable layer", "What docker run does", "One image, many containers", "Exit = stop"],
        summary: "An image is a read-only template. A container is one running instance of it with a thin writable layer on top. You can start as many containers from one image as you like.",
        sections: [
            S("Images are templates", """
            An **image** is a read-only snapshot of a filesystem plus some metadata: which command to run, which environment variables to set, which port the app listens on. It's built from **layers**, each one a set of file changes stacked on the layer below (base OS, then installed packages, then your code).

            Layers are shared. Ten images built `FROM alpine` store alpine's files once, and pulling a new version only downloads the layers that changed.
            """, example: Example("docker images", output: "REPOSITORY    TAG       IMAGE ID       CREATED       SIZE\nalpine        3.20      0a9cdd7d1a0d   2 weeks ago   12.4MB\nhello-world   latest    ec153840d1e6   6 months ago  20.3kB")),
            S("Containers are instances", """
            A **container** is an image brought to life: the image's layers, plus a thin **writable layer** on top, plus a running process. Files the container creates or changes go into its own writable layer. The image underneath never changes.

            That's why one image can back many containers at once, each with its own name, its own writable layer and its own state. Delete a container and its writable layer goes with it.
            """),
            S("What docker run actually does", """
            `docker run IMAGE COMMAND` is three steps in one: **pull** the image if it isn't local, **create** a container (the writable layer and config), then **start** its main process. Anything after the image name replaces the image's default command.

            Add `--rm` for a one-off job and Docker deletes the container as soon as it exits.
            """, example: Example("docker run --rm alpine:3.20 echo \"hello from alpine\"", output: "hello from alpine")),
            S("A container lives as long as its main process", """
            Every container has one **main process** (PID 1 inside it). When that process exits, the container stops. `echo` finishes instantly, so its container stops instantly. A web server or `sleep 3600` keeps running, so its container does too.

            A stopped container still exists: its name, config, logs and writable layer are kept until you `docker rm` it. `docker ps -a` shows it with a status like `Exited (0) 5 seconds ago`.
            """, example: Example("docker ps -a", output: "CONTAINER ID   IMAGE         COMMAND             STATUS                     NAMES\n4f1c2a9e8b3d   alpine:3.20   \"echo 'I ran'\"      Exited (0) 5 seconds ago   dz-first")),
            S("Names and IDs", """
            Every container gets a 64-character **ID** and a **name**. Without `--name`, Docker invents one like `quirky_hopper`. Any command that takes a container accepts the name, the full ID or a unique prefix of the ID (`docker logs 4f1c`).

            Names must be unique, so `docker run --name dz-first …` fails if a container called `dz-first` already exists, even a stopped one.
            """),
        ],
        reference: [
            O("docker run IMAGE", "Pull if needed, create a container and start it"),
            O("docker run IMAGE CMD ARGS…", "Run CMD instead of the image's default command"),
            O("docker run --rm IMAGE …", "Delete the container automatically when it exits"),
            O("docker run --name NAME IMAGE", "Give the container a fixed name"),
            O("docker run -d IMAGE", "Run in the background and print the container ID"),
            O("docker ps -a", "All containers, running and stopped"),
            O("docker ps -q", "Only container IDs (handy in scripts)"),
            O("docker images  /  docker image ls", "List local images with tag, ID and size"),
            O("docker pull IMAGE:TAG", "Download an image without running it"),
            O("docker image history IMAGE", "Show the layers an image is built from"),
            O("docker rmi IMAGE", "Remove a local image (no container may use it)"),
            O("docker image prune", "Remove dangling (untagged) images"),
        ],
        macNote: "On Apple silicon, Docker pulls the `linux/arm64` variant of multi-arch images like alpine. An image that only exists for `linux/amd64` still runs (via Rosetta or QEMU emulation, with a warning) but slower. All images are stored inside the Linux VM's disk, so deleting them is how you get disk space back, not deleting files on your Mac.",
        images: [Img.alpine],
        diagram: Diagram(
            "One image, many containers",
            caption: "The image is pulled once and never changes. Each container gets its own thin writable layer on top of the shared read-only layers, so dz-twin-1 and dz-twin-2 can't see each other's files.",
            nodes: [
                N("hub", "Docker Hub", icon: "cloud", .registry, at: 0, 1, detail: "library/alpine"),
                N("img", "alpine:3.20", icon: "square.stack.3d.up.fill", .image, at: 1, 1, detail: "read-only layers"),
                N("w1", "Writable layer", icon: "square.on.square", .storage, at: 1, 0, detail: "only dz-twin-1's changes"),
                N("c1", "dz-twin-1", icon: "cube.fill", .container, at: 2, 0, detail: "sleep 3600"),
                N("w2", "Writable layer", icon: "square.on.square", .storage, at: 1, 2, detail: "only dz-twin-2's changes"),
                N("c2", "dz-twin-2", icon: "cube.fill", .container, at: 0, 2, detail: "sleep 3600"),
            ],
            groups: [G("Container 1", ["w1", "c1"]), G("Container 2", ["w2", "c2"])],
            edges: [
                E("hub", "img", "pull once"),
                E("img", "w1", "docker run"),
                E("img", "w2", "docker run"),
                E("w1", "c1", "main process"),
                E("w2", "c2", "main process"),
            ]
        ),
        missions: [
            Mission("Run a one-off echo in alpine that cleans up after itself", hint: "docker run, a flag that removes the container on exit, the image, then the command.", solution: "docker run --rm \(Img.alpine) echo \"hello from alpine\"", check: .ranOK(#"docker\s+(container\s+)?run\s+(.*\s)?--rm\s.*alpine\S*\s+echo\b"#)),
            Mission("Run a container named dz-first that prints something and exits", hint: "Use --name, and leave off --rm so the container sticks around.", solution: "docker run --name dz-first \(Img.alpine) echo \"I ran\"", check: .container("dz-first", .exists)),
            Mission("Find dz-first in the list of stopped containers", hint: "It isn't running, so plain docker ps won't show it.", solution: "docker ps -a", check: .all([.container("dz-first", .stopped), .ranOK(#"docker\s+(ps|container\s+(ls|ps|list))\b.*\s(-[a-zA-Z]*a[a-zA-Z]*|--all)\b"#)])),
            Mission("Start dz-twin-1 and dz-twin-2 from the same alpine image, both running sleep 3600", hint: "Run in the background with -d, give each its own --name, and use a command that keeps going.", solution: "docker run -d --name dz-twin-1 \(Img.alpine) sleep 3600\ndocker run -d --name dz-twin-2 \(Img.alpine) sleep 3600", check: .all([.container("dz-twin-1", .running), .container("dz-twin-2", .running)])),
            Mission("List the images you have locally", hint: "One image backs both twins. See how many copies there are.", solution: "docker images", check: .ranOK(#"docker\s+(images|image\s+(ls|list))\b"#)),
        ]
    )

    // MARK: - Running Containers

    static let containers = Category(
        id: "containers", title: "Running Containers", icon: "cube",
        blurb: "Run containers the way you will every day, manage their lifecycle, and look inside them.",
        lessons: [runningContainers, lifecycle, insideContainers]
    )

    static let runningContainers = Lesson(
        id: "running-containers",
        title: "docker run, day to day",
        commands: ["docker run", "docker port"],
        topics: ["-d detached", "--name", "-p publish ports", "-e env vars", "--rm", "-it interactive", "-w workdir", "Command override", "--platform"],
        summary: "Almost everything you do starts with `docker run`. A handful of flags cover nearly every case: run it in the background, name it, publish a port, pass config, or drop into a shell.",
        sections: [
            S("The shape of docker run", """
            `docker run [OPTIONS] IMAGE [COMMAND] [ARGS…]`. **Options go before the image name.** Everything after the image is the command to run inside the container, so `docker run alpine -d` passes `-d` to alpine, not to Docker.

            Leave the command off and the image's default runs (nginx starts nginx, alpine starts `/bin/sh`).
            """),
            S("Background servers: -d, --name, -p", """
            `-d` (_detached_) starts the container in the background and prints its ID. `--name` gives it a name you can type. `-p HOST:CONTAINER` **publishes** a port: traffic to the host port is forwarded to the container port.

            Containers have their own network, so without `-p` nothing outside can reach a server inside. `-p 8080:80` means "localhost:8080 on my machine goes to port 80 in the container".
            """, example: Example("docker run -d --name dz-run-web -p 8080:80 nginx:1.27-alpine\ncurl -s localhost:8080 | head -4", output: "3b1f0c9a7e2d4f8a…\n<!DOCTYPE html>\n<html>\n<head>\n<title>Welcome to nginx!</title>")),
            S("Configuration: -e and -w", """
            Containers are configured with **environment variables**. `-e KEY=value` sets one, `-e KEY` copies it from your shell, and `--env-file .env` loads a file of them. This is how you pass database URLs, log levels and feature flags.

            `-w /path` sets the **working directory** the command starts in.
            """, example: Example("docker run --rm -e GREETING=hello alpine:3.20 sh -c 'echo $GREETING from $(hostname)'", output: "hello from 7c2e9d41b0aa")),
            S("Interactive shells: -it", """
            `-i` keeps stdin open and `-t` gives the process a terminal, so together `-it` gets you a usable shell. `docker run -it --rm alpine sh` is the quickest way to poke around a clean Linux box. Type `exit` (or Ctrl+D) and, thanks to `--rm`, the container is gone.

            Use `-it` for anything you type into. Leave it off for scripts and CI, where there's no terminal.
            """, example: Example("docker run -it --rm alpine:3.20 sh", output: "/ # cat /etc/alpine-release\n3.20.3\n/ # exit")),
            S("Overriding the command", """
            Whatever follows the image replaces its default command: `docker run --rm nginx:1.27-alpine nginx -v` prints the nginx version instead of starting a server. For multiple commands, or pipes and variables, wrap them in `sh -c '…'`.

            To replace the program itself (the image's **entrypoint**), use `--entrypoint`.
            """, example: Example("docker run --rm nginx:1.27-alpine nginx -v", output: "nginx version: nginx/1.27.5")),
            S("Ports, platforms and other flags", """
            `docker port NAME` shows a container's published ports. `-p 127.0.0.1:8080:80` binds only to localhost; `-P` publishes every exposed port on a random host port.

            `--platform linux/amd64` asks for a specific CPU architecture, for when an image has no arm64 build. Other flags you'll meet: `--restart unless-stopped`, `-v` for volumes, `--network`, `--memory` and `--cpus`.
            """, example: Example("docker port dz-run-web", output: "80/tcp -> 0.0.0.0:8080\n80/tcp -> [::]:8080")),
        ],
        reference: [
            O("docker run -d IMAGE", "Run in the background (detached)"),
            O("docker run --name NAME IMAGE", "Name the container"),
            O("docker run -p 8080:80 IMAGE", "Publish container port 80 on host port 8080"),
            O("docker run -p 127.0.0.1:8080:80 IMAGE", "Publish on localhost only"),
            O("docker run -P IMAGE", "Publish all EXPOSEd ports on random host ports"),
            O("docker run -e KEY=value IMAGE", "Set an environment variable"),
            O("docker run --env-file .env IMAGE", "Load environment variables from a file"),
            O("docker run -it --rm IMAGE sh", "Throwaway interactive shell"),
            O("docker run -w /dir IMAGE CMD", "Run CMD in /dir inside the container"),
            O("docker run IMAGE sh -c 'a && b'", "Run several commands, with pipes and variables"),
            O("docker run --entrypoint sh IMAGE", "Replace the image's entrypoint"),
            O("docker run --platform linux/amd64 IMAGE", "Pick the image architecture (emulated if not native)"),
            O("docker run --restart unless-stopped IMAGE", "Restart automatically, unless you stopped it"),
            O("docker port NAME", "Show a container's published ports"),
        ],
        macNote: "`-p` publishes onto your Mac's localhost: Docker Desktop, OrbStack and Colima forward ports from the VM for you. `--network host` means the VM's network, not your Mac's (Docker Desktop only supports it with a setting turned on), so stick with `-p`. From inside a container, reach a server running on your Mac at `host.docker.internal`, not `localhost`. On Apple silicon, `--platform linux/amd64` runs under emulation and is noticeably slower.",
        images: [Img.nginx, Img.alpine],
        diagram: Diagram(
            "Two everyday kinds of docker run",
            caption: "A detached server keeps running in the background, reachable through the port you published. An interactive -it --rm container attaches to your terminal and is deleted the moment you exit.",
            nodes: [
                N("curl", "curl", icon: "terminal", .cli, at: 0, 0, detail: "localhost:8080"),
                N("port", "Host port 8080", icon: "cable.connector", .network, at: 1, 0, detail: "-p 8080:80"),
                N("web", "dz-run-web", icon: "cube.fill", .container, at: 2, 0, detail: "nginx on :80, -d"),
                N("you", "You", icon: "person.fill", .actor, at: 1, 1, detail: "types docker run"),
                N("cli", "docker run", icon: "terminal", .cli, at: 2, 1, detail: "options IMAGE cmd"),
                N("shell", "alpine sh", icon: "cube", .container, at: 3, 1, detail: "-it --rm, -e, -w"),
                N("gone", "Removed", icon: "trash", .container, at: 4, 1, detail: "--rm on exit"),
            ],
            groups: [G("Detached server", ["port", "web"]), G("Interactive, throwaway", ["shell", "gone"])],
            edges: [
                E("curl", "port", "HTTP"),
                E("port", "web", "forwards to :80"),
                E("you", "cli", "types"),
                E("cli", "web", "-d -p --name"),
                E("cli", "shell", "-it --rm"),
                E("shell", "gone", "exit"),
            ]
        ),
        missions: [
            Mission("Run nginx in the background as dz-run-web, published on port 8080", hint: "You need -d, --name and -p HOST:CONTAINER. nginx listens on port 80.", solution: "docker run -d --name dz-run-web -p 8080:80 \(Img.nginx)", check: .all([.container("dz-run-web", .running), .publishes("dz-run-web", 8080)])),
            Mission("Ask Docker which ports dz-run-web publishes", hint: "There's a docker subcommand named after what you're asking about.", solution: "docker port dz-run-web", check: .ranOK(#"docker\s+(container\s+)?port\s+dz-run-web\b"#)),
            Mission("Fetch the nginx welcome page from your machine", hint: "curl the host port you published, with -s to hide the progress bar.", solution: "curl -s localhost:8080", check: .ranOK(#"curl\b.*(localhost|127\.0\.0\.1):8080\b"#)),
            Mission("Open a throwaway interactive shell in alpine, then exit", hint: "-it for a terminal, --rm so it disappears. Type exit when you're done.", solution: "docker run -it --rm \(Img.alpine) sh", check: .ranOK(#"docker\s+(container\s+)?run\s+(.*\s)?(-[a-zA-Z]*i[a-zA-Z]*|--interactive)\s(.*\s)?alpine"#)),
            Mission("Pass GREETING=hello into an alpine container and echo it", hint: "-e sets the variable. Use sh -c '…' with single quotes so the container's shell expands it, not yours.", solution: "docker run --rm -e GREETING=hello \(Img.alpine) sh -c 'echo $GREETING'", check: .ranOK(#"docker\s+(container\s+)?run\s+(.*\s)?(-e|--env)[\s=]+GREETING\b.*alpine"#)),
            Mission("Run pwd in alpine with /etc as the working directory", hint: "There's a short flag for the working directory. Put pwd after the image.", solution: "docker run --rm -w /etc \(Img.alpine) pwd", check: .ranOK(#"docker\s+(container\s+)?run\s+(.*\s)?(-w|--workdir)[\s=]+\S+.*alpine\S*\s+pwd\b"#)),
        ]
    )

    static let lifecycle = Lesson(
        id: "container-lifecycle",
        title: "The container lifecycle",
        commands: ["docker create", "docker start", "docker stop", "docker restart", "docker pause", "docker rm"],
        topics: ["Container states", "ps vs ps -a", "create & start", "stop vs kill", "SIGTERM and the 10s timeout", "pause / unpause", "restart", "rm & rm -f", "container prune"],
        summary: "A container moves between a few states: created, running, paused and exited. A handful of commands move it from one to the next, and `rm` deletes it for good.",
        sections: [
            S("The states", """
            **created**: the container exists (config and writable layer) but its process has never started. **running**: the main process is alive. **paused**: the process is frozen in place. **exited**: the process ended, by itself or because you stopped it.

            `docker ps` shows running (and paused) containers. `docker ps -a` shows every state, and the STATUS column tells you which: `Up 3 minutes`, `Up 3 minutes (Paused)`, `Exited (137) 2 seconds ago`, `Created`.
            """, example: Example("docker ps -a --format 'table {{.Names}}\\t{{.Status}}'", output: "NAMES      STATUS\ndz-life    Up 12 seconds\ndz-first   Exited (0) 3 minutes ago")),
            S("create, start and run", """
            `docker create` makes a container without starting it, and `docker start` starts it. `docker run` is just `create` + `start` (plus a pull if needed).

            `start` also brings back a stopped container with the same name, config and files it had before. Its writable layer survives a stop.
            """, example: Example("docker create --name dz-life alpine:3.20 sleep 3600\ndocker start dz-life", output: "8d0e2c…\ndz-life")),
            S("stop vs kill", """
            `docker stop` sends the main process **SIGTERM** so it can shut down cleanly, waits up to 10 seconds, then sends **SIGKILL**. `docker kill` sends SIGKILL straight away. Use `stop -t 2` to shorten the wait.

            If `docker stop` always takes exactly 10 seconds, your main process is ignoring SIGTERM. `sleep` running as PID 1 does just that, because PID 1 gets no default signal handlers. Real servers handle it, or you can add `--init` to `docker run` to put a tiny init process in front.
            """, example: Example("time docker stop dz-life", output: "dz-life\n\nreal    0m10.2s")),
            S("restart, pause and unpause", """
            `docker restart` is a stop followed by a start, with the same 10-second grace period. It works on stopped containers too.

            `docker pause` freezes every process in the container using the cgroup freezer: no CPU, but memory stays allocated and nothing is lost. `docker unpause` carries on exactly where it left off. It's handy for debugging, less so day to day.
            """),
            S("Removing containers", """
            `docker rm NAME` deletes a stopped container, including its writable layer and logs. A running container needs `docker rm -f`, which kills it first.

            For throwaway runs, `docker run --rm` saves you the cleanup. To clear out every stopped container at once, use `docker container prune`, which asks before deleting.
            """, example: Example("docker rm -f dz-life", output: "dz-life")),
        ],
        reference: [
            O("docker create --name N IMAGE CMD", "Create a container without starting it"),
            O("docker start NAME", "Start a created or stopped container"),
            O("docker start -a NAME", "Start and attach to its output"),
            O("docker stop NAME", "SIGTERM, wait 10s, then SIGKILL"),
            O("docker stop -t 2 NAME", "Stop with a shorter grace period"),
            O("docker kill NAME", "SIGKILL immediately"),
            O("docker kill -s HUP NAME", "Send a specific signal (e.g. reload config)"),
            O("docker restart NAME", "Stop then start"),
            O("docker pause NAME  /  docker unpause NAME", "Freeze and resume every process in the container"),
            O("docker rm NAME", "Delete a stopped container"),
            O("docker rm -f NAME", "Kill and delete a running container"),
            O("docker container prune", "Delete all stopped containers"),
            O("docker ps -a --filter status=exited", "List only exited containers"),
            O("docker run --init IMAGE", "Run a tiny init as PID 1 that forwards signals"),
        ],
        macNote: "Quitting Docker Desktop, OrbStack or Colima shuts down the Linux VM, which stops every container. They come back as exited, not deleted. Containers started with `--restart unless-stopped` or `--restart always` start again automatically when the engine does.",
        images: [Img.alpine],
        diagram: Diagram(
            "Container states",
            caption: "run is create + start. stop and kill move a running container to exited, and start brings it back with its files intact. pause freezes it in place. rm deletes an exited container; rm -f kills it first.",
            nodes: [
                N("run", "docker run", icon: "terminal", .cli, at: 0, 0, detail: "= create + start"),
                N("paused", "Paused", icon: "clock", .container, at: 1, 0, detail: "frozen, memory kept"),
                N("created", "Created", icon: "cube", .container, at: 0, 1, detail: "docker create"),
                N("running", "Running", icon: "cube.fill", .container, at: 1, 1, detail: "main process alive"),
                N("exited", "Exited", icon: "cube", .container, at: 2, 1, detail: "process ended"),
                N("removed", "Removed", icon: "trash", .container, at: 3, 1, detail: "docker rm"),
            ],
            groups: [G("Shows in docker ps", ["paused", "running"])],
            edges: [
                E("run", "created", "create"),
                E("created", "running", "start"),
                E("running", "paused", "pause / unpause"),
                E("running", "exited", "stop · kill"),
                E("exited", "running", "start · restart", loopBack: true),
                E("exited", "removed", "rm"),
            ]
        ),
        missions: [
            Mission("Create (but don't start) a container dz-life that will run sleep 3600", hint: "There's a command that does the first half of docker run.", solution: "docker create --name dz-life \(Img.alpine) sleep 3600", check: .all([.container("dz-life", .exists), .ranOK(#"docker\s+(container\s+)?create\b.*dz-life"#)])),
            Mission("Start dz-life", hint: "Created containers just need starting.", solution: "docker start dz-life", check: .all([.container("dz-life", .running), .ranOK(#"docker\s+(container\s+)?start\b.*dz-life"#)])),
            Mission("Pause dz-life, then unpause it", hint: "Two commands. Check docker ps in between to see (Paused).", solution: "docker pause dz-life\ndocker unpause dz-life", check: .all([.container("dz-life", .running), .ranOK(#"docker\s+(container\s+)?pause\b.*dz-life"#), .ranOK(#"docker\s+(container\s+)?unpause\b.*dz-life"#)])),
            Mission("Stop dz-life gracefully (and notice how long it takes)", hint: "Not kill. The polite one sends SIGTERM first.", solution: "docker stop dz-life", check: .all([.container("dz-life", .stopped), .ranOK(#"docker\s+(container\s+)?stop\b.*dz-life"#)])),
            Mission("Bring dz-life back with restart", hint: "restart works on a stopped container too.", solution: "docker restart dz-life", check: .all([.container("dz-life", .running), .ranOK(#"docker\s+(container\s+)?restart\b.*dz-life"#)])),
            Mission("Remove dz-life while it's still running", hint: "Plain rm refuses a running container. Force it.", solution: "docker rm -f dz-life", check: .all([.ranOK(#"docker\s+(container\s+)?rm\b.*dz-life"#), .not(.container("dz-life", .exists))])),
        ]
    )

    static let insideContainers = Lesson(
        id: "inside-containers",
        title: "Looking inside containers",
        commands: ["docker logs", "docker exec", "docker inspect", "docker top", "docker stats", "docker cp", "docker diff"],
        topics: ["logs", "logs -f / --tail / --since", "exec -it sh", "inspect --format", "top", "stats --no-stream", "cp in and out", "diff"],
        summary: "When a container misbehaves, you read its logs, open a shell inside it, inspect its config, and copy files in and out. These commands are your debugging toolkit.",
        sections: [
            S("Logs", """
            Docker captures everything a container's main process writes to **stdout and stderr**. `docker logs NAME` prints it. That's why containerised apps log to the console instead of to files.

            `--tail 20` shows only the last 20 lines, `-f` follows new output live (Ctrl+C to stop), `--since 10m` limits by time, and `-t` adds timestamps. They combine: `docker logs -f --tail 50 dz-peek`.
            """, example: Example("docker logs --tail 3 dz-peek", output: "2026/10/17 09:12:01 [notice] 1#1: start worker processes\n2026/10/17 09:12:01 [notice] 1#1: start worker process 30\n192.168.65.1 - - [17/Oct/2026:09:12:44 +0000] \"GET / HTTP/1.1\" 200 210 \"-\" \"curl/8.7.1\"")),
            S("exec: run a command inside", """
            `docker exec NAME CMD` runs an extra process inside a **running** container, in the same namespaces as the main process: same filesystem, same network, same environment. `docker exec -it NAME sh` gives you a shell in there.

            Exit the shell and only that process ends; the container keeps running. Minimal images often have `sh` but not `bash`.
            """, example: Example("docker exec dz-peek cat /etc/os-release", output: "NAME=\"Alpine Linux\"\nID=alpine\nVERSION_ID=3.21.3")),
            S("inspect, top and stats", """
            `docker inspect NAME` dumps the container's full config and state as JSON: image, command, env, mounts, networks, IP address, restart count. `--format` (or `-f`) pulls out one field with a Go template.

            `docker top NAME` lists the processes inside, and `docker stats` shows live CPU, memory and network use. `stats` refreshes forever, so add `--no-stream` for a single snapshot.
            """, example: Example("docker inspect --format '{{.State.Status}} {{.NetworkSettings.IPAddress}}' dz-peek", output: "running 172.17.0.3")),
            S("cp: files in and out", """
            `docker cp SRC DEST` copies between your machine and a container. Whichever side has `NAME:` in front is the container: `docker cp index.html dz-peek:/usr/share/nginx/html/` copies in, `docker cp dz-peek:/etc/nginx/conf.d/default.conf .` copies out. It works on stopped containers too.

            Great for grabbing a log or config file, or a quick experiment. For anything permanent, build it into the image or use a volume instead.
            """, example: Example("docker cp index.html dz-peek:/usr/share/nginx/html/index.html", output: "Successfully copied 2.05kB to dz-peek:/usr/share/nginx/html/index.html")),
            S("diff: what changed", """
            `docker diff NAME` lists files in the container's writable layer that differ from the image: `A` added, `C` changed, `D` deleted. It's a quick way to see what an app wrote, or to spot that you edited a file inside a container (a change that's lost when the container is removed).
            """, example: Example("docker diff dz-peek", output: "C /usr/share/nginx/html/index.html\nC /var/cache/nginx\nA /var/cache/nginx/client_temp")),
        ],
        reference: [
            O("docker logs NAME", "Print everything the container wrote to stdout/stderr"),
            O("docker logs -f --tail 50 NAME", "Last 50 lines, then follow live (Ctrl+C to stop)"),
            O("docker logs --since 10m -t NAME", "Last 10 minutes, with timestamps"),
            O("docker exec -it NAME sh", "Open a shell in a running container"),
            O("docker exec NAME CMD", "Run one command inside and print its output"),
            O("docker exec -u root NAME CMD", "Run as a specific user"),
            O("docker exec -e KEY=v NAME CMD", "Run with an extra environment variable"),
            O("docker inspect NAME", "Full config and state as JSON"),
            O("docker inspect -f '{{.State.Status}}' NAME", "One field via a Go template"),
            O("docker inspect -f '{{json .Config.Env}}' NAME", "A field as JSON"),
            O("docker top NAME", "Processes running inside the container"),
            O("docker stats --no-stream", "One snapshot of CPU, memory, network and I/O"),
            O("docker cp FILE NAME:/path", "Copy into a container"),
            O("docker cp NAME:/path .", "Copy out of a container"),
            O("docker diff NAME", "Files added (A), changed (C) or deleted (D)"),
        ],
        macNote: "Container logs, files and processes all live inside the Linux VM, so you can't `tail` a log file or browse a container's filesystem from Finder. `docker logs`, `docker exec` and `docker cp` are the way in. The container IP from `docker inspect` is on the VM's internal network and usually isn't reachable from your Mac; use the published port (`localhost:8081`) instead.",
        images: [Img.nginx],
        diagram: Diagram(
            "Ways into a running container",
            caption: "Every debugging command is an API call to dockerd. logs reads what the main process printed, exec starts an extra process in the same namespaces, cp copies files to and from the container's filesystem, and inspect, top and stats read its state.",
            nodes: [
                N("ws", "Workspace", icon: "folder.fill", .file, at: 0, 1, detail: "index.html"),
                N("cli", "docker CLI", icon: "terminal", .cli, at: 1, 1, detail: "logs · exec · cp"),
                N("dockerd", "dockerd", icon: "gearshape.2", .daemon, at: 2, 1, detail: "inspect · top · stats"),
                N("log", "Container log", icon: "doc.plaintext", .file, at: 2, 0, detail: "PID 1's stdout + stderr"),
                N("main", "nginx", icon: "cube.fill", .container, at: 3, 1, detail: "main process, PID 1"),
                N("execp", "sh", icon: "terminal", .container, at: 4, 1, detail: "added by docker exec"),
                N("fs", "dz-peek filesystem", icon: "square.stack.3d.up", .storage, at: 2, 2, detail: "image + writable layer"),
            ],
            groups: [G("dz-peek", ["main", "execp"])],
            edges: [
                E("ws", "cli", "docker cp"),
                E("cli", "dockerd", "REST API"),
                E("log", "dockerd", "docker logs", dashed: true),
                E("dockerd", "main", "exec / inspect"),
                E("main", "execp", "same namespaces", dashed: true),
                E("dockerd", "fs", "cp (tar)"),
            ]
        ),
        seed: Seed(files: [
            F("index.html", """
            <!DOCTYPE html>
            <html>
            <head><title>dz-peek</title></head>
            <body>
              <h1>Hello from inside dz-peek</h1>
              <p>This page was copied in with docker cp.</p>
            </body>
            </html>

            """),
            F("README.md", "# Looking inside containers\nCopy index.html into the dz-peek container, then read it back from the inside.\n"),
        ]),
        missions: [
            Mission("Run nginx in the background as dz-peek, published on port 8081", hint: "Same shape as before: -d, --name, -p HOST:80.", solution: "docker run -d --name dz-peek -p 8081:80 \(Img.nginx)", check: .all([.container("dz-peek", .running), .publishes("dz-peek", 8081)])),
            Mission("Copy index.html from your workspace into nginx's web root in dz-peek", hint: "docker cp SRC NAME:/path. nginx serves /usr/share/nginx/html.", solution: "docker cp index.html dz-peek:/usr/share/nginx/html/index.html", check: .ranOK(#"docker\s+(container\s+)?cp\s+(\S+\s+)*\S*index\.html\s+dz-peek:/"#)),
            Mission("Read the copied page from inside the container", hint: "Run cat inside dz-peek with docker exec.", solution: "docker exec dz-peek cat /usr/share/nginx/html/index.html", check: .ranOK(#"docker\s+(container\s+)?exec\s+(.*\s)?dz-peek\s+(.*\s)?cat\b"#)),
            Mission("Show only the last 5 lines of dz-peek's logs", hint: "docker logs has a flag to limit output to the end.", solution: "docker logs --tail 5 dz-peek", check: .ranOK(#"docker\s+(container\s+)?logs\b(?=.*\bdz-peek\b)(?=.*(--tail|-n)[\s=]+\d+)"#)),
            Mission("Print just dz-peek's status with inspect and a Go template", hint: "--format '{{.State.Status}}'", solution: "docker inspect --format '{{.State.Status}}' dz-peek", check: .ranOK(#"docker\s+(container\s+)?inspect\b(?=.*\bdz-peek\b)(?=.*\s(-f|--format)[\s=])"#)),
            Mission("Copy nginx's default.conf out of dz-peek into your workspace", hint: "Reverse the docker cp arguments. The file is /etc/nginx/conf.d/default.conf, and . means here.", solution: "docker cp dz-peek:/etc/nginx/conf.d/default.conf .", check: .all([.ranOK(#"docker\s+(container\s+)?cp\s+(\S+\s+)*dz-peek:\S+\s+\S+"#), .exists("default.conf", .file)])),
        ]
    )
}
