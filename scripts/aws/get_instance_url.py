import os
import argparse
import boto3

def set_output(name, value):
    with open(os.environ['GITHUB_OUTPUT'], 'a') as fh:
        print(f'{name}={value}', file=fh)

parser = argparse.ArgumentParser()
parser.add_argument('--region', choices=['us-east-1', 'us-west-1', 'ca-central-1'], dest='region', action='store', required='true', help='The target region')
parser.add_argument('--stack', dest='stack', action='store', required='true', help='The AWS stack name')
args = parser.parse_args()

asg_name = next(filter(
    lambda x: x['LogicalResourceId'] == 'AutoScalingGroup',
    boto3.client('cloudformation', region_name=args.region) \
        .list_stack_resources(StackName=args.stack)['StackResourceSummaries']
    ))['PhysicalResourceId']

asgs = boto3.client('autoscaling', region_name=args.region) \
    .describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])

instances = [instance['InstanceId'] for instance in asgs['AutoScalingGroups'][0]['Instances']]

public_endpoints = [r['PublicDnsName'] for r in boto3.client('ec2', region_name=args.region) \
    .describe_instances(InstanceIds=instances)['Reservations'][0]['Instances'] if 'PublicDnsName' in r]

instance_url = public_endpoints[0]

print('AWS Instance URL: ' + instance_url)
set_output('AWS_INSTANCE_URL', 'http://' + instance_url)
