# zot test registry configuration

`zot-config.json` and `htpasswd` configure the zot registry in the `oras` container. `docker-compose.yml` and `.github/workflows/main.yml` both mount them into `/etc/zot/`.

## Access

Most of the registry is open to anonymous clients, so ORAS tests that do not test authentication need no credentials. Two path prefixes require HTTP Basic authentication:

| Repositories | Anonymous | `writer` | `reader` |
|---|---|---|---|
| everything else | read, create, update, delete | same as anonymous | same as anonymous |
| `auth-test/**` | none | read, create, update, delete | read |
| `auth-private/**` | none | read, create, update, delete | none |

`Test.PM.Integration.Oras` uses `auth-test` for login, permission and bad-password cases, and `auth-private` for a valid login that is refused read access. Point a repo at them with `-namespace`, for example:

```
repo -o -name authrepo -url http://oras:5000 -namespace auth-test -username writer -password writerpass -publish 1
```

## Users

These credentials exist only for tests and are not secret.

| User | Password |
|---|---|
| `writer` | `writerpass` |
| `reader` | `readerpass` |

`htpasswd` stores them as bcrypt hashes. To add a user or change a password, regenerate its line with `htpasswd -nbB <user> <password>` (from Apache's `apache2-utils`). The file must keep LF line endings, which `.gitattributes` enforces.

## Other settings

- `extensions.search` and `extensions.ui` serve the browser UI at http://localhost:5001/home. CVE scanning is not configured, so zot does not download a vulnerability database.
- `log.level` is `debug`, so `docker logs` shows why a request was refused.

After changing either file, restart the container so zot reads it: `docker compose restart oras`.
