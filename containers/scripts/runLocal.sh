#!/bin/bash
#
# &copy; 2017-2018 Regents of the University of California and the Broad Institute. All rights reserved.
#
: ${GP_MODULE_EXEC=$GP_JOB_METADATA_DIR/exec.sh}

cd $GP_LOCAL_PREFIX$WORKING_DIR

echo "========== runLocal.sh inside 1st container, runLocal.sh - running module now  ================="

echo "###### looking for a module specific cached container #######"
. resolveContainerNameToCacheOrNot.sh 
echo " ### docker = $GP_JOB_DOCKER_IMAGE "
echo " ### ECR cache = $GP_MODULE_SPECIFIC_CONTAINER"
echo " ### USE THIS = $CONTAINER_TO_USE"


# pull first so that the stderr.txt is not polluted by the output of docker getting the image
docker pull $GP_JOB_DOCKER_IMAGE

# start the container with an endless loop
# copy the desired dirs into it
# run the module command
# copy the contents back out to the local disk

#  --mount type=bind,src={bind_src},dst={bind_dst}

###########  generate mount str from the GP_MOUNT_POINT_ARRAY ########
# this we create by splitting the mount points that are provided delimited with a colon
GP_MOUNT_POINT_ARRAY=(${GP_JOB_DOCKER_BIND_MOUNTS//:/ })
echo "Mount points for the containers are:"
for i in "${!GP_MOUNT_POINT_ARRAY[@]}"
do
    echo "Mount    $i=>${GP_MOUNT_POINT_ARRAY[i]}"
done


MOUNT_STR="  "
for i in "${!GP_MOUNT_POINT_ARRAY[@]}"
do
    A_MOUNT=" --mount type=bind,src=$GP_LOCAL_PREFIX${GP_MOUNT_POINT_ARRAY[i]},dst=${GP_MOUNT_POINT_ARRAY[i]} "
    MOUNT_STR=$MOUNT_STR$A_MOUNT
done
WALLTIME_UNIT="s"
echo "CONTAINER RUN IS docker run -d   --mount type=bind,src=$GP_LOCAL_PREFIX$GP_JOB_METADATA_DIR,dst=$GP_JOB_METADATA_DIR $MOUNT_STR -t $GP_JOB_DOCKER_IMAGE sleep 90000s "

CONTAINER_ID="`docker run -d   --mount type=bind,src=$GP_LOCAL_PREFIX$GP_JOB_METADATA_DIR,dst=$GP_JOB_METADATA_DIR $MOUNT_STR -t $GP_JOB_DOCKER_IMAGE sleep 90000s `"

echo CONTAINER_ID is $CONTAINER_ID

# the GP_MODULE_DIR and MOD_LIBS are handled different so that it gets captured in the saved image

if [ ! "x$MOD_LIBS_S3" = "x" ]; then
    # Variable is empty
    echo "========== COPY IN module libs $MOD_LIBS "
	docker exec $CONTAINER_ID mkdir -p $MOD_LIBS
	docker cp $GP_LOCAL_PREFIX$MOD_LIBS/. $CONTAINER_ID:$MOD_LIBS
fi


# tasklib should NOT be in the mount points
#
# Try to log the case where a populated tasklib is already present inside the container
#   - see if we can fail if it already exists and is populated
#
docker exec $CONTAINER_ID ls -alrt  $GP_MODULE_DIR
docker cp $GP_LOCAL_PREFIX$GP_MODULE_DIR/ $CONTAINER_ID:$GP_MODULE_DIR
docker exec $CONTAINER_ID ls -alrt  $GP_MODULE_DIR

#
# bootstrap package loading for old modules using shared containers
#
if [ -f "$GP_LOCAL_PREFIX$GP_MODULE_DIR/r.package.info" ]
then
        #echo "$GP_MODULE_DIR/r.package.info found.">$GP_LOCAL_PREFIX$GP_JOB_METADATA_DIR/tedlog1.txt 
        docker exec $CONTAINER_ID  ls /build/source/installPackages.R
	INSTALL_R_PRESENT = $?
        if [ $INSTALL_R_PRESENT != 0 ]
	then
		docker cp /usr/local/bin/installPackages.R  $CONTAINER_ID:/build/source/installPackages.R
		docker exec $CONTAINER_ID /usr/local/bin/installPackages.R $GP_MODULE_DIR/r.package.info
        fi
	docker exec $CONTAINER_ID Rscript /build/source/installPackages.R $GP_MODULE_DIR/r.package.info >$GP_LOCAL_PREFIX$GP_JOB_METADATA_DIR/r.package.installs.out.txt 2>$GP_LOCAL_PREFIX$GP_JOB_METADATA_DIR/r.package.installs.err.txt
fi

#
# the actual exec - do we capture stderr here or move it inside of the exec.sh generated by GP
#
echo EXEC IS "docker exec -e GP_JOB_METADATA_DIR="$GP_JOB_METADATA_DIR" -t $CONTAINER_ID sh $GP_JOB_METADATA_DIR/exec.sh >$GP_LOCAL_PREFIX$STDOUT_FILENAME 2>$GP_LOCAL_PREFIX$STDERR_FILENAME "
docker exec  -e GP_JOB_METADATA_DIR="$GP_JOB_METADATA_DIR" -t $CONTAINER_ID sh $GP_MODULE_EXEC >$GP_LOCAL_PREFIX$GP_JOB_METADATA_DIR/dockerout.log 2>$GP_LOCAL_PREFIX$GP_JOB_METADATA_DIR/dockererr.log 

exit_code=$?
echo "{ \"exit_code\": $exit_code }" >> $GP_LOCAL_PREFIX$GP_JOB_METADATA_DIR/docker_exit_code.txt

echo "======== runLocal: Module execution complete  ========"
docker stop $CONTAINER_ID
echo "Saving to ECR "
/usr/local/bin/saveContainerInECR.sh

# clean up exitted containers so that the docker space does not fill up with old
# containers we won't run again.  Maybe we should leave images as they might actually be reused
# but not for now
echo "=========== removing all exited containers =============="
docker ps -aq --no-trunc -f status=exited | xargs docker rm



