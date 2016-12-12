#!/bin/bash

set -e

test $MYID && echo $MYID > /root/data/zookeeper/myid

