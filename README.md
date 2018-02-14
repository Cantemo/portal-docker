Portal in Docker
================

This repo contains configuration for how to build Portal docker images
and how to run portal with docker-compose and kubernetes (kubernetes
will come at a later stage)

Prerequisites
-------------

This setup does not include many of the components required for
running Cantemo Portal. The assumption is that these are setup outside
of the docker environment, for example using AWS services.

The following services are required for Cantemo Portal:

* Vidispine - You can either install your own Vidispine instance, or
  run vidispine off of the Amazon Marketplace. A development instance
  is enough for a proof-of-concept installation but you should use a
  production license for a live installation.
* Postgresql - You can use Amazon RDS PostgreSQL.
* Memcached - You can use Elasticache
* Elastic Search - You can use Amazon Elasticsearch but make sure you
  instantiate a version 1.5 cluster. If you are using this
  alternative, also make sure you set the environment variable
  ELASTICSEARCH_USE_MORPHOLOGY to false Morphology requires a plugin
  which is not available in Amazon Elastic Search.
* You should also prepare a docker registry if you want to run this on a
  more complex system than a single node.

In addition to these services you also need to have a download link
for a portal installer. These can be obtained from Cantemo Support or your system integrator.

A license key for Portal is required. You can obtain one from your system integrator.

Building
--------

You need to start by setting the PORTAL_DOWNLOAD_URL environment
variable to a portal download link. You can obtain these from Cantemo
Support.

> export PORTAL_DOWNLOAD_URL=http://www2.cantemo.com/files/transfer/f1/f1d2d2f924e986ac86fdf7b36c94bcdf32beec15/RedHat7_Portal_3.3.x.tar

> docker build -t portal:latest images/portal

> docker tag portal:tag your.registry.here/portal:latest

> docker push your.registry.here/portal:latest

Configuration
-------------

Once the image is built you need to configure the runtime
environment. This is done by copying the file compose/env-sample to compose/.env

This .env file will be read by docker-compose and used to configure
portal inside the containers. In the sample file, most of the services
are assumed to be run as Amazon services, so the actual configuration
parameters may vary depending on your specific setup.

Running
-------

Once you have configured the docker-compose environment you can bring up the system with the commands:

> cd compose
> docker-compose -p portal up

This will bring up all the portal components and you can now access
the portal installation by going to http://your.docker.server in your browser.

