# Browser Access with CORS

The ClusterD WebUI can make browser requests to HTTP endpoints on Mesos® masters
and agents. When the WebUI and the target endpoint do not have the same origin,
the browser requires Cross-Origin Resource Sharing (CORS) response headers.

CORS access is disabled unless an origin is explicitly configured. Configure the
`--http_cors_allowed_origins` flag on every master and every agent that the WebUI
must access.


## Configure Allowed Origins

The flag accepts a comma-separated list of exact origins. Each origin consists of
the scheme, hostname, and Mesos® master port. It does not contain a path.

For example, if the WebUI can be loaded from two TLS-enabled masters, configure:

    --http_cors_allowed_origins=https://master1.example:5050,https://master2.example:5050

Use `http` instead of `https` when TLS is not enabled. The configured value must
exactly match the browser's `Origin` header. Scheme, hostname, and port are all
significant, so `https://master1.example:5050` does not match
`http://master1.example:5050`, `https://master1.example`, or an IP address.

In a flag-per-file installation, write the same comma-separated list to both of
the following files on the applicable hosts:

    /etc/mesos-master/http_cors_allowed_origins
    /etc/mesos-agent/http_cors_allowed_origins

For example, both files can contain:

    https://master1.example:5050,https://master2.example:5050

Apply the configuration according to the deployment's normal process restart or
reload procedure.

**NOTE:** ZooKeeper ensemble addresses are not browser origins. Their ports are
ZooKeeper ports rather than Mesos® master HTTP ports. Specify every complete
WebUI origin explicitly instead of copying or deriving the value from a
ZooKeeper URL.


## Response Behavior

For a request whose `Origin` exactly matches a configured value, the master or
agent returns these CORS response headers:

    Access-Control-Allow-Origin: https://master1.example:5050
    Access-Control-Allow-Credentials: true
    Access-Control-Expose-Headers: Mesos-Stream-Id
    Vary: Origin

`Access-Control-Allow-Origin` contains only the matching request origin. It is
never a list and is not set to `*`. Responses to requests from an unconfigured
origin, or requests without an `Origin` header, do not receive CORS access
headers. If a response already has a `Vary` header, `Origin` is added without
removing the existing values.

The CORS handling applies to master and agent HTTP routes, including the
operator API and other endpoints served by their libprocess processes.


## Preflight Requests

A browser sends an `OPTIONS` preflight request before requests that use headers
such as `Authorization` or a JSON `Content-Type`. For an allowed origin and a
requested `GET` or `POST` method, the master or agent responds without executing
the requested API operation and includes:

    Access-Control-Allow-Methods: GET, POST, OPTIONS
    Access-Control-Allow-Headers: Authorization, Content-Type, Accept, Mesos-Stream-Id

The browser then decides whether it may send the actual request.


## Authentication and Security

CORS controls which browser origins may read responses. It is not an
authentication or authorization mechanism. Actual master and agent requests
remain subject to the configured HTTP authenticators, credentials, ACLs, and
endpoint authorization rules.

Only add trusted WebUI origins. Do not treat an origin allowlist as permission to
expose master or agent endpoints to an untrusted network. Use TLS for the WebUI
and Mesos® endpoints when credentials or other sensitive data cross the network.
See [Authentication](authentication.md) and [SSL in Mesos](ssl.md) for the
corresponding security configuration.


## Troubleshooting

If the browser still reports a CORS error, inspect the request's `Origin` header
and verify all of the following:

* The origin is present in `--http_cors_allowed_origins` on the target process.
* The scheme is correct for the WebUI (`http` or `https`).
* The hostname is identical; DNS names, short names, and IP addresses are
  different origins.
* The port is the WebUI's Mesos® master HTTP port, even when the target request is
  sent to an agent port.
* The value contains no path or trailing slash.
* The changed configuration has been applied to every master and agent that the
  WebUI can contact.
* The actual request still satisfies authentication and authorization. A failed
  credential or ACL check is not fixed by adding an origin.
