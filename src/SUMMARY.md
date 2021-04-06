# Summary

# Fundamentals

- [Mesos Architecture providing an overview of Mesos concepts](architecture.md)
- [Video and Slides of Mesos Presentations](presentations.md)
- [Mesos Release and Support Policy](versioning.md)

# Build / Installation

- [Building for basic instructions on compiling and installing Mesos.](building.md)
- [Binary Packages for how to use Mesos binary packages.](binary-packages.md)
- [Configuration for build configuration options.](configuration.md)
- [CMake for details about using the new CMake build system.](cmake.md)
- [Windows Support for the state of Windows support in Mesos.](windows.md)

# Administration

- [Configuration for command-line arguments.](configuration.md)
- [High Availability Master Setup](high-availability.md)
  - [Replicated Log for information on the Mesos replicated log.](replicated-log-internals.md)
- [Fault Tolerant Agent Setup](agent-recovery.md)
- [Framework Rate Limiting](framework-rate-limiting.md)
- [Maintenance for performing maintenance on a Mesos cluster.](maintenance.md)
- [Upgrades for upgrading a Mesos cluster.](upgrades.md)
- [Downgrades for downgrading a Mesos cluster.](downgrades.md)
- [Logging](logging.md)
- [Monitoring / Metrics](monitoring.md)
- [Debugging using the new CLI](cli.md)
- [Operational Guide](operational-guide.md)
- [Fetcher Cache Configuration](fetcher.md)
- [Fault Domains](fault-domains.md)
- [Performance Profiling for debugging performance issues in Mesos.](performance-profiling.md)
- [Memory Profiling for debugging potential memory leaks in Mesos.](memory-profiling.md)

# Resource Management

- [Attributes and Resources for how to describe the agents that comprise a cluster.](attributes-resources.md)
- [Using Resource Roles](roles.md)
  - [Resource Role Weights for fair sharing.](weights.md)
  - [Resource Role Quota for how to configure Mesos to provide guaranteed resource allocations for use by a role.](quota.md)
  - [Reservations for how operators and frameworks can reserve resources on individual agents for use by a role.](reservation.md)
  - [Shared Resources for how to share persistent volumes between tasks managed by different executors on the same agent.](shared-resources.md)
- [Oversubscription for how to configure Mesos to take advantage of unused resources to launch “best-effort” tasks.](oversubscription.md)

# Security

- [Authentication](authentication.md)
- [Authorization](authorization.md)
- [SSL](ssl.md)
- [Secrets for managing secrets within Mesos.](secrets.md)

# Containerization

- [Containerizer Overview](containerizers.md)
  - [Containerizer Internals for implementation details of containerizers.](containerizer-internals.md)
  - [Docker Containerizer for launching a Docker image as a Task, or as an Executor.](docker-containerizer.md)
  - [Mesos Containerizer default containerizer, supports both Linux and POSIX systems.](mesos-containerizer.md)
    - [Container Images for supporting container images in Mesos containerizer.](container-image.md)
    - [Docker Volume Support](./isolators/docker-volume.md)
    - [Nvidia GPU Support for how to run Mesos with Nvidia GPU support.](gpu-support.md)
- [Container Sandboxes](sandbox.md)
- [Container Volumes](container-volume.md)
- [Nested Container and Task Group (Pod)](nested-container-and-task-group.md)
- [Standalone Containers](standalone-containers.md)
