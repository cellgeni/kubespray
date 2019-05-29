#!/usr/bin/env bash
docker rm -f scfind || docker run --name scfind -d -p 3838:3838 quay.io/hemberg-group/scfind-shiny:v1.5.0