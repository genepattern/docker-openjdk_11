#!/bin/sh
echo "Config for $i -- $@"
. runConfig.sh $@
. ../../DinD_testing_scripts/runOnBatchInner.sh $@

