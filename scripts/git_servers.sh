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
# The tests pin the certificate of the HTTPS server rather than adding it to the
# trusted roots of the simulator: simctl reports that it added it and on a
# runner the trust does not take effect. Validation against the trust store of
# the system is therefore not what these tests cover.
#
# HTTPS is served by the Apache that ships with macOS, SSH by its sshd.

set -euo pipefail

SSH_PORT="${GIT_SERVERS_SSH_PORT:-47022}"
HTTPS_PORT="${GIT_SERVERS_HTTPS_PORT:-47443}"

HTTP_USER="testuser"
HTTP_PASSWORD="testpassword"

STATE_PATH="$(pwd)/.git-servers"

log() { echo "[git_servers] $*" >&2; }

# Only processes this script started are killed. Matching by port alone would
# take down whatever else a developer happens to be running on it, and matching
# by name would miss a stale server that then answers with an old certificate.
port_in_use() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN -t >/dev/null 2>&1
}

# A recorded number is not proof: process ids are reused, and a stale file from
# an interrupted run can name something else by the time it is read. The match
# is done with a case statement rather than grep, because a grep would carry
# the very path it looks for in its own arguments and so match itself.
is_our_server() {
  local command
  command="$(ps -o command= -p "$1" 2>/dev/null)" || return 1
  case "$command" in
  *"$STATE_PATH"*) return 0 ;;
  *) return 1 ;;
  esac
}

stop() {
  local pid_file pid pids=""
  for pid_file in "$STATE_PATH"/*.pid; do
    [ -f "$pid_file" ] || continue
    pid="$(cat "$pid_file")"
    [ -n "$pid" ] || continue
    is_our_server "$pid" || continue
    pids="$pids $pid"
    # Asked to shut down rather than killed outright: Apache forks workers, and
    # killing the parent leaves them orphaned and still holding the port.
    kill "$pid" 2>/dev/null || true
  done

  for _ in $(seq 1 50); do
    port_in_use "$SSH_PORT" || port_in_use "$HTTPS_PORT" || break
    sleep 0.2
  done
  for pid in $pids; do
    is_our_server "$pid" && kill -9 "$pid" 2>/dev/null || true
  done

  rm -rf "$STATE_PATH"
  log "stopped"
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
  local port="$1" name="$2" pid="${3:-}"
  for _ in $(seq 1 100); do
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
      return 0
    fi
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
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
  # Self-signed, and no authority: the tests pin this exact certificate, so
  # nothing ever builds a chain. An authority was generated here until a spike
  # showed openssl verify rejecting the very chain it had just produced, which
  # no test noticed precisely because they all pin.
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$STATE_PATH/leaf.key" -out "$STATE_PATH/leaf.pem" \
    -days 30 -subj "/CN=127.0.0.1" \
    -addext "subjectAltName=IP:127.0.0.1" \
    -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
    -addext "extendedKeyUsage=serverAuth" 2>/dev/null
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
  wait_for_port "$SSH_PORT" sshd "$!"
}

start_https_server() {
  # The Apache that ships with macOS, which speaks CGI, chunked bodies, basic
  # authentication and TLS already. Doing it by hand meant decoding chunked
  # transfers, forwarding the CGI status, and working around a hostname lookup
  # between binding and listening, none of which is our problem here.
  local modules=/usr/libexec/apache2

  htpasswd -bc "$STATE_PATH/htpasswd" "$HTTP_USER" "$HTTP_PASSWORD" 2>/dev/null

  cat > "$STATE_PATH/httpd.conf" <<EOF
ServerRoot "$STATE_PATH"
ServerName 127.0.0.1
Listen 127.0.0.1:$HTTPS_PORT
PidFile "$STATE_PATH/httpd.pid"
ErrorLog "$STATE_PATH/https.log"

LoadModule mpm_prefork_module $modules/mod_mpm_prefork.so
LoadModule authn_core_module $modules/mod_authn_core.so
LoadModule authn_file_module $modules/mod_authn_file.so
LoadModule authz_core_module $modules/mod_authz_core.so
LoadModule authz_user_module $modules/mod_authz_user.so
LoadModule auth_basic_module $modules/mod_auth_basic.so
LoadModule alias_module $modules/mod_alias.so
LoadModule env_module $modules/mod_env.so
LoadModule cgi_module $modules/mod_cgi.so
LoadModule ssl_module $modules/mod_ssl.so
LoadModule unixd_module $modules/mod_unixd.so

SSLEngine on
SSLCertificateFile "$STATE_PATH/leaf.pem"
SSLCertificateKeyFile "$STATE_PATH/leaf.key"

SetEnv GIT_PROJECT_ROOT $STATE_PATH
SetEnv GIT_HTTP_EXPORT_ALL
ScriptAlias / $(git --exec-path)/git-http-backend/

<Location />
    AuthType Basic
    AuthName "pass"
    AuthUserFile "$STATE_PATH/htpasswd"
    Require valid-user
</Location>
EOF

  # Left to daemonise rather than held in the foreground. With -DFOREGROUND it
  # never calls setsid, so it shares the process group of whoever started it,
  # and shutting it down signals that whole group -- which means stopping the
  # servers kills the shell that asked. Daemonised it owns its own group, writes
  # its own pid file, and returns once it is up.
  /usr/sbin/httpd -f "$STATE_PATH/httpd.conf"
  wait_for_port "$HTTPS_PORT" https
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

  # Consumed by the tests. xcodebuild passes variables with this prefix into the
  # test process with the prefix removed.
  cat > "$STATE_PATH/env" <<EOF
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
