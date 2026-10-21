# php-release-bridge

[![build](https://github.com/YasarKah/php-release-bridge/actions/workflows/build.yml/badge.svg)](https://github.com/YasarKah/php-release-bridge/actions/workflows/build.yml)

Community-built PHP Docker images bridging the gap between upstream PHP releases and official Docker image availability.

> [!IMPORTANT]
> **This is not an official PHP or Docker image.** It is not affiliated with, endorsed by, or maintained by
> the PHP project, Docker, Inc. or the [Docker Official Images](https://github.com/docker-library/official-images) program.
> When the official [`php`](https://hub.docker.com/_/php) tag for the same version is available, **use the official image** —
> see [Migrating to the official image](#migrating-to-the-official-image).

## Why

When PHP publishes a release (often a security release), the official `php` image on Docker Hub follows after the
`docker-library/php` update is reviewed, merged into `official-images`, and built. That usually takes hours,
sometimes longer. This project publishes a transparent, reproducible build of the **real upstream release**
for that window, using the same Dockerfile as the official image.

## Available images

| Image | PHP | SAPI | Base | Platforms |
|---|---|---|---|---|
| `ghcr.io/yasarkah/php:8.4.27-fpm-trixie` | 8.4.27 | FPM | Debian 13 (Trixie) slim | `linux/amd64` |

Only `linux/amd64` is built and tested. Other architectures are not published.

The image contains **PHP-FPM only**. It does not include Nginx, Apache or any other web server; put one in front of it.

## Usage

```sh
docker pull ghcr.io/yasarkah/php:8.4.27-fpm-trixie
docker run --rm ghcr.io/yasarkah/php:8.4.27-fpm-trixie php -v
```

Pin by digest in production. The digest of every build is shown in the
[workflow run summary](https://github.com/YasarKah/php-release-bridge/actions/workflows/build.yml) and on the
[package page](https://github.com/YasarKah/php-release-bridge/pkgs/container/php):

```dockerfile
FROM ghcr.io/yasarkah/php:8.4.27-fpm-trixie@sha256:<digest>
```

The image behaves like `php:8.4-fpm-trixie`: FPM listens on port `9000`, the document root is `/var/www/html`,
and `docker-php-ext-install`, `docker-php-ext-configure`, `docker-php-ext-enable` and `docker-php-source`
work the same way.

Example with Nginx (`compose.yaml`):

```yaml
services:
  php:
    image: ghcr.io/yasarkah/php:8.4.27-fpm-trixie
    volumes:
      - ./app:/var/www/html
  nginx:
    image: nginx:stable
    ports:
      - "8080:80"
    volumes:
      - ./app:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
```

```nginx
server {
    listen 80;
    root /var/www/html;
    index index.php;

    location ~ \.php$ {
        fastcgi_pass php:9000;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
```

## Migrating to the official image

Once `php:8.4.27-fpm-trixie` (or a newer `8.4.x`) exists on [Docker Hub](https://hub.docker.com/_/php/tags?name=8.4-fpm-trixie),
replace the image reference. No other change is needed:

```diff
-FROM ghcr.io/yasarkah/php:8.4.27-fpm-trixie
+FROM php:8.4.27-fpm-trixie
```

To keep receiving patch releases and Debian security updates, track the official `php:8.4-fpm-trixie` tag.
Bridge images are not rebuilt after the official tag is published.

## How it is built

1. [`8.4/trixie/fpm/`](8.4/trixie/fpm) is the upstream `docker-library/php` `8.4/trixie/fpm` directory at commit
   [`e3eaff8`](https://github.com/docker-library/php/tree/e3eaff845f7a9f7259c31da54dce0320b47a3bbd/8.4/trixie/fpm),
   the commit that updated it to PHP 8.4.27.
2. PHP is compiled from the official source tarball `php-8.4.27.tar.xz` downloaded from `www.php.net`.
   The build fails unless:
   - the tarball matches the SHA256 published by php.net and by `docker-library/php`
     (`dcf93923b0e38e0d5252b25b796520b5a47761a08b3488b6d0b5d1115764d3f0`), and
   - its GPG signature verifies against the PHP 8.4 release managers' keys pinned by full fingerprint.
3. [GitHub Actions](.github/workflows/build.yml) builds the image for `linux/amd64`, runs the
   [smoke tests](tests/smoke.sh), then rebuilds from cache, pushes to GHCR with an SBOM and SLSA provenance,
   attests the digest, and runs the smoke tests again against the pushed digest.

### Tests

`tests/smoke.sh <image> <version>` checks:

- `php -v` and `php-fpm -v` report the expected version, and `PHP_VERSION` matches it exactly
- `php-fpm -t` passes
- OPcache, sodium, mbstring, openssl, curl and pdo_sqlite are loaded
- the base OS is Debian 13 (Trixie)
- no Nginx/Apache binaries are present
- the container starts and php-fpm reports it is ready
- a FastCGI request from a separate container (`cgi-fcgi`) is answered by php-fpm with the expected version

### Build locally

```sh
docker build --platform linux/amd64 -t php-release-bridge:8.4.27-fpm-trixie 8.4/trixie/fpm
tests/smoke.sh php-release-bridge:8.4.27-fpm-trixie 8.4.27
```

## Differences from the official image

| | Official `php` | This project |
|---|---|---|
| Dockerfile | `docker-library/php` | Same file, with the changes below |
| Base image | `debian:trixie-slim`, rebuilt on every base update | `debian:trixie-slim` pinned by digest |
| `PHP_BUILD_PROVIDER` (shown in `php -i`) | `https://github.com/docker-library/php` | `https://github.com/YasarKah/php-release-bridge` |
| OCI labels | — | Title, source, license, "unofficial" description |
| Platforms | amd64, arm64, and others | `linux/amd64` only |
| Tags | Many aliases (`8.4-fpm`, `fpm`, …) | One exact tag per release |
| Rebuilds | Continuous | One-off, until the official tag exists |
| Registry | Docker Hub | GitHub Container Registry |

## Security

- Treat these images as a short-lived stopgap. They do not receive Debian security rebuilds after publication.
- Verify provenance before use:
  `gh attestation verify oci://ghcr.io/yasarkah/php:8.4.27-fpm-trixie --owner YasarKah`
- The project only repackages upstream PHP. It does not patch PHP or fix PHP vulnerabilities.
- See [SECURITY.md](SECURITY.md) for how to report problems.

## Upstream status

Checked on 2026-10-21:

- PHP 8.4.27 was released on 2026-10-21 as a security release ([php.net](https://www.php.net/downloads.php)).
- `docker-library/php` was updated in [#1694](https://github.com/docker-library/php/pull/1694).
- The official image update is pending in [official-images#22541](https://github.com/docker-library/official-images/pull/22541).
  `php:8.4.27-fpm-trixie` was not yet on Docker Hub.

Check the links above for the current state.

## Roadmap

- Detect new PHP releases from the php.net releases API and the `docker-library/php` `versions.json`,
  and open a pull request that updates the build directory from upstream.
- Mark bridge tags as superseded in the README and package description once the official tag is published.
- Evaluate `linux/arm64` builds on native arm64 runners.

## Contributing

Issues and pull requests are welcome. Please keep changes small and close to upstream:

- Update `8.4/trixie/fpm/` by copying files from `docker-library/php` at a specific commit, and record the commit
  in the Dockerfile header and README.
- Never publish a release candidate under a final version tag, and never publish an image whose source tarball
  cannot be verified.
- Run `tests/smoke.sh` locally before opening a pull request. CI runs it on every pull request.

## License

The build files are MIT-licensed (see [LICENSE](LICENSE)). They are derived from
[docker-library/php](https://github.com/docker-library/php), Copyright (c) 2014 Docker, Inc.
PHP is distributed under the [PHP License v3.01](https://www.php.net/license/). The image also contains Debian
packages under their own licenses.
