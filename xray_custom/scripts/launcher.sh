#!/bin/sh
set -e

bash ./xray_prepare.sh
bash ./post_register.sh
exec /usr/bin/xray -config /configure/output/config.json