# Security Policy

## Scope

This repository contains build files for **unofficial** PHP container images.
It is not affiliated with the PHP project, Docker, Inc. or the Docker Official Images program.

| Report here | Report upstream |
|---|---|
| Problems in this repository's Dockerfile, scripts or workflow | Vulnerabilities in PHP itself: https://github.com/php/php-src/security |
| Published images that do not match this repository's source | Debian package vulnerabilities: https://www.debian.org/security/ |
| Compromised or unexpected tags under `ghcr.io/yasarkah/php` | Issues in the official image: https://github.com/docker-library/php/issues |

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting:
**Security → Report a vulnerability** on this repository.
Do not open a public issue for undisclosed vulnerabilities.

You can expect an acknowledgement within 7 days. This is a volunteer-maintained project; there is no SLA.

## Supported images

Only the most recent tag for each PHP minor version is maintained, and only until the
matching official `php` image tag is published on Docker Hub. After that, migrate to
the official image; old bridge tags are not rebuilt for Debian security updates.

## Verifying an image

Each published image has a build provenance attestation and an SBOM:

```sh
gh attestation verify oci://ghcr.io/yasarkah/php:8.4.27-fpm-trixie --owner YasarKah
docker buildx imagetools inspect ghcr.io/yasarkah/php:8.4.27-fpm-trixie --format '{{ json .SBOM }}'
```

Always deploy by digest (`@sha256:...`) rather than by tag.
