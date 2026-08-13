---
title: Apache Mesos - Updating a Running Container Memory Limit
layout: documentation
---

# Updating a Running Container Memory Limit

## Overview

The agent operator API provides the `UPDATE_CONTAINER_MEMORY_LIMIT` call for
changing the memory allocation and hard limit of a running task container
without restarting it. The same call can increase or decrease the limit and
works with both the Mesos Containerizer and the Docker Containerizer.

The operation is local to one agent. A Mesos `ContainerID` is meaningful to
the agent that owns it, so the request must be sent directly to that agent's
`/api/v1` endpoint rather than to the master or another agent.

This feature changes runtime enforcement only. It does not change the task's
resources in the master's allocator, offers, quota accounting, or framework
state. A scheduler that requires an accounting-aware resource resize must use
an appropriate scheduler-level workflow instead.

## Requirements

The following conditions must be met:

* The target is a running, top-level task container. Nested container IDs are
  rejected.
* The request is sent to the agent that owns the container.
* The memory limit is a positive, finite number expressed in MiB.
* The agent has memory isolation enabled for its selected containerizer.
* On Linux with cgroups v2, the memory controller is available and delegated
  to the agent's hierarchy.
* If `--authenticate_http_readwrite=true` is configured, the client supplies
  credentials accepted by the agent's read/write HTTP authentication realm.

For Docker tasks, the Docker Containerizer must be enabled, for example with
`--containerizers=docker,mesos`. The exact isolation flags depend on the
deployment, but they must enable the memory controller used by the agent.

## Calling the API

Set the URL of the agent that owns the container, its HTTP credentials, the
Mesos container ID, and the new limit:

```bash
AGENT_URL='https://agent.example.com:5051'
HTTP_USER='operator'
HTTP_PASSWORD='replace-with-password'
CONTAINER_ID='848b24db-a7f7-4d38-997a-c33c2c5ae669'
MEMORY_MIB=256
```

Send the operator call:

```bash
curl --fail-with-body --silent --show-error \
  --user "${HTTP_USER}:${HTTP_PASSWORD}" \
  --request POST \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --data "$(printf \
    '{"type":"UPDATE_CONTAINER_MEMORY_LIMIT","update_container_memory_limit":{"container_id":{"value":"%s"},"memory_limit":{"value":%s}}}' \
    "${CONTAINER_ID}" "${MEMORY_MIB}")" \
  --write-out '\nHTTP %{http_code}\n' \
  "${AGENT_URL}/api/v1"
```

Add `--insecure` only for a test deployment whose certificate cannot be
verified. Production clients should validate the agent certificate.

A successful synchronous update returns an empty response body and
`200 OK`:

```text
HTTP 200
```

To test a decrease, set a lower value and repeat the same request:

```bash
MEMORY_MIB=64
```

## Finding the Correct Container and Agent

Use framework or operator state to determine the agent that runs the task and
then obtain the task's Mesos `ContainerID`. Do not use the task ID, executor
ID, Docker image ID, or Docker container ID in the request.

With the Docker Containerizer, Docker container names normally use the form
`mesos-<ContainerID>`. On the owning agent, the following diagnostic command
lists the mapping:

```bash
docker ps --no-trunc --format '{{.ID}} {{.Names}}'
```

For example:

```text
410ca96979a1... mesos-848b24db-a7f7-4d38-997a-c33c2c5ae669
```

The value required by the API is
`848b24db-a7f7-4d38-997a-c33c2c5ae669`. If the API returns `404 Not Found`
while the workload is running, first verify that `AGENT_URL` identifies the
agent that owns this container ID.

## Verifying cgroups v2 Enforcement

On the agent, find the Docker container process and its unified cgroup:

```bash
DOCKER_NAME="mesos-${CONTAINER_ID}"
PID="$(docker inspect --format '{{.State.Pid}}' "${DOCKER_NAME}")"
CGROUP="$(awk -F: '$1 == "0" {print $3}' "/proc/${PID}/cgroup")"
```

Read the kernel values:

```bash
cat "/sys/fs/cgroup${CGROUP}/memory.low"
cat "/sys/fs/cgroup${CGROUP}/memory.max"
cat "/sys/fs/cgroup${CGROUP}/memory.current"
```

For a limit of 256 MiB, both `memory.low` and `memory.max` are set to
`268435456`. For 64 MiB, both values are `67108864`.

`memory.low` protects the assigned memory under system-wide pressure, while
`memory.max` is the hard ceiling. If a new `memory.max` is below
`memory.current`, the kernel attempts to reclaim memory. If reclaim cannot
bring usage below the new ceiling, the cgroup OOM killer may terminate
processes in the container. Operators should inspect `memory.current` before
large decreases.

## Technical Flow

The request follows the standard typed agent operator API path:

1. The agent registers `/api/v1` in the read/write HTTP authentication realm.
   The endpoint accepts `POST` requests encoded as JSON or Protobuf.
2. The request is deserialized into `mesos::agent::Call`. The call type and
   payload are defined in `include/mesos/agent/agent.proto` and its v1
   counterpart.
3. Agent call validation requires the
   `update_container_memory_limit` payload, validates the `ContainerID`,
   rejects nested IDs, and requires a positive finite scalar value.
4. The handler checks the containerizer's set of running containers. An ID
   that is not present on this agent produces `404 Not Found`.
5. The handler builds a memory resource request and a `mem` resource limit in
   MiB, then invokes the generic
   `Containerizer::update(containerId, resourceRequests, resourceLimits)`
   interface.
6. The selected containerizer stores the new runtime values and applies them
   through its platform-specific backend.

### Mesos Containerizer

The Mesos Containerizer fans the update out to its isolators. With the
cgroups v2 memory controller, `MemoryControllerProcess::update` converts MiB
to bytes, clamps the result to the controller's minimum, and writes the value
to both `memory.low` and `memory.max`. The hard limit is written for increases
and decreases.

### Docker Containerizer

The Docker Containerizer inspects the Docker container when necessary to
obtain its host PID. Under cgroups v2 it resolves the unified cgroup from that
PID, rejects the hierarchy root as a safety check, and writes `memory.low` and
`memory.max` in the resolved cgroup. This supports systemd scope paths and
other Docker cgroup layouts without deriving a path from the Mesos container
ID.

Under cgroups v1, the Docker backend writes
`memory.soft_limit_in_bytes` and `memory.limit_in_bytes`. Both increases and
decreases of the hard limit are applied there as well.

## Scope and Durability

The update is a runtime override on one agent. It deliberately does not
modify master-side resource accounting. In particular:

* the allocator still accounts for the memory originally assigned to the
  task;
* the framework's task resources are not rewritten;
* no new resources are offered or consumed by this call; and
* the override is not a checkpointed, scheduler-visible resize contract.

Later lifecycle processing, recovery, re-registration, or another resource
update can recompute and reapply the task's normal limits. Clients that need
the override for the lifetime of a task should monitor it and be prepared to
reapply it after agent recovery. Do not rely on the override surviving an
agent restart.

## Errors and Troubleshooting

* `400 Bad Request`: Check that the payload field is present, the ID is a
  valid top-level `ContainerID`, and the MiB value is positive and finite.
* `401 Unauthorized`: Supply credentials for the agent's read/write HTTP
  authentication realm.
* `404 Not Found`: Send the request to the agent that owns the container and
  verify that the container is still running.
* `500 Internal Server Error`: Inspect the agent log for container inspection,
  cgroup path, controller delegation, or control-file write failures.

Agent logs include the principal, container ID, requested MiB value, and the
cgroup control files updated by the backend. These messages are useful for
distinguishing request-routing failures from kernel enforcement failures.
