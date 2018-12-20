

if [ "x$GP_MODULE_SPECIFIC_CONTAINER" = "x" ]; then
    # Variable is empty
    echo "== no MODULE_SPECIFIC_CONTAINER specified. Using default for test purposes "
    # GP_MODULE_SPECIFIC_CONTAINER=liefeld/test-cache_module_specific_container
 
    GP_MODULE_SPECIFIC_CONTAINER="`python /usr/local/bin/make_repo_name.py $GP_MODULE_LSID $GP_MODULE_NAME`"
    echo "== ECR TAG is  $GP_MODULE_SPECIFIC_CONTAINER =="
fi

CONTAINER_TAG=$GP_MODULE_SPECIFIC_CONTAINER
CONTAINER_VERSION=1
#PROFILE="--profile genepattern"
PROFILE=""

AWS_ACCOUNT="`python /usr/local/bin/get_aws_account.py`"
echo " == found AWS account ID = $AWS_ACCOUNT "

aws --region us-east-1 ecr describe-images --repository-name $CONTAINER_TAG  > repo.json
if [ -s repo.json ];
then
   echo "Container already exists in ECR"
   CONTAINER_TO_USE-$CONTAINER_TAG

   # login to the AWS ECR
   aws --region us-east-1 ecr get-login --no-include-email  > dockerlogin.sh
   sh dockerlogin.sh

   # pull the ECR container
   docker pull $AWS_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/$CONTAINER_TAG

   # tell the local docker that 
   docker tag $AWS_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/$CONTAINER_TAG $GP_JOB_DOCKER_IMAGE
   #exit
else
   echo " == Pulling $GP_JOB_DOCKER_IMAGE from dockerhub "
   CONTAINER_TO_USE=$GP_JOB_DOCKER_IMAGE
   docker pull $GP_JOB_DOCKER_IMAGE
fi




