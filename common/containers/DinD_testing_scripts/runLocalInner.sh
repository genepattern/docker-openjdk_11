#!/bin/sh
#
# &copy; 2017-2018 Regents of the University of California and the Broad Institute. All rights reserved.
#
echo MOD LIBS ARE $MOD_LIBS 

: ${STDOUT_FILENAME=stdout.txt}
: ${STDERR_FILENAME=stderr.txt}
: ${GP_METADATA_DIR=$WORKING_DIR/.gp_metadata}
: ${EXITCODE_FILENAME=$GP_METADATA_DIR/exit_code.txt}
: ${S3_ROOT=s3://moduleiotest}
: ${GP_JOB_WALLTIME_SEC=3600}

# Default is to mount the local drive, option us /usr/local/bin/runLocalCp.sh or runLocalMnt.sh
: ${RUN_DOCKER_SCRIPT=/usr/local/bin/runLocal.sh}

echo "Running DinD using $RUN_DOCKER_SCRIPT in outer container"

# ##### NEW PART FOR SCRIPT INSTEAD OF COMMAND LINE ################################
# Make the input file directory since we need to put the script to execute in it
cd $TEST_ROOT
mkdir -p $WORKING_DIR
mkdir -p $GP_METADATA_DIR

EXEC_SHELL=$GP_METADATA_DIR/exec.sh
echo "#!/bin/bash\n" > $EXEC_SHELL
echo "cd $WORKING_DIR\n" >> $EXEC_SHELL
echo $COMMAND_LINE >>$EXEC_SHELL
echo "\n " >>$EXEC_SHELL
chmod a+x $EXEC_SHELL

echo RUNNING in DOCKER: $EXEC_SHELL

echo CALL IS docker run -e MOD_LIBS="$MOD_LIBS" -e MOD_LIBS_S3="$MOD_LIBS_S3" -e GP_METADATA_DIR="$GP_METADATA_DIR" -v /var/run/docker.sock:/var/run/docker.sock  -v $GP_METADATA_DIR:$GP_METADATA_DIR -v $GP_TASKLIB:$GP_TASKLIB -v $INPUT_FILE_DIRECTORIES:$INPUT_FILE_DIRECTORIES -v $WORKING_DIR:$WORKING_DIR  -e DOCKER_CONTAINER=$DOCKER_CONTAINER -e GP_WORKING_DIR=$WORKING_DIR -e GP_DOCKER_MOUNT_POINTS=$INPUT_FILE_DIRECTORIES:$WORKING_DIR:$GP_TASKLIB -e GP_TASKLIB=$GP_TASKLIB -t liefeld/dind $RUN_DOCKER_SCRIPT 
echo "\n\n\n" 

docker run -e $GP_JOB_WALLTIME_SEC=$$GP_JOB_WALLTIME_SEC -e GP_LOCAL_PREFIX=  -e STDOUT_FILENAME=$GP_METADATA_DIR/stdout.txt -e STDERR_FILENAME=$GP_METADATA_DIR/stderr.txt  -e MOD_LIBS="$MOD_LIBS" -e MOD_LIBS_S3="$MOD_LIBS_S3" -e GP_METADATA_DIR="$GP_METADATA_DIR" -v /var/run/docker.sock:/var/run/docker.sock  -v $GP_METADATA_DIR:$GP_METADATA_DIR -v $GP_TASKLIB:$GP_TASKLIB -v $INPUT_FILE_DIRECTORIES:$INPUT_FILE_DIRECTORIES -v $WORKING_DIR:$WORKING_DIR  -e GP_DOCKER_CONTAINER=$GP_DOCKER_CONTAINER -e GP_WORKING_DIR=$WORKING_DIR -e GP_DOCKER_MOUNT_POINTS=$INPUT_FILE_DIRECTORIES:$WORKING_DIR:$GP_TASKLIB -e GP_TASKLIB=$GP_TASKLIB -t liefeld/dind $RUN_DOCKER_SCRIPT  

 
echo OUTER CONTAINER DONE 


