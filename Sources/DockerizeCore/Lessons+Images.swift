import Foundation

extension Curriculum {
    // MARK: - Images & Dockerfiles

    static let images = Category(
        id: "images", title: "Images & Dockerfiles", icon: "square.stack.3d.up",
        blurb: "Pull, tag and inspect images, then write Dockerfiles that build fast and ship small.",
        lessons: [pullingImages, firstDockerfile, buildCache, multiStage]
    )

    // MARK: Pulling & managing images

    static let pullingImages = Lesson(
        id: "pulling-images",
        title: "Pulling & managing images",
        commands: ["docker pull", "docker images", "docker tag", "docker rmi", "docker history", "docker image inspect"],
        topics: ["Registries, repositories & tags", "Digests", "docker pull", "docker images", "docker tag", "docker rmi", "docker history", "docker image inspect", "Why pin tags", "Multi-arch images"],
        summary: "An image is a read-only stack of filesystem layers plus a little config, stored in a registry under a name and a tag. You pull it once and every container starts from it.",
        sections: [
            S("What's in an image name?", """
            A full reference looks like `docker.io/library/alpine:3.20`. That's the **registry** (`docker.io`, Docker Hub), the **repository** (`library/alpine`; `library/` is where official images live) and the **tag** (`3.20`).

            Docker fills in the defaults, so `alpine:3.20` means the same thing. Leave the tag off and you get `:latest`. A tag is a movable label: whoever owns the repository can point it at a new image at any time.

            A **digest** (`alpine@sha256:4bcff6…`) is the image's content hash. It never changes, so it's the only reference that is truly fixed.
            """, example: Example("docker pull \(Img.alpine)", output: "3.20: Pulling from library/alpine\n9986a736f7d3: Pull complete\nDigest: sha256:1e42bbe2508154c9126d48c2b8a75420c3544343bf86fd041fb7527e017a4b4a\nStatus: Downloaded newer image for alpine:3.20\ndocker.io/library/alpine:3.20")),
            S("Listing what you have", """
            `docker images` (or `docker image ls`) lists local images with their tag, **image ID** and size. Two tags with the same ID are the same image under two names, not two copies.

            Filter by repository with `docker images alpine`, or show digests with `--digests`.
            """, example: Example("docker images", output: "REPOSITORY   TAG       IMAGE ID       CREATED       SIZE\nbusybox      1.36      3f57d9401f8d   4 months ago  4.27MB\nalpine       3.20      0a9a5dfd008f   2 months ago  8.83MB")),
            S("Tags are just names", """
            `docker tag SOURCE TARGET` adds another name to an existing image. Nothing is copied. You do this before pushing to your own registry (`docker tag dz-app:1.0 registry.example.com/team/app:1.0`) or to give a base image a friendlier name.

            `docker rmi NAME` removes a **tag**. The image itself is only deleted when its last tag goes and no container uses it. That's why removing your extra tag leaves the original untouched.
            """, example: Example("docker tag \(Img.alpine) dz-mybase:1.0 && docker rmi dz-mybase:1.0", output: "Untagged: dz-mybase:1.0")),
            S("Layers and history", """
            Each instruction that changes files in a Dockerfile adds a **layer**. Layers are shared: ten images built `FROM alpine` store alpine's layer once.

            `docker history` shows the layers newest first, with the instruction that made each one and its size. `<missing>` just means that layer was built elsewhere and has no local ID; it's normal for pulled images.
            """, example: Example("docker history \(Img.alpine)", output: "IMAGE          CREATED       CREATED BY                                      SIZE\n0a9a5dfd008f   2 months ago  CMD [\"/bin/sh\"]                                 0B\n<missing>      2 months ago  ADD alpine-minirootfs-3.20.3-aarch64.tar.gz …   8.83MB")),
            S("Inspecting an image", """
            `docker image inspect` prints the full config as JSON: environment, default command, exposed ports, labels, layers, OS and CPU architecture. Use `--format` with a Go template to pull out one field instead of scrolling.
            """, example: Example("docker image inspect --format '{{.Os}}/{{.Architecture}}' \(Img.alpine)", output: "linux/arm64")),
            S("Pin your tags, and know your architecture", """
            `latest` is not "the newest". It's just the tag used when you don't give one, and it can move under you. A build that worked on Monday can break on Tuesday. Pin a specific tag (`python:3.12-alpine`) in anything you ship, and a digest when you need byte-for-byte repeatability.

            Most official images are **multi-arch**: the tag points at an index listing one image per platform (`linux/amd64`, `linux/arm64`, …). `docker pull` picks the one matching your machine, so the same tag gives an Apple silicon laptop and an Intel server different bytes.
            """),
        ],
        reference: [
            O("docker pull IMAGE[:TAG]", "Download an image (default tag is latest)"),
            O("docker pull IMAGE@sha256:…", "Pull an exact image by digest"),
            O("docker pull --platform linux/amd64 IMAGE", "Pull a specific architecture"),
            O("docker images  /  docker image ls", "List local images"),
            O("docker images REPO", "List only images from one repository"),
            O("docker images --digests", "Show each image's digest"),
            O("docker images -f dangling=true", "List untagged <none> images"),
            O("docker tag SRC TARGET", "Add another name to an image"),
            O("docker rmi IMAGE  /  docker image rm", "Remove a tag (and the image when no tags remain)"),
            O("docker image prune", "Delete dangling images; -a deletes all unused ones"),
            O("docker history IMAGE", "Show the layers and the instructions that made them"),
            O("docker image inspect IMAGE", "Full image config as JSON"),
            O("docker image inspect -f '{{.Architecture}}' IMAGE", "Print one field with a Go template"),
        ],
        macNote: "Apple silicon Macs pull `linux/arm64` images, while most servers run `linux/amd64`. `docker pull --platform linux/amd64` fetches the Intel variant, which runs under emulation (Rosetta or QEMU inside the VM): it works, but slower. Images are stored on the Linux VM's disk, not in your Mac's filesystem.",
        images: [Img.alpine, Img.busybox],
        diagram: Diagram(
            "Pulling an image",
            caption: "The daemon asks the registry for the tag's manifest. A multi-arch tag points at an index, so the daemon picks the variant for your platform, downloads only the layers it doesn't already have, and records the tag locally.",
            nodes: [
                N("you", "You", icon: "person.fill", .actor, at: 0, 0, detail: "docker pull"),
                N("cli", "docker CLI", icon: "terminal", .cli, at: 1, 0, detail: "sends the request"),
                N("dockerd", "dockerd", icon: "gearshape.2", .daemon, at: 2, 0, detail: "does the pull"),
                N("hub", "Docker Hub", icon: "cloud", .registry, at: 3, 0, detail: "library/alpine"),
                N("index", "Manifest index", icon: "list.bullet.rectangle", .registry, at: 3, 1, detail: "amd64, arm64, …"),
                N("layers", "Image layers", icon: "square.stack.3d.up.fill", .image, at: 2, 1, detail: "stored once, shared"),
                N("tags", "Local tags", icon: "tag", .image, at: 1, 1, detail: "alpine:3.20, dz-mybase:1.0"),
            ],
            groups: [G("Registry", ["hub", "index"]), G("Local image store", ["layers", "tags"])],
            edges: [
                E("you", "cli", "pull alpine:3.20"),
                E("cli", "dockerd", "API call"),
                E("dockerd", "hub", "GET manifest"),
                E("hub", "index", "tag → index"),
                E("index", "layers", "your platform"),
                E("layers", "tags", "tagged"),
            ]
        ),
        missions: [
            Mission("Pull the alpine and busybox images", hint: "One docker pull per image. Use the exact tags this lesson uses.", solution: "docker pull \(Img.alpine)\ndocker pull \(Img.busybox)", check: .all([
                .ranOK(#"docker (image )?pull\b.*alpine"#),
                .ranOK(#"docker (image )?pull\b.*busybox"#),
                .image(Img.alpine),
                .image(Img.busybox),
            ])),
            Mission("Tag alpine as dz-mybase:1.0", hint: "docker tag takes the existing name first, then the new one.", solution: "docker tag \(Img.alpine) dz-mybase:1.0", check: .all([
                .ranOK(#"docker (image )?tag\b.*dz-mybase:1\.0"#),
                .image("dz-mybase:1.0"),
            ])),
            Mission("Show the layer history of dz-mybase:1.0", hint: "Which command lists the instructions that built each layer?", solution: "docker history dz-mybase:1.0", check: .ranOK(#"docker (image )?history\b"#)),
            Mission("Remove the dz-mybase:1.0 tag and check alpine is still there", hint: "rmi removes a name. Then list your images.", solution: "docker rmi dz-mybase:1.0\ndocker images", check: .all([
                .ranOK(#"docker (rmi|image (rm|remove))\b.*dz-mybase"#),
                .not(.image("dz-mybase:1.0")),
                .image(Img.alpine),
            ])),
            Mission("Print alpine's OS and architecture with --format", hint: "docker image inspect, with a Go template that reads .Architecture.", solution: "docker image inspect --format '{{.Os}}/{{.Architecture}}' \(Img.alpine)", check: .ranOK(#"docker (image )?inspect\b.*(--format|-f)\b.*Architecture"#)),
        ]
    )

    // MARK: Your first Dockerfile

    static let firstDockerfile = Lesson(
        id: "first-dockerfile",
        title: "Your first Dockerfile",
        commands: ["docker build", "docker run"],
        topics: ["FROM", "WORKDIR", "COPY", "RUN", "ENV", "EXPOSE", "CMD", "Build context", "docker build -t", "Rebuilding"],
        summary: "A Dockerfile is a recipe: start from a base image, add your files, run setup commands, and say what to start. docker build turns it into an image you can run anywhere.",
        sections: [
            S("The recipe", """
            A Dockerfile is a list of instructions, run top to bottom. Each one builds on the result of the last.

            `FROM` picks the base image. `WORKDIR` sets (and creates) the directory later instructions run in. `COPY` copies files from your project into the image. `RUN` runs a shell command at **build** time, like installing a package. `ENV` sets an environment variable. `EXPOSE` documents which port the app listens on. `CMD` is the command a container runs when it **starts**.
            """, example: Example("cat Dockerfile", output: "FROM nginx:1.27-alpine\nWORKDIR /usr/share/nginx/html\nENV SITE_VERSION=1.0\nCOPY site/ .\nRUN echo \"ok\" > health.txt\nEXPOSE 80\nCMD [\"nginx\", \"-g\", \"daemon off;\"]")),
            S("The build context", """
            The `.` at the end of `docker build -t dz-site:1.0 .` is the **build context**: the folder whose files `COPY` can see. The CLI sends it to the builder (BuildKit) before anything runs.

            `COPY` paths are relative to the context, and you can't reach outside it: `COPY ../secrets .` fails. Keep the context small; the next lesson covers `.dockerignore`.
            """, example: Example("docker build -t dz-site:1.0 .", output: "[+] Building 1.2s (8/8) FINISHED\n => [internal] load build definition from Dockerfile\n => [1/3] FROM docker.io/library/nginx:1.27-alpine\n => [2/3] COPY site/ .\n => [3/3] RUN echo \"ok\" > health.txt\n => exporting to image\n => => naming to docker.io/library/dz-site:1.0")),
            S("Run what you built", """
            Your image runs like any other. `EXPOSE` doesn't publish anything by itself; you still map a host port with `-p HOST:CONTAINER`.
            """, example: Example("docker run -d --name dz-site -p 8082:80 dz-site:1.0 && curl -s localhost:8082", output: "<!doctype html>\n<title>dz-site</title>\n<h1>Hello from dz-site v1.0</h1>")),
            S("RUN vs CMD", """
            `RUN` happens once, while building, and its result is saved into the image. `CMD` is saved as metadata and runs every time a container starts.

            Write `CMD` in **exec form**, a JSON array like `["nginx", "-g", "daemon off;"]`. That runs the program directly as PID 1, so it receives `docker stop`'s signal. The shell form (`CMD nginx -g 'daemon off;'`) wraps it in `/bin/sh -c`.
            """),
            S("Change, rebuild, retag", """
            An image is frozen. Editing `site/index.html` changes nothing in `dz-site:1.0` or in the running container. To ship the change, build again under a **new tag**, then start a container from it.

            Using a new tag (`1.1`) instead of overwriting `1.0` means you can always roll back to the old one.
            """, example: Example("docker build -t dz-site:1.1 . && docker images dz-site", output: "REPOSITORY   TAG   IMAGE ID       CREATED          SIZE\ndz-site      1.1   7d2c19a0b4e1   3 seconds ago    48.3MB\ndz-site      1.0   c41f8e2d9a77   2 minutes ago    48.3MB")),
        ],
        reference: [
            O("FROM IMAGE:TAG", "Base image to start from (first instruction)"),
            O("WORKDIR /path", "Set and create the working directory for later steps"),
            O("COPY SRC DEST", "Copy files from the build context into the image"),
            O("RUN command", "Run a command at build time and save the result as a layer"),
            O("ENV KEY=value", "Set an environment variable for build steps and containers"),
            O("EXPOSE 80", "Document the port the app listens on (doesn't publish it)"),
            O("CMD [\"prog\", \"arg\"]", "Default command when a container starts (exec form)"),
            O("docker build -t NAME:TAG .", "Build the Dockerfile in . and tag the result"),
            O("docker build -f path/Dockerfile .", "Use a Dockerfile with another name or location"),
            O("docker build -t A:1 -t A:latest .", "Apply several tags in one build"),
            O("docker run -d -p 8082:80 NAME:TAG", "Run your image with a published port"),
            O("docker images NAME", "List the tags you've built for an image"),
        ],
        macNote: "The build runs inside Docker's Linux VM, so the CLI copies the build context from your Mac into the VM on every build. A big project folder makes every build slower, which is one more reason for a `.dockerignore`. The image you build is for your Mac's architecture (arm64 on Apple silicon) unless you pass `--platform`.",
        images: [Img.nginx],
        diagram: Diagram(
            "From Dockerfile to container",
            caption: "docker build sends the build context (your folder, Dockerfile included) to BuildKit. BuildKit runs each instruction and saves the results as image layers. docker run starts a container from that image.",
            nodes: [
                N("you", "You", icon: "person.fill", .actor, at: 0, 0, detail: "docker build ."),
                N("cli", "docker CLI", icon: "terminal", .cli, at: 1, 0, detail: "sends the context"),
                N("buildkit", "BuildKit", icon: "hammer", .daemon, at: 2, 0, detail: "runs each step"),
                N("image", "dz-site:1.0", icon: "square.stack.3d.up.fill", .image, at: 3, 0, detail: "nginx + your layers"),
                N("ctr", "dz-site", icon: "shippingbox.fill", .container, at: 4, 0, detail: "nginx running"),
                N("dockerfile", "Dockerfile", icon: "doc.text", .file, at: 0, 1, detail: "the recipe"),
                N("context", "Build context", icon: "folder.fill", .file, at: 1, 1, detail: "Dockerfile + site/"),
                N("port", "localhost:8082", icon: "network", .network, at: 4, 1, detail: "-p 8082:80"),
            ],
            groups: [G("Your folder", ["dockerfile", "context"]), G("Docker engine", ["buildkit", "image", "ctr"])],
            edges: [
                E("you", "cli", "build -t"),
                E("dockerfile", "context", "lives in"),
                E("context", "cli", "tarred up"),
                E("cli", "buildkit", "context"),
                E("buildkit", "image", "layers"),
                E("image", "ctr", "docker run"),
                E("ctr", "port", "published"),
            ]
        ),
        seed: Seed(files: [
            F("Dockerfile", """
            # Start from a small nginx image.
            FROM \(Img.nginx)

            # nginx serves files from this folder.
            WORKDIR /usr/share/nginx/html

            ENV SITE_VERSION=1.0

            # Copy our site over the default page.
            COPY site/ .

            # Runs once, at build time.
            RUN echo "ok" > health.txt

            EXPOSE 80

            # Runs every time a container starts. Exec form, so nginx is PID 1.
            CMD ["nginx", "-g", "daemon off;"]

            """),
            F("site/index.html", """
            <!doctype html>
            <title>dz-site</title>
            <link rel="stylesheet" href="style.css">
            <h1>Hello from dz-site v1.0</h1>
            <p>Built from a Dockerfile.</p>

            """),
            F("site/style.css", "body { font-family: system-ui, sans-serif; margin: 3rem; }\nh1 { color: #1060ff; }\n"),
        ]),
        missions: [
            Mission("Build the Dockerfile as dz-site:1.0", hint: "docker build with -t NAME:TAG, and . as the build context.", solution: "docker build -t dz-site:1.0 .", check: .image("dz-site:1.0")),
            Mission("Run it in the background as dz-site, published on port 8082", hint: "-d, --name, and -p HOST:CONTAINER. nginx listens on 80.", solution: "docker run -d --name dz-site -p 8082:80 dz-site:1.0", check: .all([
                .container("dz-site", .running),
                .publishes("dz-site", 8082),
            ])),
            Mission("Fetch the page with curl", hint: "Your Mac reaches the container through localhost:8082.", solution: "sleep 1 && curl -s http://localhost:8082", check: .ranOK(#"curl\b.*(localhost|127\.0\.0\.1):8082"#)),
            Mission("Change v1.0 to v1.1 in site/index.html and build dz-site:1.1", hint: "Edit the file in any editor (or overwrite it with printf), then build with a new tag.", solution: "printf '<!doctype html>\\n<title>dz-site</title>\\n<h1>Hello from dz-site v1.1</h1>\\n' > site/index.html\ndocker build -t dz-site:1.1 .", check: .all([
                .exists("site/index.html", .file),
                .not(.contains("site/index.html", "v1.0")),
                .image("dz-site:1.1"),
            ])),
            Mission("List the dz-site images you've built", hint: "docker images, optionally filtered by repository name.", solution: "docker images dz-site", check: .ranOK(#"docker (images|image (ls|list))\b"#)),
        ]
    )

    // MARK: Layers & the build cache

    static let buildCache = Lesson(
        id: "build-cache",
        title: "Layers & the build cache",
        commands: ["docker build", "docker system df"],
        topics: ["Layers", "The build cache", "Instruction order", ".dockerignore", "--no-cache", "--progress=plain", "Image size", "docker system df"],
        summary: "BuildKit reuses a step's cached result when nothing it depends on has changed. Order your Dockerfile so slow steps depend on files that rarely change, and keep junk out of the build context.",
        sections: [
            S("How the cache decides", """
            For each instruction, BuildKit asks: have I run exactly this before, on exactly the same parent layer? For `COPY`, it also checks a hash of the files being copied. If yes, it reuses the saved layer and prints `CACHED`.

            The first miss breaks the chain. Every instruction after a changed one runs again, even if that instruction didn't change itself.
            """, example: Example("docker build -t dz-cache:fast .", output: " => CACHED [2/5] WORKDIR /app\n => CACHED [3/5] COPY requirements.txt .\n => CACHED [4/5] RUN echo \"Installing dependencies…\" && sleep 5\n => [5/5] COPY . .\n => exporting to image")),
            S("Order matters", """
            `COPY . .` copies everything, so changing any file (one line of `app.py`) invalidates it, and every step after it. If the slow dependency install comes after, you wait for it on every edit.

            The fix: copy only the **dependency manifest** (`requirements.txt`, `package.json`, `go.mod`…), install, and only then copy the source. Dependencies change rarely, so the slow step stays cached.
            """, example: Example("cat Dockerfile", output: "FROM python:3.12-alpine\nWORKDIR /app\nCOPY requirements.txt .\nRUN pip install -r requirements.txt\nCOPY . .\nCMD [\"python\", \"app.py\"]")),
            S(".dockerignore", """
            A `.dockerignore` next to the Dockerfile lists paths to leave out of the build context, with the same patterns as `.gitignore`. Ignored files aren't sent to the builder, can't be copied by `COPY . .`, and can't bust the cache when they change.

            Typical entries: `.git`, `node_modules`, `__pycache__`, `.venv`, test data, logs, and `.env` files with secrets.
            """, example: Example("cat .dockerignore", output: "testdata/\n.git\n__pycache__\n*.log\n.env")),
            S("Seeing what happened", """
            `--progress=plain` prints every step's full output instead of the collapsing progress view, which is what you want when a `RUN` fails or you want to see which steps say `CACHED`.

            `--no-cache` ignores the cache and runs every step. Use it when a step fetches something that changed upstream (a `RUN apk add` that should pick up a security fix) but the instruction text didn't change.
            """, example: Example("docker build --no-cache --progress=plain -t dz-cache:fast .", output: "#7 [4/5] RUN echo \"Installing dependencies…\" && sleep 5\n#7 0.215 Installing dependencies…\n#7 DONE 5.2s")),
            S("Size and disk usage", """
            Every layer adds to the image's size, and deleting a file in a later step doesn't shrink an earlier layer. Copying a 4 MB test-data folder you never use makes every copy of the image 4 MB bigger.

            `docker images` shows each image's size. `docker system df` sums up images, containers, volumes and the **build cache**, and `docker builder prune` clears the cache when it grows.
            """, example: Example("docker system df", output: "TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE\nImages          4         1         112.4MB   64.1MB (57%)\nContainers      1         1         1.1kB     0B (0%)\nLocal Volumes   0         0         0B        0B\nBuild Cache     14        0         8.2MB     8.2MB")),
        ],
        reference: [
            O("docker build --progress=plain .", "Print every step's full output"),
            O("docker build --no-cache .", "Ignore the cache and run every step"),
            O("docker build --pull .", "Check the registry for a newer base image first"),
            O("COPY requirements.txt .", "Copy the manifest alone so the install step stays cached"),
            O("COPY . .", "Copy the whole context (put it after slow steps)"),
            O(".dockerignore", "Paths left out of the build context (.gitignore syntax)"),
            O("!keep.txt  (in .dockerignore)", "Re-include a path an earlier pattern excluded"),
            O("RUN a && b && rm -rf /tmp/x", "Clean up in the same RUN, or the files stay in the layer"),
            O("docker images", "Image sizes"),
            O("docker history IMAGE", "Which layer made the image big"),
            O("docker system df", "Disk used by images, containers, volumes, build cache"),
            O("docker builder prune", "Delete the build cache (-a for all of it)"),
        ],
        macNote: "The build cache lives on the Docker VM's virtual disk, not on your Mac. Docker Desktop's disk image only grows until you prune, so check `docker system df` now and then. Sending a large build context from macOS into the VM is noticeably slow, so a good `.dockerignore` pays off more on a Mac than on Linux.",
        images: [Img.python],
        diagram: Diagram(
            "Cache hits and misses after editing app.py",
            caption: "Top: COPY . . comes first, so editing app.py misses the cache there and the slow install runs again. Bottom: the manifest is copied first, so the install stays cached and only the final COPY reruns.",
            nodes: [
                N("b1", "FROM python", icon: "square.stack.3d.up", .image, at: 0, 0, detail: "cache hit"),
                N("b2", "COPY . .", icon: "doc.on.doc", .file, at: 1, 0, detail: "MISS: app.py changed"),
                N("b3", "RUN install", icon: "clock", .daemon, at: 2, 0, detail: "MISS: runs again, 5s"),
                N("b4", "CMD", icon: "terminal", .image, at: 3, 0, detail: "MISS"),
                N("g1", "FROM python", icon: "square.stack.3d.up", .image, at: 0, 1, detail: "cache hit"),
                N("g2", "COPY requirements.txt", icon: "doc.plaintext", .file, at: 1, 1, detail: "cache hit"),
                N("g3", "RUN install", icon: "bolt.fill", .daemon, at: 2, 1, detail: "cache hit, 0s"),
                N("g4", "COPY . .", icon: "doc.on.doc", .file, at: 3, 1, detail: "MISS: app.py changed"),
                N("g5", "CMD", icon: "terminal", .image, at: 4, 1, detail: "MISS, instant"),
            ],
            groups: [G("Slow: source first", ["b1", "b2", "b3", "b4"]), G("Fast: manifest first", ["g1", "g2", "g3", "g4", "g5"])],
            edges: [
                E("b1", "b2", "hit"),
                E("b2", "b3", "miss"),
                E("b3", "b4", "miss"),
                E("g1", "g2", "hit"),
                E("g2", "g3", "hit"),
                E("g3", "g4", "hit"),
                E("g4", "g5", "miss"),
            ]
        ),
        seed: Seed(files: [
            F("Dockerfile", """
            FROM \(Img.python)
            WORKDIR /app

            # Copies everything: source, test data, the lot.
            COPY . .

            # Stand-in for `pip install -r requirements.txt`: slow, and it only
            # needs requirements.txt. (The app uses just the standard library.)
            RUN echo "Installing dependencies from requirements.txt..." && cat requirements.txt && sleep 5

            CMD ["python", "app.py"]

            """),
            F("requirements.txt", "# Standard library only for now.\n# Pinned dependencies would go here, e.g. requests==2.32.3\n"),
            F("app.py", """
            import json
            from http.server import BaseHTTPRequestHandler, HTTPServer


            class Handler(BaseHTTPRequestHandler):
                def do_GET(self):
                    body = json.dumps({"service": "dz-cache", "status": "ok"}).encode()
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(body)


            if __name__ == "__main__":
                print("listening on :8000", flush=True)
                HTTPServer(("", 8000), Handler).serve_forever()

            """),
            F("testdata/README.md", "Local sensor dumps used by the test suite. Never needed in the image.\n"),
            F("testdata/sensors-2026-10-01.csv", "timestamp,sensor,celsius,status\n" + String(repeating: "2026-10-01T00:00:00Z,sensor-7,21.4,ok\n", count: 100_000)),
        ]),
        missions: [
            Mission("Build the badly ordered Dockerfile as dz-cache:slow", hint: "Watch which step takes five seconds.", solution: "docker build -t dz-cache:slow .", check: .image("dz-cache:slow")),
            Mission("Reorder the Dockerfile: COPY requirements.txt and the install step before COPY . .", hint: "Copy only requirements.txt, run the install, then copy everything else.", solution: """
            cat > Dockerfile <<'EOF'
            FROM \(Img.python)
            WORKDIR /app
            COPY requirements.txt .
            RUN echo "Installing dependencies from requirements.txt..." && cat requirements.txt && sleep 5
            COPY . .
            CMD ["python", "app.py"]
            EOF
            """, check: .matches("Dockerfile", #"(?s)COPY\s+(\./)?requirements\.txt\s.*\bRUN\b.*COPY\s+\.\s+\.?/?"#)),
            Mission("Add a .dockerignore that excludes testdata/", hint: "One pattern per line, like .gitignore.", solution: "printf 'testdata/\\n.git\\n__pycache__\\n' > .dockerignore", check: .contains(".dockerignore", "testdata")),
            Mission("Build again as dz-cache:fast", hint: "Same build command, new tag. Build it twice and the second run is all CACHED.", solution: "docker build -t dz-cache:fast .", check: .all([
                .image("dz-cache:fast"),
                .ranOK(#"docker (image |buildx )?build\b.*dz-cache:fast"#),
            ])),
            Mission("Rebuild from scratch with --no-cache and plain progress output", hint: "Two build flags: one skips the cache, one prints every step.", solution: "docker build --no-cache --progress=plain -t dz-cache:fast .", check: .ranOK(#"docker (image |buildx )?build\b.*--no-cache"#)),
            Mission("Compare the sizes of dz-cache:slow and dz-cache:fast", hint: "List the dz-cache images. Which one carries the test data?", solution: "docker images dz-cache", check: .ranOK(#"docker (images|image (ls|list)|system df)\b"#)),
        ]
    )

    // MARK: Multi-stage builds

    static let multiStage = Lesson(
        id: "multi-stage-builds",
        title: "Multi-stage builds",
        commands: ["docker build --target", "docker build --build-arg", "docker run --entrypoint"],
        topics: ["Multi-stage builds", "COPY --from", "--target", "ARG vs ENV", "--build-arg", "ENTRYPOINT vs CMD", "Exec vs shell form", "USER", "LABEL", "HEALTHCHECK"],
        summary: "A multi-stage build uses one stage with all the build tools to produce an artifact, then copies just that artifact into a small final image. The tools never ship.",
        sections: [
            S("Build big, ship small", """
            A Dockerfile can have several `FROM` lines. Each starts a new **stage**. Name one with `AS`: `FROM alpine:3.20 AS build`.

            `COPY --from=build /src/greet /usr/local/bin/greet` copies a file out of an earlier stage. Only the **last** stage becomes your image, so compilers, caches and source code from the build stage are left behind.
            """, example: Example("cat Dockerfile", output: "FROM alpine:3.20 AS build\n…\nRUN … > greet\n\nFROM busybox:1.36\nCOPY --from=build /src/greet /usr/local/bin/greet\nUSER app\nENTRYPOINT [\"/usr/local/bin/greet\"]\nCMD [\"world\"]")),
            S("Building one stage with --target", """
            `--target build` stops after the stage named `build` and tags that. It's useful for debugging a build step, or for a stage that runs tests in CI.

            Compare the two images with `docker images`: the build stage carries its tools; the final image doesn't.
            """, example: Example("docker images dz-multi", output: "REPOSITORY   TAG     IMAGE ID       CREATED          SIZE\ndz-multi     build   5be0c3a1f2d9   8 seconds ago    29.8MB\ndz-multi     1.0     a1d93e77c0f4   20 seconds ago   4.27MB")),
            S("ARG vs ENV", """
            `ARG` is a **build-time** variable. Set it with `docker build --build-arg GREETING=Howdy`. It's visible to `RUN` steps in its stage and gone from the final image. An `ARG` declared before the first `FROM` can only be used in `FROM` lines.

            `ENV` is baked into the image and visible to the running container too. Never pass secrets with either; they show up in `docker history`. Use `RUN --mount=type=secret` instead.
            """, example: Example("docker build --build-arg GREETING=Howdy -t dz-multi:howdy . && docker run --rm dz-multi:howdy", output: "Howdy, world! (running as app)")),
            S("ENTRYPOINT vs CMD", """
            `ENTRYPOINT` is the program. `CMD` is its default arguments. Arguments after the image name in `docker run` **replace CMD**, so `docker run dz-multi:1.0 Docker` runs `greet Docker`. Without an ENTRYPOINT, those arguments replace the whole command (`docker run alpine ls /`).

            To replace the entrypoint itself, use `--entrypoint`. Prefer the **exec form** (JSON array) for both: in the shell form, `/bin/sh -c` wraps your program and CMD arguments are silently ignored.
            """, example: Example("docker run --rm dz-multi:1.0 Docker", output: "Hello, Docker! (running as app)")),
            S("USER, LABEL and HEALTHCHECK", """
            Containers run as **root** unless you say otherwise. Create an unprivileged user and switch to it with `USER app` near the end, so a compromised process can't write to the image's system files.

            `LABEL` adds metadata (`org.opencontainers.image.source=…`) that `docker image inspect` shows. `HEALTHCHECK CMD wget -qO- localhost/health || exit 1` lets Docker mark a container `healthy` or `unhealthy`; you'll see it in `docker ps`.
            """, example: Example("docker run --rm --entrypoint id dz-multi:1.0 -u", output: "10001")),
        ],
        reference: [
            O("FROM IMAGE AS name", "Start a named build stage"),
            O("COPY --from=name SRC DEST", "Copy a file out of an earlier stage"),
            O("COPY --from=IMAGE SRC DEST", "Copy a file straight out of another image"),
            O("docker build --target name .", "Build only up to the named stage"),
            O("ARG NAME=default", "Build-time variable (not in the final image's env)"),
            O("docker build --build-arg NAME=value .", "Set an ARG for this build"),
            O("ENTRYPOINT [\"prog\"]", "The program the container always runs"),
            O("CMD [\"arg\"]", "Default args (or command); replaced by args after the image name"),
            O("docker run --entrypoint prog IMAGE args", "Override the entrypoint for one run"),
            O("USER name[:group]", "Run later steps and the container as this user"),
            O("LABEL key=value", "Add metadata to the image"),
            O("HEALTHCHECK CMD cmd || exit 1", "Command Docker runs to judge container health"),
            O("docker image inspect -f '{{.Config.User}}' IMAGE", "See which user an image runs as"),
        ],
        macNote: "To build for amd64 servers from an Apple silicon Mac, use `docker buildx build --platform linux/amd64` (or both: `--platform linux/amd64,linux/arm64` with `--push`). Emulated `RUN` steps are much slower, so multi-stage builds help: keep heavy work in as few steps as possible, or cross-compile in a native build stage.",
        images: [Img.alpine, Img.busybox],
        diagram: Diagram(
            "Two stages, one small image",
            caption: "The build stage starts from alpine, does the heavy work and produces one file. The final stage starts from busybox and copies only that file. --target build stops after the first stage instead.",
            nodes: [
                N("alpine", "FROM alpine AS build", icon: "square.stack.3d.up", .image, at: 0, 0, detail: "tools live here"),
                N("run", "RUN steps", icon: "hammer", .daemon, at: 1, 0, detail: "build + 20 MB toolchain"),
                N("artifact", "/src/greet", icon: "doc.text", .file, at: 2, 0, detail: "the artifact"),
                N("buildimg", "dz-multi:build", icon: "square.stack.3d.up.fill", .image, at: 3, 0, detail: "--target build, ~30 MB"),
                N("busybox", "FROM busybox", icon: "square.stack.3d.up", .image, at: 1, 1, detail: "tiny base"),
                N("final", "dz-multi:1.0", icon: "square.stack.3d.up.fill", .image, at: 2, 1, detail: "~4 MB, USER app"),
                N("ctr", "Container", icon: "shippingbox.fill", .container, at: 3, 1, detail: "greet world"),
            ],
            groups: [G("Stage 1: build", ["alpine", "run", "artifact"]), G("Stage 2: final", ["busybox", "final"])],
            edges: [
                E("alpine", "run", "WORKDIR /src"),
                E("run", "artifact", "produces"),
                E("artifact", "buildimg", "--target build", dashed: true),
                E("artifact", "final", "COPY --from=build"),
                E("busybox", "final", "base"),
                E("final", "ctr", "docker run"),
            ]
        ),
        seed: Seed(files: [
            F("Dockerfile", """
            # ---- Stage 1: build ----
            FROM \(Img.alpine) AS build
            ARG GREETING=Hello
            WORKDIR /src
            COPY greet.sh.in .
            # Pretend toolchain: big, needed only while building.
            RUN dd if=/dev/zero of=/src/toolchain.bin bs=1M count=20 2>/dev/null
            # "Compile" the artifact.
            RUN sed "s/__GREETING__/${GREETING}/" greet.sh.in > greet && chmod +x greet

            # ---- Stage 2: final ----
            FROM \(Img.busybox)
            LABEL org.opencontainers.image.title="dz-multi"
            RUN adduser -D -H -u 10001 app
            COPY --from=build /src/greet /usr/local/bin/greet
            USER app
            ENTRYPOINT ["/usr/local/bin/greet"]
            CMD ["world"]

            """),
            F("greet.sh.in", """
            #!/bin/sh
            echo "__GREETING__, ${1:-world}! (running as $(id -un))"

            """),
        ]),
        missions: [
            Mission("Build the final image as dz-multi:1.0", hint: "A normal docker build. All stages run, only the last is tagged.", solution: "docker build -t dz-multi:1.0 .", check: .image("dz-multi:1.0")),
            Mission("Build only the build stage, tagged dz-multi:build", hint: "--target takes the name after AS.", solution: "docker build --target build -t dz-multi:build .", check: .all([
                .ranOK(#"docker (image |buildx )?build\b.*--target[ =]build"#),
                .image("dz-multi:build"),
            ])),
            Mission("Run dz-multi:1.0 with your name as the argument", hint: "Anything after the image name replaces CMD.", solution: "docker run --rm dz-multi:1.0 Docker", check: .ranOK(#"^(?!.*--entrypoint)\s*docker (container )?run\b.*dz-multi:1\.0\s+\w+"#)),
            Mission("Build dz-multi:howdy with GREETING set to Howdy", hint: "--build-arg NAME=value sets an ARG.", solution: "docker build --build-arg GREETING=Howdy -t dz-multi:howdy .\ndocker run --rm dz-multi:howdy", check: .all([
                .ranOK(#"docker (image |buildx )?build\b.*--build-arg[ =]GREETING="#),
                .image("dz-multi:howdy"),
            ])),
            Mission("Prove dz-multi:1.0 doesn't run as root", hint: "Swap the entrypoint for id (or whoami) with --entrypoint.", solution: "docker run --rm --entrypoint id dz-multi:1.0 -u", check: .ranOK(#"docker (container )?run\b.*--entrypoint[ =]\S*(id|whoami)\b.*dz-multi"#)),
            Mission("Compare the sizes of the dz-multi images", hint: "List images, filtered to the dz-multi repository.", solution: "docker images dz-multi", check: .ranOK(#"docker (images|image (ls|list))\b.*dz-multi"#)),
        ]
    )
}
