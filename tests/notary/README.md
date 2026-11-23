# Docker Content Trust test server

`server-config.json` configures the `notary` container, a Notary server like the one `docker trust` signs to. `docker-compose.yml` and `.github/workflows/main.yml` both mount it at `/etc/notary/server-config.json`. They mount `certs/` at `/etc/notary/certs/`. ORAS repos point at it with `-trust-server https://notary:4443`.

The server keeps trust data in memory and signs timestamps with its own key, so it needs no database or signer service. Restarting it discards all trust data. Since IPM pins the root key of each repository it has verified, use a fresh test repository name after a restart so its keys and pins belong to the same run.

It runs without authentication, like the `oras` test registry. Do not use this configuration outside tests.

## Certificates

IPM only accepts an https trust server, as docker does. `certs/notary-server.crt` and `certs/notary-server.key` are the server's certificate and key for `notary`, `localhost` and `127.0.0.1`, issued by `certs/root-ca.crt`. The CA's private key was discarded after issuing the server certificate, so it cannot issue others. The server key exists only for tests and is not secret. The certificates expire in November 2036.

Compose and CI select the `content-trust-test` Docker build target. Only this test image installs `root-ca.crt` in the system trust store. An ordinary `docker build .` uses the `release` target and the base image's trust store. The stalled-server stand-in in `Test.PM.Integration.OrasContentTrust` serves the same certificate on `127.0.0.1`. Since the server key is public, anything in that image can pose as `notary`, `localhost` or `127.0.0.1` over TLS, which is acceptable only in test images.

To replace them, issue a new server certificate with `subjectAltName=DNS:notary,DNS:localhost,IP:127.0.0.1` from a new CA, replace the three files, and rebuild the `iris` image.

## The notary CLI

The `iris` image installs the notary CLI v0.6.1, whose only Linux build is for amd64, so an arm64 image has none. There `Test.PM.Integration.OrasContentTrust` skips its signed cases, unless the environment variable `IPM_REQUIRE_CONTENT_TRUST` is set, as in CI, which makes them fail instead. Copying the amd64 binary into the container works on hosts that emulate amd64.

## Signing in tests

`Test.PM.Integration.OrasContentTrust` publishes modules with the ordinary `publish` command and then signs them as an external promotion process would, with the notary CLI that the IRIS image installs:

```sh
notary -d <signer keys> -s https://notary:4443 init oras:5000/<namespace>/<module>
notary -d <signer keys> -s https://notary:4443 key rotate oras:5000/<namespace>/<module> snapshot -r
notary -d <signer keys> -s https://notary:4443 publish oras:5000/<namespace>/<module>
notary -d <signer keys> -s https://notary:4443 addhash oras:5000/<namespace>/<module> <tag> <manifest size> --sha256 <manifest digest> -p
```

The passphrases come from `NOTARY_ROOT_PASSPHRASE`, `NOTARY_TARGETS_PASSPHRASE`, `NOTARY_SNAPSHOT_PASSPHRASE` and `NOTARY_DELEGATION_PASSPHRASE`. The test sets them to fixed values that are not secret.
