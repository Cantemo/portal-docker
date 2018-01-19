#!/bin/bash -xe

export VIDISPINE_USERNAME="${VIDISPINE_USERNAME:-admin}"
export VIDISPINE_PASSWORD="${VIDISPINE_PASSWORD:-admin}"
export VIDISPINE_HOST="${VIDISPINE_HOST:-vs}"
export VIDISPINE_PORT="${VIDISPINE_PORT:-8080}"
export DATABASE_USER="${DATABASE_USER:-portal}"
export DATABASE_PASSWORD="${DATABASE_PASSWORD:-portal}"
export DATABASE_HOST="${DATABASE_HOST:-portaldb}"
export MEMCACHED_HOST="${MEMCACHED_HOST:-memcached}"
export MEMCACHED_PORT="${MEMCACHED_PORT:-11211}"
export DEBUG="${DEBUG:-false}"
export DEVELOPMENT_SYSTEM="${DEVELOPMENT_SYSTEM:-false}"
export RE3_LOCAL="${RE3_LOCAL:-false}"
export RABBITMQ_HOST="${RABBITMQ_HOST:-rabbitmq}"
export RABBITMQ_PORT="${RABBITMQ_PORT:-5672}"

export RABBITMQ_USER="${RABBITMQ_USER:-portal}"
export RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD:-p0rtal}"
export RABBITMQ_VHOST="${RABBITMQ_VHOST:-portal}"

export ELASTICSEARCH_HOST="${ELASTICSEARCH_HOST:-elastic}"
export ELASTICSEARCH_PORT="${ELASTICSEARCH_PORT:-9200}"
export ELASTICSEARCH_USE_MORPHOLOGY="${ELASTICSEARCH_USE_MORPHOLOGY:-true}"

export NOTIFIER_HOST="${NOTIFIER_HOST:-notifier}"
export NOTIFIER_PORT="${NOTIFIER_PORT:-5000}"

export PORTAL_CELERY_QUEUES="${PORTAL_CELERY_QUEUES:-celery,portal,indexer,indexer_collections,indexer_files,archiver,notifyindexer,re3}"

export ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-env_not_set}"

export PORTAL_CELERY_NUM_WORKERS="${PORTAL_CELERY_NUM_WORKERS:-5}"

export PREVIEW_VIDEO_SHAPES="${PREVIEW_VIDEO_SHAPES:-lowres}"

#export PORTALCONF=${PORTALCONF:-/tmp/portal.conf}

cp /opt/cantemo/portal/configs/portal.conf.sample /tmp/portal.conf

#portal.plugins.activedirectory.authentication.ActiveDirectoryBackend

sed -e "s,^VIDISPINE_USERNAME.*,VIDISPINE_USERNAME: $VIDISPINE_USERNAME," -i /tmp/portal.conf
sed -e "s,^VIDISPINE_PASSWORD.*,VIDISPINE_PASSWORD: $VIDISPINE_PASSWORD," -i /tmp/portal.conf
sed -e "s,^VIDISPINE_URL.*,VIDISPINE_URL: http://$VIDISPINE_HOST," -i /tmp/portal.conf
sed -e "s,^VIDISPINE_PORT.*,VIDISPINE_PORT: $VIDISPINE_PORT," -i /tmp/portal.conf

sed -e "s,^DATABASE_USER.*,DATABASE_USER: $DATABASE_USER," -i /tmp/portal.conf
sed -e "s,^DATABASE_PASSWORD.*,DATABASE_PASSWORD: $DATABASE_PASSWORD," -i /tmp/portal.conf
sed -e "s,^DATABASE_HOST.*,DATABASE_HOST: $DATABASE_HOST," -i /tmp/portal.conf

sed -e "s,^CACHE_LOCATION.*,CACHE_LOCATION: $MEMCACHED_HOST:$MEMCACHED_PORT," -i /tmp/portal.conf
sed -e "s,^DEBUG:.*,DEBUG: $DEBUG," -i /tmp/portal.conf
sed -e "s,^DEVELOPMENT_SYSTEM:.*,DEVELOPMENT_SYSTEM: $DEVELOPMENT_SYSTEM," -i /tmp/portal.conf
sed -e "s,^RE3_LOCAL:.*,RE3_LOCAL: $RE3_LOCAL," -i /tmp/portal.conf

sed -e "s,^CELERY_ALWAYS_EAGER.*,CELERY_ALWAYS_EAGER: False\nBROKER_URL: amqp://$RABBITMQ_USER:$RABBITMQ_PASSWORD@$RABBITMQ_HOST:$RABBITMQ_PORT/$RABBITMQ_VHOST," -i /tmp/portal.conf

# This option in for portal 3.1.x
sed "/\[celery\]/a CELERYD_CONCURRENCY: ${PORTAL_CELERY_NUM_WORKERS}" -i /tmp/portal.conf
# As of portal 3.2.x this is now auto-scaling and the option has been renamed
sed "/\[celery\]/a CELERY_MAXIMUM_WORKERS: ${PORTAL_CELERY_NUM_WORKERS}" -i /tmp/portal.conf

sed "/\[replace_urls\]/a http%3A//$VIDISPINE_HOST%3A$VIDISPINE_PORT/APInoauth/ = /APInoauth/" -i /tmp/portal.conf

# Enable Rules Engine 2
sed "/\[enable_extras\]/a RULES_ENGINE2_ENABLED: True" -i /tmp/portal.conf

# Set Preview Video Shapes
sed -e "s,^PREVIEW_VIDEO_SHAPES.*,PREVIEW_VIDEO_SHAPES: $PREVIEW_VIDEO_SHAPES," -i /tmp/portal.conf

(
    echo "[elasticsearch]" ;
    echo "ELASTICSEARCH_URL: ${ELASTICSEARCH_URL}" ;
    echo "ELASTICSEARCH_USE_MORPHOLOGY: ${ELASTICSEARCH_USE_MORPHOLOGY}" ;
    echo
) >> /tmp/portal.conf

(echo "[elasticsearch]" ; echo "ELASTICSEARCH_URL: ${ELASTICSEARCH_URL}" ; echo ) >> /tmp/portal.conf
(echo "[notifier]" ; echo "NOTIFIER_BIND_ADDRESS: 0.0.0.0"; echo "NOTIFIER_HOST: ${NOTIFIER_HOST}" ; echo) >> /tmp/portal.conf

if [ "X${STATSD_HOST}" != "X" ]; then
    (echo "[statsd]"; echo "STATSD_HOST: ${STATSD_HOST}"; echo "STATSD_PREFIX: ${ENVIRONMENT_NAME}.portal" ) >> /tmp/portal.conf
fi

sed -i -e "s,http://127.0.0.1:8080,http://${VIDISPINE_HOST}:${VIDISPINE_PORT}," /etc/nginx/conf.d/portal.conf

cp /tmp/portal.conf /etc/cantemo/portal/portal.conf

if [ "X$@" = "X" ]; then
    # If we haven't been given a specific command, run the default ones based on the PORTAL_ROLE
    RETURN=$(curl -s -m 10 -u ${VIDISPINE_USERNAME}:${VIDISPINE_PASSWORD} --write-out %{http_code} --output /dev/null http://${VIDISPINE_HOST}:${VIDISPINE_PORT}/API/version) || /bin/true
    if [ "$RETURN" != "200" ]; then
        echo "Vidispine is not yet ready. Exiting."
        exit 1
    fi

    # If postgresql isn't ready yet, exit and let kubernetes restart us
    if ! ncat ${DATABASE_HOST} 5432 < /dev/null; then
        echo "Postgresql is not running on ${DATABASE_HOST}. Exiting"
        exit 1
    fi

    # Run migrate in the setup role. This must be done
    # before the startup routines since they may require a Portal database.
    # Note: This still means that the plugin specific models are not available for startup
    # scripts.
    if [ "X$PORTAL_ROLE" = "Xsetup" ]; then
        /opt/cantemo/portal/bin/south_migrate.sh
    fi

    # Run all startup routines
    for script in /startup.d/*; do
        if [ -x $script ]; then
            $script
        fi
    done

    if [ "X$PORTAL_ROLE" = "Xweb" ]; then
        nginx
        cd /opt/cantemo/portal/portal
        export HTTPS=on
        /opt/cantemo/python/bin/gunicorn_django \
            -t 200 \
            --workers=5 \
            -b localhost:9000
    elif [ "X$PORTAL_ROLE" = "Xcelery" ]; then
        /opt/cantemo/portal/manage.py celery worker -Q $PORTAL_CELERY_QUEUES
    elif [ "X$PORTAL_ROLE" = "Xflower" ]; then
        /opt/cantemo/portal/manage.py celery flower
    elif [ "X$PORTAL_ROLE" = "Xbeat" ]; then
        /opt/cantemo/portal/manage.py \
            celery beat \
            --pidfile= \
            --schedule=/var/lib/cantemo/portal/celerybeat-schedule
    elif [ "X$PORTAL_ROLE" = "Xsetup" ]; then

        # Run migrate in the setup pod only
        /opt/cantemo/portal/bin/south_migrate.sh

        /setup_storages.py

        /enable_apps.sh

        # Run setup scripts in the setup pod only
        for script in /setup.d/*; do
            if [ -x $script ]; then
                $script
            fi
        done
        #flag setup as done
        /setup_done.sh

        # Run the wizard. This script waits until the portal-web service is available
        /setup_wizard.sh

        # Run setup scripts intended to be run after the wizard has completed
        for script in /setup-post-wizard.d/*; do
            if [ -x $script ]; then
                $script
            fi
        done
    elif [ "X$PORTAL_ROLE" = "Xnotifier" ]; then
        /opt/cantemo/python/bin/python \
            /opt/cantemo/portal/notifier/notifier.pyc
    fi
else
    $@
fi
