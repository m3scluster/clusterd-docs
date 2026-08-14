# Task exec HTTP endpoint reference

`mesos task exec` crosses three HTTP transports:

* the Mesos master resolves the task and owning agent;
* the Mesos agent creates and manages the nested exec session; and
* for Docker-containerized tasks, `mesos-docker-exec` talks to the Docker
  Engine API through the agent's configured `--docker_socket` resource.

The master and agent requests use their configured HTTP or HTTPS URLs. The
Docker requests use HTTP framing over a Unix socket or compatible proxy socket;
they are not sent to the master or agent HTTP port.

## Endpoint summary

| Phase | HTTP request | Call or purpose |
|---|---|---|
| Task lookup | `GET <master>/tasks?task_id=<task-id>` | Find the running task and root container |
| Agent lookup | `GET <master>/slaves` | Resolve the task's agent address |
| Session launch and output | `POST <agent>/api/v1` | `LAUNCH_NESTED_CONTAINER_SESSION` |
| Interactive input | `POST <agent>/api/v1` | `ATTACH_CONTAINER_INPUT` |
| Session wait | `POST <agent>/api/v1` | `WAIT_CONTAINER` |
| Docker create | `POST /containers/{container}/exec` | Create a Docker exec instance |
| Docker start | `POST /exec/{id}/start` | Start and stream the Docker exec instance |
| Docker inspect | `GET /exec/{id}/json` | Retrieve the Docker exec exit code |

The Docker calls are made only when the root task uses the Docker containerizer.
Mesos-containerized tasks use the same master and agent calls but remain on the
Mesos containerizer's nested-session path.

## Task lookup

The CLI requests the master's legacy task endpoint with a task ID filter:

```http
GET /tasks?task_id=synthetic-task-1 HTTP/1.1
Host: master.example.test:5050
Accept: application/json
```

The response contains a top-level `tasks` array. The CLI selects an entry whose
`id` exactly matches the requested ID and whose `state` is `TASK_RUNNING`. It
uses the entry's `slave_id` to find the agent and reads the root container ID
from `statuses[].container_status.container_id`.

This is the legacy master `/tasks` endpoint, not the `GET_TASKS` call on the
[Operator HTTP API](operator-http-api.md#get_tasks).

## Agent lookup

The CLI requests the master's legacy agent-list endpoint:

```http
GET /slaves HTTP/1.1
Host: master.example.test:5050
Accept: application/json
```

The response contains a top-level `slaves` array. The CLI matches the task's
`slave_id` against each entry's `id` and extracts the agent address from its
`pid` field.

This is the legacy master `/slaves` endpoint. The corresponding modern master
operator call is documented under
[`GET_AGENTS`](operator-http-api.md#get_agents), but `task exec` currently uses
`/slaves`.

## Session launch and output

The CLI sends a JSON call to the owning agent:

```http
POST /api/v1 HTTP/1.1
Host: agent.example.test:5051
Content-Type: application/json
Accept: application/recordio
Message-Accept: application/json
```

The `launch_nested_container_session` body contains a fresh nested container ID
whose parent is the task's root container ID. Its `command` contains the command
value, an argument array beginning with the command as `argv[0]`, and
`"shell": false`. With `-t`, the request also contains a `MESOS` container
object with `tty_info`.

The response is a RecordIO stream of `DATA` messages for standard output and
standard error. `task exec` consumes output directly from this launch response;
it does not make a separate `ATTACH_CONTAINER_OUTPUT` request.

See
[`LAUNCH_NESTED_CONTAINER_SESSION`](operator-http-api.md#launch_nested_container_session)
for the complete request and RecordIO response format.

## Interactive input

When `-i` is present, the CLI opens an additional request to the owning agent:

```http
POST /api/v1 HTTP/1.1
Host: agent.example.test:5051
Content-Type: application/recordio
Message-Content-Type: application/json
Accept: application/json
Transfer-Encoding: chunked
```

The first RecordIO record has type `CONTAINER_ID` and identifies the nested
session. Following records have type `PROCESS_IO`; they carry `STDIN` data or
heartbeat control messages. An empty standard-input data message indicates
end-of-file.

The CLI first probes the input attachment with the initial container-ID record,
then establishes the persistent RecordIO input stream on the same endpoint.
Non-interactive exec calls omit this input path.

See [`ATTACH_CONTAINER_INPUT`](operator-http-api.md#attach_container_input) for
the complete RecordIO message format. The separately documented
[`ATTACH_CONTAINER_OUTPUT`](operator-http-api.md#attach_container_output) call
is used by `mesos task attach`, not by the `task exec` launch path.

## Session wait

After the launch stream ends, the CLI waits for the nested session through a
JSON agent call:

```http
POST /api/v1 HTTP/1.1
Host: agent.example.test:5051
Content-Type: application/json
Accept: application/json
```

A synthetic request has this shape:

```json
{
  "type": "WAIT_CONTAINER",
  "wait_container": {
    "container_id": {
      "parent": {"value": "synthetic-container-1"},
      "value": "synthetic-session-1"
    }
  }
}
```

`WAIT_CONTAINER` supports standalone and nested containers. It returns HTTP 200
when the container termination is available and HTTP 404 when the container
cannot be found. The JSON response has type `WAIT_CONTAINER`; its
`wait_container` object can include `exit_status`, `state`, `reason`,
`limitation`, and `message`. `task exec` reads `exit_status` and converts the
wait status to its command exit code.

`WAIT_CONTAINER` is distinct from the deprecated
[`WAIT_NESTED_CONTAINER`](operator-http-api.md#wait_nested_container) call.

## Docker create

For a Docker task, the agent starts `mesos-docker-exec`. The helper sends the
following request through `--docker_socket`:

```http
POST /containers/{container}/exec HTTP/1.1
Host: localhost
Content-Type: application/json
```

The JSON payload has this shape:

```json
{
  "AttachStdin": true,
  "AttachStdout": true,
  "AttachStderr": true,
  "Tty": true,
  "Cmd": ["/bin/sh"],
  "Env": ["SYNTHETIC_MODE=example"],
  "User": "synthetic-user"
}
```

`Cmd` is the argument vector derived from the Mesos `CommandInfo`. `Env` is an
array of `NAME=value` strings. `User` is included only when a user was supplied.
`Tty` reflects the CLI's `-t` option. The helper requires a 2xx response and
reads the Docker exec ID from its JSON `Id` field.

## Docker start

The helper starts the exec instance through the same Docker socket:

```http
POST /exec/{id}/start HTTP/1.1
Host: localhost
Content-Type: application/json
```

```json
{
  "Detach": false,
  "Tty": true
}
```

The helper deliberately does not request an HTTP connection upgrade. It accepts
HTTP 200 or HTTP 101 from the daemon or proxy and uses the response remainder
and socket as the bidirectional exec stream. For a TTY session, the input side
remains open until the exec instance exits so a proxy cannot discard pending
terminal output after an early write-side close.

## Docker inspect

When the Docker stream closes, the helper retrieves the exit status:

```http
GET /exec/{id}/json HTTP/1.1
Host: localhost
Accept: application/json
```

The helper requires HTTP 200 and a JSON response. Docker can briefly report a
null or absent `ExitCode` after the stream closes, so the helper retries until a
numeric value is available. It makes at most 500 attempts with 10 milliseconds
between attempts and returns the resulting `ExitCode` as its process status.

## Access control

Master and agent calls use the CLI's configured authentication and TLS settings
and remain subject to Mesos authorization. The Docker calls use the agent's
local `--docker_socket` resource. Access to that resource grants extensive
control over the Docker daemon and host, so its filesystem permissions and any
proxy access must be restricted.
