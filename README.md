# indi-allsky-web

Container image for the **web/SyncAPI side** of [indi-allsky](https://github.com/aaronwmorris/indi-allsky),
for running on the k8s homelab (arm64) as the remote server that the camera Pi
uploads to. It serves the gallery at zephyr.ecafe.org.

The image is upstream's own `docker/Dockerfile.gunicorn`, built unchanged at
the commit in [`UPSTREAM_REF`](UPSTREAM_REF), plus one script:

- **`expire.sh`**: deletes images and videos past the retention window. A
  SyncAPI receiver never expires anything by itself (the camera's capture
  process does that on the Pi, and deletions aren't synced), so run this as a
  nightly CronJob with the same image and environment as the web pod.
  It wraps upstream's `misc/expire_images.py` (defaults: images 30 days,
  videos 365 days).

## Image

`ghcr.io/ennui2342/indi-allsky-web:1.YYYYMMDD.RUN`, built on every push to
`main` by [`.github/workflows/build.yml`](.github/workflows/build.yml) on a native
arm64 runner. There is no `latest` tag. CI posts the result to Discord.

The entrypoint is upstream's `start_gunicorn.sh` (port 8000). It needs the
environment from upstream's `docker/env_template` (MariaDB connection, Flask
secret and password keys, first web user). On every start it runs the
database migrations, keeping the migration state in `/var/lib/indi-allsky`,
which must be persistent. It also runs `sudo chown` on `/etc/indi-allsky` and
`/var/lib/indi-allsky`.

## Local testing (Mac, arm64)

```bash
cp .env.example .env    # fill in; .env is gitignored
./build-local.sh        # same two-step build as CI → indi-allsky-web:local
docker compose up -d    # MariaDB + web at http://localhost:18000/indi-allsky/
docker compose run --rm expire
docker compose down -v
```

## Secrets

- **Local:** `.env` (gitignored) is used only by the compose stack above.
- **Cluster:** generated separately and kept in the k8s repo as a
  SOPS-encrypted `*-secret.yaml`, like the rest of the cluster.
  `INDIALLSKY_FLASK_PASSWORD_KEY` encrypts stored secrets in the database, so
  it must never change once set.
- **CI:** `DISCORD_WEBHOOK` is a GitHub Actions secret, as in the other
  image repos. The notify step skips if it isn't set.

## Upgrading

Keep this image on the same indi-allsky commit as the camera Pi
(`~/indi-allsky` on the Pi, ignoring the local patch commits), so both sides
speak the same SyncAPI. Upgrade both together:

1. Set `UPSTREAM_REF` to the new commit and push. CI builds and pushes a new tag.
2. Bump the tag in the k8s repo.
3. Upgrade the Pi to the same commit.

Built with the help of Claude (Anthropic's AI assistant).
