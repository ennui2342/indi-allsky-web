#!/bin/bash
# Delete images and videos older than the retention window on this SyncAPI
# receiver. Nothing else expires files here: the capture process that normally
# does it runs on the camera's Pi, and SyncAPI never propagates deletions.
#
# Run as a CronJob from the same image and environment as the web pod
# (gunicorn), which must have started at least once (it creates the schema):
#
#   ./expire.sh [--days 30] [--timelapse_days 365]   (upstream's defaults)
#
# Writes /etc/indi-allsky/flask.json the same way upstream's
# docker/start_gunicorn.sh does, without the migrations or gunicorn.

set -o errexit
set -o nounset

ALLSKY_DIRECTORY="/home/allsky/indi-allsky"
ALLSKY_ETC="/etc/indi-allsky"

# The folder only appears with the first upload; until then there's nothing
# to expire (and expire_images.py would crash on it).
if [ ! -d "$INDIALLSKY_IMAGE_FOLDER" ]; then
    echo "No image folder yet ($INDIALLSKY_IMAGE_FOLDER): nothing to expire"
    exit 0
fi

if [ "${INDIALLSKY_MARIADB_SSL:-false}" == "true" ]; then
    SSL="ssl_ca=/etc/ssl/certs/ca-certificates.crt&ssl_verify_identity&"
else
    SSL=""
fi
SQLALCHEMY_DATABASE_URI="mysql+mysqlconnector://${MARIADB_USER}:${MARIADB_PASSWORD}@${INDIALLSKY_MARIADB_HOST}:${INDIALLSKY_MARIADB_PORT}/${MARIADB_DATABASE}?${SSL}charset=${INDIALLSKY_MARIADB_CHARSET}&collation=${INDIALLSKY_MARIADB_COLLATION}"

jq \
 --arg sqlalchemy_database_uri "$SQLALCHEMY_DATABASE_URI" \
 --arg indi_allsky_docroot "/var/www/html/allsky" \
 --argjson indi_allsky_auth_all_views "$INDIALLSKY_FLASK_AUTH_ALL_VIEWS" \
 --arg migration_folder "/var/lib/indi-allsky/migrations" \
 --arg image_folder "$INDIALLSKY_IMAGE_FOLDER" \
 --arg secret_key "$INDIALLSKY_FLASK_SECRET_KEY" \
 --arg password_key "$INDIALLSKY_FLASK_PASSWORD_KEY" \
 '.SQLALCHEMY_DATABASE_URI = $sqlalchemy_database_uri | .INDI_ALLSKY_DOCROOT = $indi_allsky_docroot | .INDI_ALLSKY_AUTH_ALL_VIEWS = $indi_allsky_auth_all_views | .MIGRATION_FOLDER = $migration_folder | .INDI_ALLSKY_IMAGE_FOLDER = $image_folder | .SECRET_KEY = $secret_key | .PASSWORD_KEY = $password_key' \
 "${ALLSKY_DIRECTORY}/flask.json_template" > "${ALLSKY_ETC}/flask.json"

cd "$ALLSKY_DIRECTORY"
# shellcheck disable=SC1091
source /home/allsky/venv/bin/activate
exec ./misc/expire_images.py "$@"
