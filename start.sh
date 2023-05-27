#!/bin/bash
systemctl daemon-reload
systemctl start dedoduro.service
exec "$@"
