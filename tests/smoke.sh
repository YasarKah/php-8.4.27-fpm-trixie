#!/usr/bin/env bash
# Usage: tests/smoke.sh <image> <expected-php-version>
set -euo pipefail

image="${1:?usage: $0 <image> <expected-php-version>}"
expected="${2:?usage: $0 <image> <expected-php-version>}"
helper_image='debian:trixie-slim@sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad'

id="smoke-$$"
net="$id-net"
fpm="$id-fpm"

cleanup() {
	docker rm -f "$fpm" >/dev/null 2>&1 || true
	docker network rm "$net" >/dev/null 2>&1 || true
}
trap cleanup EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

run() { docker run --rm --platform linux/amd64 "$image" "$@"; }

out="$(run php -v)"
echo "$out"
grep -q "^PHP $expected (cli)" <<<"$out" || fail "php -v does not report $expected"
pass "php -v"

version="$(run php -r 'echo PHP_VERSION;')"
[ "$version" = "$expected" ] || fail "PHP_VERSION is '$version', expected '$expected'"
pass "PHP_VERSION is exactly $expected"

out="$(run php-fpm -v)"
echo "$out"
grep -q "^PHP $expected (fpm-fcgi)" <<<"$out" || fail "php-fpm -v does not report $expected"
pass "php-fpm -v"

run php-fpm -t || fail "php-fpm -t"
pass "php-fpm -t"

out="$(run php -m)"
for ext in 'Zend OPcache' sodium mbstring openssl curl pdo_sqlite; do
	grep -qx "$ext" <<<"$out" || fail "extension missing: $ext"
done
pass "expected extensions loaded"

out="$(run sh -c 'grep -m1 -o "Debian GNU/Linux [0-9]* ([a-z]*)" /etc/os-release')"
[ "$out" = "Debian GNU/Linux 13 (trixie)" ] || fail "unexpected OS: $out"
pass "base OS is $out"

if run sh -c 'command -v nginx || command -v apache2 || command -v httpd'; then
	fail "image unexpectedly contains a web server"
fi
pass "no Nginx/Apache in image"

docker network create "$net" >/dev/null
docker run -d --platform linux/amd64 --name "$fpm" --network "$net" --network-alias fpm "$image" >/dev/null

for _ in $(seq 1 30); do
	docker logs "$fpm" 2>&1 | grep -q 'ready to handle connections' && break
	sleep 1
done
docker logs "$fpm" 2>&1 | grep -q 'ready to handle connections' || { docker logs "$fpm"; fail "php-fpm did not start"; }
[ "$(docker inspect -f '{{.State.Running}}' "$fpm")" = true ] || fail "container is not running"
pass "container started, php-fpm ready"

docker exec "$fpm" sh -c 'printf "%s" "<?php echo \"ok:\", PHP_VERSION, \":\", PHP_SAPI;" > /var/www/html/smoke.php'

out="$(docker run --rm --platform linux/amd64 --network "$net" -e DEBIAN_FRONTEND=noninteractive "$helper_image" sh -c '
	set -e
	apt-get update -qq >/dev/null
	apt-get install -y -qq --no-install-recommends libfcgi-bin >/dev/null
	SCRIPT_FILENAME=/var/www/html/smoke.php REQUEST_METHOD=GET cgi-fcgi -bind -connect fpm:9000
')"
echo "$out"
grep -q "ok:$expected:fpm-fcgi" <<<"$out" || fail "FastCGI response did not match"
pass "FastCGI request served by php-fpm $expected"

echo "All smoke tests passed for $image"
