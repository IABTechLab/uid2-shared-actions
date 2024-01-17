from cfn_tools import load_yaml, dump_yaml
import argparse
import boto3
import json
import requests

def create_cloudformation_stack(client, stack_name, cft_content, api_token, dc_cfg, ip_address):
    result = client.create_stack(
        StackName=stack_name,
        TemplateBody=cft_content,
        Capabilities=['CAPABILITY_IAM'],
        Parameters=[
            { 'ParameterKey': 'APIToken', 'ParameterValue': api_token },
            { 'ParameterKey': 'DeployToEnvironment', 'ParameterValue': 'integ' },
            { 'ParameterKey': 'VpcId', 'ParameterValue': dc_cfg['VpcId'] },
            { 'ParameterKey': 'VpcSubnet1', 'ParameterValue': dc_cfg['VpcSubnet1'] },
            { 'ParameterKey': 'VpcSubnet2', 'ParameterValue': dc_cfg['VpcSubnet2'] },
            { 'ParameterKey': 'SSHKeyName', 'ParameterValue': dc_cfg['SSHKeyName'] },
            { 'ParameterKey': 'TrustNetworkCidr', 'ParameterValue': ip_address + '/32' },
        ],
        OnFailure='DO_NOTHING')
    waiter = client.get_waiter('stack_create_complete')
    waiter.wait(StackName=stack_name)
    return result

parser = argparse.ArgumentParser()
parser.add_argument('--core', dest='core_url', action='store', required='true', help='The core URL')
parser.add_argument('--optout', dest='optout_url', action='store', required='true', help='The optout URL')
parser.add_argument('--region', choices=['us-east-1', 'us-west-1', 'ca-central-1'], dest='region', action='store', required='true', help='The target region')
parser.add_argument('--ami', dest='ami_id', action='store', required='true', help='The AMI ID')
parser.add_argument('--stack', dest='stack', action='store', required='true', help='The AWS stack name')
parser.add_argument('--key', dest='operator_key', action='store', required='true', help='The operator key')
args = parser.parse_args()

with open("{}stacks/stack.{}.json".format(args.stack_filepath, args.region), 'r') as f:
    dc_cfg = json.load(f)

with open("{}scripts/aws/UID_CloudFormation.template.yml".format(args.operator_repo_filepath), 'r') as f:
    cft = load_yaml(f)

cft['Mappings']['RegionMap'][args.region]['AMI'] = args.ami

user_data = cft['Resources']['LaunchTemplate']['Properties']['LaunchTemplateData']['UserData']['Fn::Base64']['Fn::Sub']
cft['Resources']['LaunchTemplate']['Properties']['LaunchTemplateData']['UserData']['Fn::Base64']['Fn::Sub'] = user_data + '''
export CORE_BASE_URL={}
export OPTOUT_BASE_URL={}
export ENFORCE_HTTPS=false
'''.format(args.core_url, args.optout_url)

ip = requests.get('https://ipinfo.io/ip').text.strip()

create_cloudformation_stack(
    boto3.client('cloudformation', region_name=args.region),
    stack_name=args.stack,
    cft_content=dump_yaml(cft),
    api_token=args.key,
    dc_cfg=dc_cfg, 
    ip_address=ip)
