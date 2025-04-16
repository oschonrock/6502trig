#!/usr/bin/env bash

# change labels which match "bk" pattern into breakpoints for vice
cat $1 | egrep '[.:]bk[0-9]*' | sed -E 's/^al/bk/' >> $2
