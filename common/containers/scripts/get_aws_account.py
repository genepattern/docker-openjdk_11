import boto3
sts = boto3.client("sts")
x = sts.get_caller_identity()
print x['Account']
