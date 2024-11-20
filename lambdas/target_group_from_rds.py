import os
import sys
import json
import logging
import boto3

sys.path.append(f"{os.environ['LAMBDA_TASK_ROOT']}/lib")
sys.path.append(os.path.dirname(os.path.realpath(__file__)))

import cfnresponse
          
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_instance_id_by_name(instance_name):
    # Create an EC2 client
    print(f"instance_name: {instance_name}")
    ec2 = boto3.client('ec2')

    # Describe instances with filters for the 'Name' tag
    response = ec2.describe_instances(
        Filters=[
            {
                'Name': 'tag:Name',
                'Values': [instance_name]
            }
        ]
    )

    # Extract instance ID(s)
    instances = response['Reservations']
    instance_ids = []

    for reservation in instances:
        for instance in reservation['Instances']:
            instance_ids.append(instance['InstanceId'])

    if not instance_ids:
        print(f"No instances found with name {instance_name}")
        return None

    # if len(instance_ids) > 1:
    #     print(f"More than one instance found with name {instance_name}")
    #     return None

    return instance_ids

def lambda_handler(event, context):
    logger.info('got event {}'.format(event))  
    try: 
        responseData = {}
        if event['RequestType'] == 'Delete':
            logger.info('Incoming RequestType: Delete operation') 
            cfnresponse.send(event, context, cfnresponse.SUCCESS, {})
        if event['RequestType'] in ["Create", "Update"]:                      
            ResourceRef=event['ResourceProperties']['RDSInstanceId']
            ec2_name = 'do-not-delete-rds-custom-' + ResourceRef
            response = get_instance_id_by_name(ec2_name)

            logger.info(f'found instance:{response}')

            responseData = {}
            formatted_list = ",".join(response)
            responseData['Ec2InstanceId'] = formatted_list
            logger.info('Retrieved Ec2InstanceId! ')
            cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData)
        else:
            logger.info('Unexpected RequestType!') 
            cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData)
    except Exception as err:
        logger.error(err)
        responseData = {"Data": str(err)}
        cfnresponse.send(event,context,cfnresponse.FAILED,responseData)
    return              