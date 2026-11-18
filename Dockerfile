# Thin layer over upstream indi-allsky's own docker/Dockerfile.gunicorn,
# built from the commit in UPSTREAM_REF (see .github/workflows/build.yml).
# The only addition is expire.sh, so the expiry CronJob can run from the
# same image as the web pod.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

COPY --chown=allsky:allsky --chmod=755 expire.sh /home/allsky/expire.sh
