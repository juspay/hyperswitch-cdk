#!/bin/bash
set -e
set -x

aws s3 cp s3://{{bucket-name}}/envoy.yaml /home/ubuntu/
rm -rf /etc/envoy/envoy.yaml
cp /home/ubuntu/envoy.yaml /etc/envoy/envoy-config-template.yaml
cp /home/ubuntu/envoy.yaml /etc/envoy/
chmod ug+rw /etc/envoy/envoy.yaml
chown envoy:envoy /etc/envoy/envoy.yaml
chmod ug+rw /etc/envoy/envoy-config-template.yaml
chown envoy:envoy /etc/envoy/envoy-config-template.yaml
systemctl restart envoy.service
