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

In addition to these services you also need to have a download link
for a portal installer. These can be obtained from Cantemo Support.

Building
--------

You need to start by setting the PORTAL_DOWNLOAD_URL environment
variable to a portal download link. You can obtain these from Cantemo
Support.

> export PORTAL_DOWNLOAD_URL=http://www2.cantemo.com/files/transfer/f1/f1d2d2f924e986ac86fdf7b36c94bcdf32beec15/RedHat7_Portal_3.3.x.tar

> docker build -t portal:tag images/portal


Configuration
-------------

Once you have setup all the 
