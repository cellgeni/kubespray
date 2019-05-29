#!/usr/bin/env bash
docker run -d --restart=unless-stopped \
    -p 80:80 -p 443:443 \
    -v $HOME/fullchain.pem:/etc/rancher/ssl/cert.pem \
    -v $HOME/privkey.pem:/etc/rancher/ssl/key.pem \
    rancher/rancher:latest --no-cacerts