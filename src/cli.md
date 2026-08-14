# The Mesos CLI

The Mesos command-line interface (CLI) is a Python 3 application that provides
the default Mesos commands and supports additional custom plugins. Two task
commands are useful when inspecting running containers:

* `mesos task exec` starts a new command in a running task's container.
* `mesos task attach` attaches the local terminal to the standard streams of a
  running task.

`task exec` supports tasks launched by both the Mesos and Docker
containerizers. The Docker path is described in more detail in the
[Docker containerizer documentation](docker-containerizer.md#interactive-task-exec).

## Building the CLI

The Mesos CLI can be built with the Mesos
[Autotools](configuration/autotools.md) or
[CMake](configuration/cmake.md) options. Consult the linked configuration
pages when selecting Python 3 for the build. The resulting executable is named
`mesos`.

## Using the CLI from the source tree

The CLI can also be used without building the rest of Mesos. Bootstrap and
activate its virtual environment as follows:

```console
$ cd src/python/cli_new/
$ PYTHON=python3 ./bootstrap
$ source activate
$ mesos
```

Run `mesos-cli-tests` in the activated environment to execute the CLI
integration tests.

## Configuring the CLI

The CLI reads `~/.mesos/config.toml` by default. The configuration identifies
the Mesos master and lists optional plugin directories. Each plugin path must
be absolute.

```toml
plugins = [
  "/opt/mesos-cli/plugins/synthetic-example"
]

[master]
  address = "master.example.test:5050"
```

The `master` table contains either an `address` or a ZooKeeper configuration,
but not both. A ZooKeeper configuration has an `addresses` array and a `path`:

```toml
[master]
  [master.zookeeper]
    addresses = [
      "zk-1.example.test:2181",
      "zk-2.example.test:2181"
    ]
    path = "/mesos"
```

## Executing commands in running tasks

Use `task exec` with a Mesos task ID. The CLI resolves the task to its owning
agent and root container before creating a new nested debug session.

```text
mesos task exec [-i|--interactive] [-t|--tty] \
    <task-id> <command> [<args>...]
```

The options have independent meanings:

* `-i`, `--interactive` attaches local standard input to the new process.
* `-t`, `--tty` requests a terminal for the new process.

For a non-interactive command, omit both options:

```console
$ mesos task exec synthetic-task-1 /usr/bin/id
```

To open an interactive shell with a terminal, combine both options:

```console
$ mesos task exec -it synthetic-task-1 /bin/sh
```

The command and its arguments are passed as an argument vector, not joined into
a shell command string. Invoke a shell explicitly when shell parsing is needed:

```console
$ mesos task exec synthetic-task-1 /bin/sh -c 'printf "synthetic output\n"'
```

When the command finishes, `task exec` returns the status reported for the
nested session.

### Execution flow

The Docker and Mesos containerizers share the CLI and agent API flow:

1. The CLI resolves the task ID and owning agent through the master's legacy
   `/tasks` and `/slaves` endpoints.
2. It creates a fresh nested container ID and requests a debug-class session
   with `LAUNCH_NESTED_CONTAINER_SESSION`.
3. Standard output and error arrive in the launch response. With `-i`, a
   separate `ATTACH_CONTAINER_INPUT` stream carries standard input.
4. The CLI uses `WAIT_CONTAINER` to obtain the session's final status.

### HTTP endpoint overview

The complete request path is listed below. Docker calls apply only to tasks
launched by the Docker containerizer. Each row links to request headers,
payloads, response handling, and transport-specific behavior.

| Phase | HTTP request | Call or purpose | Details |
|---|---|---|---|
| Task lookup | `GET <master>/tasks?task_id=<task-id>` | Find the running task and root container | [Task lookup](task-exec-http-api.md#task-lookup) |
| Agent lookup | `GET <master>/slaves` | Resolve the task's agent address | [Agent lookup](task-exec-http-api.md#agent-lookup) |
| Session launch and output | `POST <agent>/api/v1` | `LAUNCH_NESTED_CONTAINER_SESSION` | [Launch and output](task-exec-http-api.md#session-launch-and-output) |
| Interactive input | `POST <agent>/api/v1` | `ATTACH_CONTAINER_INPUT`, only with `-i` | [Interactive input](task-exec-http-api.md#interactive-input) |
| Session wait | `POST <agent>/api/v1` | `WAIT_CONTAINER` | [Session wait](task-exec-http-api.md#session-wait) |
| Docker create | `POST /containers/{container}/exec` | Create a Docker exec instance | [Docker create](task-exec-http-api.md#docker-create) |
| Docker start | `POST /exec/{id}/start` | Start and stream the Docker exec instance | [Docker start](task-exec-http-api.md#docker-start) |
| Docker inspect | `GET /exec/{id}/json` | Retrieve the Docker exec exit code | [Docker inspect](task-exec-http-api.md#docker-inspect) |

See the [task exec HTTP endpoint reference](task-exec-http-api.md) for the
end-to-end transport boundaries and full details.

For a Docker-containerized task, the agent's Docker containerizer launches the
`mesos-docker-exec` helper. The helper does not invoke `docker exec`. It uses
the Docker Engine API through the resource configured by `--docker_socket`.

The Docker request carries the command argument vector, environment, optional
user, standard-stream attachments, and TTY choice. Mesos `CommandInfo.arguments`
already contains `argv[0]` and is forwarded directly. `CommandInfo.value` is
used only when the argument list is empty.

### Prerequisites and security

Before using `task exec`, verify that:

* the task is running and visible through the master configured for the CLI;
* the agent is reachable and uses the containerizer that launched the task;
* authentication and authorization permit the required master and agent API
  operations;
* for Docker tasks, the configured Docker Engine API resource is reachable and
  compatible; and
* `mesos-docker-exec` is installed in the agent's `launcher_dir`.

On Unix, `--docker_socket` defaults to `/var/run/docker.sock`. A deployment can
instead provide a compatible proxy socket, for example:

```text
--docker_socket=/run/mesos/docker.sock
```

Access to a Docker Engine socket is highly privileged. Restrict its filesystem
permissions, do not expose it to untrusted networks, and limit `task exec` to
authorized operators.

### TTY and control characters

When `-t` is used, the CLI requires a local terminal. It switches the local
terminal to raw mode for the session and restores the original settings when
the session ends. The `--tty` option is not supported on Windows.

For Docker TTY sessions, `mesos-docker-exec` also puts its outer Mesos terminal
in raw mode. Control bytes can then reach the Docker terminal instead of being
consumed by the outer terminal. In particular, `Ctrl-C`, `Ctrl-D`, and `Ctrl-Z`
are delivered to the remote terminal, where the remote terminal and process
determine their effect.

The sequence `Ctrl-p Ctrl-q` is reserved by the CLI for detaching and is not
forwarded to the remote process.

Some interactive programs query the terminal cursor position. The Docker exec
stream recognizes these queries even when a query spans multiple network
chunks and returns a cursor-position report so the program can continue.

### Docker proxy compatibility

The Docker helper deliberately uses normal HTTP streaming instead of requesting
an upgraded or hijacked connection. It accepts both HTTP 200 and HTTP 101 start
responses for compatibility with Docker daemons and older socket proxies.

The input side remains open until the Docker exec process exits. Proxies used
for `--docker_socket` must preserve the bidirectional stream; implementations
that discard pending terminal output after an early write-side close are not
compatible with interactive sessions.

### Troubleshooting

If `task exec` fails, check the following in order:

1. **Task resolution:** confirm that the exact task ID is running and visible
   through the configured master.
2. **Agent access:** confirm connectivity, authentication, and authorization
   for the owning agent's API.
3. **Docker resource:** for Docker tasks, verify `--docker_socket`, its
   permissions, and Docker Engine API compatibility.
4. **Helper installation:** verify that `mesos-docker-exec` is present in
   `launcher_dir` on the agent.
5. **Local terminal:** use `-t` only from a terminal and combine it with `-i`
   for an interactive shell.
6. **Control characters:** remember that `Ctrl-p Ctrl-q` is consumed locally;
   other control bytes require a TTY if they are expected to act as terminal
   controls in the container.
7. **Proxy streaming:** if output is truncated or a session stalls, inspect the
   Docker socket proxy for broken bidirectional streaming or premature
   half-closes.