#!/bin/bash
docker logs mysql8 2>&1 | grep GENERATED
