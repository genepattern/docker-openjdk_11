#!/bin/bash
#
# &copy; 2017-2018 Regents of the University of California and the Broad Institute. All rights reserved.
#
echo "setting up sigterm trap"
trap "echo SIGINT Received! == $? received;exit" SIGINT 
trap "echo SIGTERM Received! == $? received;exit" SIGTERM 
trap "echo EXIT Recieved! == $? received;exit" EXIT 
trap "echo SIGQUIT Received! == $? received;exit" SIGQUIT 
trap "echo SIGKILL Received! == $? received;exit" SIGKILL
trap "echo SIGSTOP Received! == $? received;exit" SIGSTOP 
trap "echo SIGHUP Received! == $? received;exit" SIGHUP

#
# strip off spaces if present
#  - this is to conform to the old API so both can be run in parallel
#
TASKLIB="$(echo -e "${1}" | tr -d '[:space:]')"
INPUT_FILES_DIR="$(echo -e "${2}" | tr -d '[:space:]')"
S3_ROOT="$(echo -e "${3}" | tr -d '[:space:]')"
WORKING_DIR="$(echo -e "${4}" | tr -d '[:space:]')"
EXECUTABLE=$5

# make a directory into which we will S3 sync everything we have had passed in to the 'outer' container
# this will NOT be at the same path as on the GP head node and the compute node, but it will be mounted to the
# inner container using the same path as on the head node
#
# Note we need to coordinate with Peter to ensure he doesn't do additional S3 commands in the inner container
# in the generated exec.sh script
#
# /local on the compute node should be mounted to /local in this (outer) container
#
LOCAL_DIR=/local

#
# assign filenames for STDOUT and STDERR if not already set
#
: ${GP_METADATA_DIR=$WORKING_DIR/.gp_metadata}
: ${STDOUT_FILENAME=$GP_METADATA_DIR/stdout.txt}
: ${STDERR_FILENAME=$GP_METADATA_DIR/stderr.txt}
: ${EXITCODE_FILENAME=$GP_METADATA_DIR/exit_code.txt}

# Default is to mount the local drive for everything but modlibs which are cp'd in
#   options are 
#  /usr/local/bin/runLocalMnt.sh - mounts all drives, copies none 
#  /usr/local/bin/runLocalCp.sh  --> copies all dirs in, no mounts
#
: ${RUN_DOCKER_SCRIPT=/usr/local/bin/runLocal.sh}
chmod a+x $5

#
# set the modules container
#
if [ "x$DOCKER_CONTAINER" = "x" ]; then
    # Variable is empty
    echo "== no DOCKER_CONTAINER specified. Using default "
    DOCKER_CONTAINER=genepattern/docker-java17openjdk:develop
fi

#
# and a possibly different container id to use to save or reuse a cached container
#
if [ "x$MODULE_SPECIFIC_CONTAINER" = "x" ]; then
    # Variable is empty
    echo "== no MODULE_SPECIFIC_CONTAINER specified. No caching of the container will be done at the end of the run "
fi


# copy tasklib in, this is necessary until each module has a captured or specially built container
echo "=== 1. PERFORMING AWS SYNC $S3_ROOT$TASKLIB $LOCAL_DIR/$TASKLIB"
aws s3 sync $S3_ROOT$TASKLIB $LOCAL_DIR/$TASKLIB --quiet

# copy the inputs, this is redundant with the aws-synch-from-s3.sh script but left in for backward compatibility
echo "=== 2. PERFORMING aws s3 sync $S3_ROOT$INPUT_FILES_DIR $LOCAL_DIR/$INPUT_FILES_DIR"
aws s3 sync $S3_ROOT$INPUT_FILES_DIR $LOCAL_DIR/$INPUT_FILES_DIR --quiet

# switch to the working directory and sync it up - should be empty, maybe drop this
echo "=== 3. PERFORMING aws s3 sync $S3_ROOT$WORKING_DIR $LOCAL_DIR/$WORKING_DIR "
aws s3 sync $S3_ROOT$WORKING_DIR $LOCAL_DIR/$WORKING_DIR --quiet

# sync the metadata dir - VITAL - this is where the aws-sync and the exec script will come from
echo "=== 4. synching gp_metadata_dir"
aws s3 sync $S3_ROOT$GP_METADATA_DIR $LOCAL_DIR/$GP_METADATA_DIR 

# make sure scripts in metadata dir are executable
cd $LOCAL_DIR/$WORKING_DIR
echo "=== 5. chmodding $GP_METADATA_DIR from $PWD"
chmod a+rwx $LOCAL_DIR/$GP_METADATA_DIR/*

echo "=== Load $MOD_LIB libraries"
# bootstapping until all modules have unique fully-populated containers
#  setup so the inner container loads R libraries, add a package load before the actual module call
# and do the necessary S3 sync based on an environment variable
if [ "x$MOD_LIBS_S3" = "x" ]; then
    # Variable is empty
    echo "== no module libs to copy in "
else
    # copy in cached module libraries - this is only temporary
    aws s3 sync $S3_ROOT$MOD_LIBS_S3 $MOD_LIBS --quiet
    ls -alrt $MOD_LIBS
fi

#
# TEMP ISSUE- need to make a couple of dir roots that Peter's script will need to sync into 
#
# mkdir -p $LOCAL_DIR/Users/liefeld/GenePattern
# mkdir -p $LOCAL_DIR/opt/gpbeta/gp_home/users/

# RUN Peter's file for additional S3 fetches
if [ -f "$LOCAL_DIR$GP_METADATA_DIR/aws-sync-from-s3.sh" ]
then
    echo "==Running Peter's s3 script ==="
    . $LOCAL_DIR$GP_METADATA_DIR/aws-sync-from-s3.sh
    mv $LOCAL_DIR$GP_METADATA_DIR/aws-sync-from-s3.sh $LOCAL_DIR$GP_METADATA_DIR/aws-sync-from-s3_HOLD.sh
    echo "# stubbed out to prevent call from inside inner container" > $LOCAL_DIR$GP_METADATA_DIR/aws-sync-from-s3.sh
    chmod a+x $LOCAL_DIR$GP_METADATA_DIR/aws-sync-from-s3.sh
    echo "===Stubbed out S3 script "
fi

synchDir 30s $LOCAL_DIR$WORKING_DIR $S3_ROOT$WORKING_DIR &

echo "========== S3 copies in complete, DEBUG inside 1st container ================="

. $RUN_DOCKER_SCRIPT $@

echo "====== END RUNNING Module, copy back from S3  ================="

# send the generated files back
echo "=== 6. PERFORMING aws s3 sync $LOCAL_DIR/$WORKING_DIR $S3_ROOT$WORKING_DIR"
aws s3 sync $LOCAL_DIR/$WORKING_DIR $S3_ROOT$WORKING_DIR 

# TASKLIB- NO LONGER SYNCH'D BACK
#echo "=== 7. PERFORMING aws s3 sync $LOCAL_DIR/$TASKLIB $S3_ROOT$TASKLIB"
#aws s3 sync $LOCAL_DIR/$TASKLIB $S3_ROOT$TASKLIB --quiet

# Synch metadata to ensure stderr.txt etc make it back
echo "=== 8. PERFORMING aws s3 sync  $LOCAL_DIR/$GP_METADATA_DIR $S3_ROOT$GP_METADATA_DIR"
aws s3 sync  $LOCAL_DIR/$GP_METADATA_DIR $S3_ROOT$GP_METADATA_DIR --quiet

#
# allow customization for specific images - eg to save RLIBS back to S3 for reuse
#
if [ "x$MOD_LIBS_S3" = "x" ]; then
    # Variable is empty
    echo "== no module libs to copy in "
else
    # save changes to  $MOD_LIBS back to $MOD_LIBS_S3: "
    aws s3 sync $MOD_LIBS $S3_ROOT$MOD_LIBS_S3  --quiet
fi






