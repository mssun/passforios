#!/bin/bash

# Starts local SSH and HTTPS git servers for the transport tests, which are the
# only tests that exercise libssh2 and the TLS stream of libgit2. Everything
# lives in .git-servers and is thrown away by `stop`.
#
#   ./scripts/git_servers.sh start
#   set -a; source .git-servers/env; set +a
#   bundle exec fastlane test
#   ./scripts/git_servers.sh stop
#
# The tests pin the certificate of the HTTPS server rather than adding its
# authority to the trusted roots of the simulator: simctl reports that it added
# it and on a runner the trust does not take effect. Validation against the
# trust store of the system is therefore not what these tests cover.

set -euo pipefail

SSH_PORT="${GIT_SERVERS_SSH_PORT:-47022}"
HTTPS_PORT="${GIT_SERVERS_HTTPS_PORT:-47443}"
DEVICE="${GIT_SERVERS_DEVICE:-iPhone 16}"

HTTP_USER="testuser"
HTTP_PASSWORD="testpassword"

STATE_PATH="$(pwd)/.git-servers"

log() { echo "[git_servers] $*" >&2; }

# Only processes this script started are killed. Matching by port alone would
# take down whatever else a developer happens to be running on it, and matching
# by name would miss a stale server that then answers with an old certificate.
stop() {
  local pid_file pid
  for pid_file in "$STATE_PATH"/*.pid; do
    [ -f "$pid_file" ] || continue
    pid="$(cat "$pid_file")"
    if [ -n "$pid" ]; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  done
  rm -rf "$STATE_PATH"
  log "stopped"
}

port_in_use() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN -t >/dev/null 2>&1
}

require_free_port() {
  local port="$1" name="$2"
  if port_in_use "$port"; then
    log "port $port is already in use, so the $name server cannot start"
    log "stop whatever is holding it, or set GIT_SERVERS_${name}_PORT to another one"
    return 1
  fi
}

wait_for_port() {
  local port="$1" name="$2" pid="$3"
  for _ in $(seq 1 100); do
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
      return 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      log "$name exited before it listened on port $port"
      sed 's/^/    /' "$STATE_PATH/$name.log" >&2 2>/dev/null || log "(no output)"
      return 1
    fi
    sleep 0.2
  done
  log "$name did not come up on port $port within 20s"
  sed 's/^/    /' "$STATE_PATH/$name.log" >&2 2>/dev/null || log "(no output)"
  return 1
}

seed_repository() {
  local repository="$1" work="$STATE_PATH/seed"
  git init -q --bare "$repository"
  git -C "$repository" config http.receivepack true
  rm -rf "$work"
  git init -q "$work"
  echo "seeded" > "$work/README"
  git -C "$work" add README
  git -C "$work" -c user.email=test@example.com -c user.name=Test commit -qm "seed"
  git -C "$work" push -q "$repository" HEAD:refs/heads/master
  rm -rf "$work"
}

write_certificates() {
  # A certificate authority without keyUsage is refused by strict verifiers,
  # SecureTransport among them, with an error that names something else.
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$STATE_PATH/ca.key" -out "$STATE_PATH/ca.pem" \
    -days 30 -subj "/CN=Pass Transport Test CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
  openssl req -newkey rsa:2048 -nodes -keyout "$STATE_PATH/leaf.key" -out "$STATE_PATH/leaf.csr" \
    -subj "/CN=127.0.0.1" 2>/dev/null
  openssl x509 -req -in "$STATE_PATH/leaf.csr" -CA "$STATE_PATH/ca.pem" -CAkey "$STATE_PATH/ca.key" \
    -CAcreateserial -out "$STATE_PATH/leaf.pem" -days 30 -extfile <(printf \
      "subjectAltName=IP:127.0.0.1\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\n") 2>/dev/null
  cat "$STATE_PATH/leaf.pem" "$STATE_PATH/leaf.key" > "$STATE_PATH/leaf-chain.pem"
}

start_ssh_server() {
  ssh-keygen -q -t ed25519 -f "$STATE_PATH/host_key" -N ""
  ssh-keygen -q -t ed25519 -f "$STATE_PATH/client_key" -N ""
  cp "$STATE_PATH/client_key.pub" "$STATE_PATH/authorized_keys"
  chmod 600 "$STATE_PATH/authorized_keys"

  cat > "$STATE_PATH/sshd_config" <<EOF
Port $SSH_PORT
ListenAddress 127.0.0.1
HostKey $STATE_PATH/host_key
PidFile $STATE_PATH/sshd.pid
AuthorizedKeysFile $STATE_PATH/authorized_keys
StrictModes no
PasswordAuthentication no
UsePAM no
EOF

  /usr/sbin/sshd -f "$STATE_PATH/sshd_config" -D -e > "$STATE_PATH/sshd.log" 2>&1 &
  echo $! > "$STATE_PATH/sshd.started.pid"
  wait_for_port "$SSH_PORT" sshd "$!"
}

start_https_server() {
  # git-http-backend is run as a subprocess and its output written back through
  # the TLS socket. CGIHTTPRequestHandler cannot be used: it forks and writes
  # plain bytes to the descriptor, which corrupts an encrypted connection.
  cat > "$STATE_PATH/https_server.py" <<'PYTHON'
import base64, os, socketserver, ssl, subprocess, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ROOT, PORT, USER, PASSWORD = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
BACKEND = subprocess.run(["git", "--exec-path"], capture_output=True, text=True).stdout.strip() + "/git-http-backend"
EXPECTED = "Basic " + base64.b64encode(f"{USER}:{PASSWORD}".encode()).decode()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def read_body(self):
        # libgit2 sends the body of a push chunked, so Content-Length alone
        # would hand git-http-backend an empty pack.
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            chunks = []
            while True:
                line = self.rfile.readline()
                try:
                    size = int(line.split(b";")[0], 16)
                except ValueError:
                    # A closed connection or a split header, rather than a size.
                    # Returning what arrived beats an exception that kills the
                    # thread and shows up as an unexplained reset.
                    break
                if size == 0:
                    self.rfile.readline()
                    break
                chunks.append(self.rfile.read(size))
                self.rfile.read(2)
            return b"".join(chunks)
        return self.rfile.read(int(self.headers.get("Content-Length") or 0))

    def handle_request(self, method):
        # Always drain the body: leaving it unread desynchronises the connection,
        # and the retry that follows a 401 then fails to be understood.
        body = self.read_body()
        if self.headers.get("Authorization") != EXPECTED:
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="pass"')
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        parsed = urlparse(self.path)
        environment = dict(
            os.environ,
            GIT_PROJECT_ROOT=ROOT,
            GIT_HTTP_EXPORT_ALL="1",
            REQUEST_METHOD=method,
            PATH_INFO=parsed.path,
            QUERY_STRING=parsed.query,
            CONTENT_TYPE=self.headers.get("Content-Type", ""),
            CONTENT_LENGTH=str(len(body)),
            REMOTE_USER=USER,
            REMOTE_ADDR=self.client_address[0],
        )
        result = subprocess.run([BACKEND], input=body, capture_output=True, env=environment)
        head, _, payload = result.stdout.partition(b"\r\n\r\n")

        # git-http-backend reports failures through a CGI Status header. Sending
        # 200 regardless would deliver its error text as if it were a pack.
        status = 200
        headers = []
        for line in head.split(b"\r\n"):
            if b":" not in line:
                continue
            key, _, value = line.partition(b":")
            if key.strip().lower() == b"status":
                status = int(value.strip().split()[0])
            else:
                headers.append((key.decode(), value.strip().decode()))

        self.send_response(status)
        for key, value in headers:
            self.send_header(key, value)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        self.handle_request("GET")

    def do_POST(self):
        self.handle_request("POST")

    def log_message(self, *args):
        pass


class Server(ThreadingHTTPServer):
    def server_bind(self):
        # HTTPServer resolves the host name between binding and listening, and a
        # reverse lookup that is slow to answer leaves the port bound but not
        # yet accepting, which looks exactly like a server that never started.
        socketserver.TCPServer.server_bind(self)
        self.server_name = "127.0.0.1"
        self.server_port = self.server_address[1]


context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(os.path.join(ROOT, "leaf-chain.pem"))
server = Server(("127.0.0.1", PORT), Handler)
server.socket = context.wrap_socket(server.socket, server_side=True)
server.serve_forever()
PYTHON

  python3 "$STATE_PATH/https_server.py" "$STATE_PATH" "$HTTPS_PORT" "$HTTP_USER" "$HTTP_PASSWORD" \
    > "$STATE_PATH/https.log" 2>&1 &
  echo $! > "$STATE_PATH/https.started.pid"
  wait_for_port "$HTTPS_PORT" https "$!"
}

record_device() {
  local selected
  # Only to run the tests somewhere predictable. The certificate is pinned by
  # the tests themselves, so nothing depends on the trust store of the device.
  selected="$(xcrun simctl list devices available --json | python3 -c "
import json, re, sys

name, preferred = sys.argv[1], sys.argv[2]
candidates = []
for runtime, devices in json.load(sys.stdin)['devices'].items():
    version = re.search(r'iOS-([0-9]+)-([0-9]+)', runtime)
    if not version:
        continue
    major, minor = int(version.group(1)), int(version.group(2))
    for device in devices:
        if device['name'] == name:
            candidates.append((major == int(preferred), major, minor, device['udid']))
if candidates:
    match = max(candidates)
    print(f'{match[3]} iOS-{match[1]}.{match[2]}')
" "$DEVICE" "${GIT_SERVERS_IOS_MAJOR:-18}")"

  local udid="${selected%% *}"
  if [ -z "$udid" ]; then
    log "no simulator named '$DEVICE'; set GIT_SERVERS_DEVICE to one that exists"
    return 1
  fi
  echo "$udid" > "$STATE_PATH/device_udid"
  log "tests will run on $DEVICE ${selected##* } ($udid)"
}

start() {
  case "$STATE_PATH" in
    *[!A-Za-z0-9/._-]*)
      log "the path $STATE_PATH contains characters that do not survive being put in a URL"
      log "check the repository out somewhere without spaces or move it"
      exit 1
      ;;
  esac
  stop
  mkdir -p "$STATE_PATH"
  require_free_port "$SSH_PORT" SSH
  require_free_port "$HTTPS_PORT" HTTPS
  write_certificates
  seed_repository "$STATE_PATH/ssh-repo.git"
  seed_repository "$STATE_PATH/repo.git"
  start_ssh_server
  start_https_server
  record_device

  # Consumed by the tests. xcodebuild passes variables with this prefix into the
  # test process with the prefix removed.
  cat > "$STATE_PATH/env" <<EOF
GIT_SERVERS_DEVICE_UDID=$(cat "$STATE_PATH/device_udid")
TEST_RUNNER_GIT_SSH_URL=ssh://$(whoami)@127.0.0.1:$SSH_PORT$STATE_PATH/ssh-repo.git
TEST_RUNNER_GIT_SSH_PRIVATE_KEY_BASE64=$(base64 < "$STATE_PATH/client_key" | tr -d '\n')
TEST_RUNNER_GIT_SSH_USER=$(whoami)
TEST_RUNNER_GIT_HTTPS_URL=https://127.0.0.1:$HTTPS_PORT/repo.git
TEST_RUNNER_GIT_HTTPS_USER=$HTTP_USER
TEST_RUNNER_GIT_HTTPS_CERTIFICATE_BASE64=$(openssl x509 -in "$STATE_PATH/leaf.pem" -outform DER | base64 | tr -d '\n')
TEST_RUNNER_GIT_HTTPS_PASSWORD=$HTTP_PASSWORD
EOF
  log "started; source $STATE_PATH/env before running the tests"
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  *) echo "usage: $0 {start|stop}" >&2; exit 2 ;;
esac
