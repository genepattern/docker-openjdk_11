#!/bin/sh

: ${i=}
 
TEST_ROOT=$PWD
# ============ NOTE TASKLIB MUST END WITH A SLASH ===========
GP_TASKLIB=/Users/liefeld/GenePattern/gp_dev/docker/docker-aws-common-scripts/containers/tests/src
INPUT_FILE_DIRECTORIES=$TEST_ROOT/data
WORKING_DIR=$TEST_ROOT/job_1$1
#MOD_LIBS=$TASKLIB
#MOD_LIBS_S3=$TASKLIB
unset MOD_LIBS
unset MOD_LIBS_S3


COMMAND_LINE="java -cp $GP_TASKLIB/SelectFeaturesColumns.jar:$GP_TASKLIB/gp-modules.jar org.genepattern.modules.selectfeaturescolumns.SelectFeaturesColumns $INPUT_FILE_DIRECTORIES/all_aml_train$i.gct $WORKING_DIR/testout$i.gct -t1-2"

# docker local only vars
GP_DOCKER_CONTAINER=genepattern/docker-java17openjdk:develop

# aws batch only vars 
S3_ROOT=s3://moduleiotest
#JOB_DEFINITION_NAME="Java17_OpenJDK_Generic"
JOB_DEFINITION_NAME="S3ModuleWrapper"

JOB_ID=gp_S3WRAPPER_SFC_JAVA17_$1
JOB_QUEUE=TedTest

#unset GP_METADATA_DIR
#unset EXITCODE_FILENAME

RUN_DOCKER_SCRIPT=runLocal.sh



