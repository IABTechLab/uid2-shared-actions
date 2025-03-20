from cfn_tools import load_yaml, dump_yaml
import argparse
import boto3
import json
import requests

def create_egress(url, description):
    return {
        'IpProtocol': 'tcp',
        'FromPort': get_port(url),
        'ToPort': get_port(url),
        'CidrIp': '0.0.0.0/0',
        'Description': description
    }

def get_port(url):
    return url.split(":")[1]

def create_cloudformation_stack(client, stack_name, cft_content, api_token, dc_cfg, ip_address, env):
    result = client.create_stack(
        StackName=stack_name,
        TemplateBody=cft_content,
        Capabilities=['CAPABILITY_IAM'],
        Parameters=[
            { 'ParameterKey': 'APIToken', 'ParameterValue': api_token },
            { 'ParameterKey': 'DeployToEnvironment', 'ParameterValue': "prod" if env == "prod" else "integ" }, # Mock env also uses integ
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
parser.add_argument('--stack_fp', dest='stack_fp', action='store', required='true', help='The filepath to the AWS stacks')
parser.add_argument('--cftemplate_fp', dest='cftemplate_fp', action='store', required='true', help='The filepath to the CloudFormation template')
parser.add_argument('--core_url', dest='core_url', action='store', required='true', help='The core URL')
parser.add_argument('--optout_url', dest='optout_url', action='store', required='true', help='The optout URL')
parser.add_argument('--localstack_url', dest='localstack_url', action='store', required='true', help='The localstack URL')
parser.add_argument('--region', choices=['us-east-1', 'us-west-1', 'ca-central-1', 'eu-central-1'], dest='region', action='store', required='true', help='The AWS target region')
parser.add_argument('--ami', dest='ami', action='store', required='true', help='The AMI ID')
parser.add_argument('--stack', dest='stack', action='store', required='true', help='The AWS stack name')
parser.add_argument('--scope', choices=['UID', 'EUID'], dest='scope', action='store', required='true', help='The identity scope')
parser.add_argument('--env', choices=['mock', 'integ', 'prod'], dest='env', action='store', required='true', help='The target environment')
parser.add_argument('--key', dest='operator_key', action='store', required='true', help='The operator key')
args = parser.parse_args()

with open('{}/stack.{}.json'.format(args.stack_fp, args.region), 'r') as f:
    dc_cfg = json.load(f)

with open('{}/{}_CloudFormation.template.yml'.format(args.cftemplate_fp, args.scope), 'r') as f:
    cft = load_yaml(f)

cft['Mappings']['RegionMap'][args.region]['AMI'] = args.ami

if args.env == "mock":
    egress = cft['Resources']['SecurityGroup']['Properties']['SecurityGroupEgress']
    egress.append(create_egress(args.core_url, 'E2E - Core'))
    egress.append(create_egress(args.optout_url, 'E2E - Optout'))
    egress.append(create_egress(args.localstack_url, 'E2E - Localstack'))
    cft['Resources']['SecurityGroup']['Properties']['SecurityGroupEgress'] = egress

# Now, we overwrite core, optout URL's with bore addresses.
secrets = cft['Resources']['TokenSecret']['Properties']['SecretString']['Fn::Join'][1]
core_index = secrets.index('"core_base_url": "')
secrets = secrets[:core_index] + secrets[core_index+2:]
optout_index = secrets.index('", "optout_base_url": "')
secrets = secrets[:optout_index] + secrets[optout_index+2:]
secrets = secrets[:1] + [f'"core_base_url": "{args.core_url}"',f', "optout_base_url":  "{args.optout_url}'] + secrets[1:]
secrets.pop()
secrets.extend([', "skip_validations": true', f', "debug_mode": {str(args.env != "prod").lower()}', '}'])
cft['Resources']['TokenSecret']['Properties']['SecretString']['Fn::Join'][1] = secrets

print(dump_yaml(cft))

ip = requests.get('https://ipinfo.io/ip').text.strip()

create_cloudformation_stack(
    boto3.client('cloudformation', region_name=args.region),
    stack_name=args.stack,
    cft_content=dump_yaml(cft),
    api_token=args.operator_key,
    dc_cfg=dc_cfg, 
    ip_address=ip,
    env=args.env)
