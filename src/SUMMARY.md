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

# Networking

- [Networking Overview](networking.md)
  - [Networking in Detail](networking-for-mesos-managed-containers.md)
  - [Container Network Interface (CNI)](cni.md)
  - [Port Mapping Isolator](isolators/network-port-mapping.md)

# Storage

- [Multiple Disks for how to allow tasks to use multiple isolated disk resources.](multiple-disk.md)
- [Persistent Volume for how to allow tasks to access persistent storage resources.](persistent-volume.md)
- [Container Storage Interface (CSI) Support](csi.md)

# Scheduler and Executor Development

- [Running Workloads in Mesos explains how a scheduler can specify and run tasks.](running-workloads.md)
- [Framework Development Guide describes how to build applications on top of Mesos.](app-framework-development-guide.md)
- [Guide for Designing Highly Available Mesos Frameworks](high-availability-framework-guide.md)
- [Reconciliation for ensuring a framework’s state remains eventually consistent in the face of failures.](reconciliation.md)
- [Task State Reasons describes how task state reasons are used in Mesos.](task-state-reasons.md)
- [Task Health Checking](health-checks.md)
- [v1 Scheduler HTTP API for communication between schedulers and the Mesos master.](scheduler-http-api.md)
- [v1 Executor HTTP API describes the new HTTP API for communication between executors and the Mesos agent.](executor-http-api.md)





