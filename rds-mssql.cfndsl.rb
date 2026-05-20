CloudFormation do

  Description "#{component_name} - #{component_version}"
  
  tags = []
  tags << { Key: 'Environment', Value: Ref(:EnvironmentName) }
  tags << { Key: 'EnvironmentType', Value: Ref(:EnvironmentType) }

  extra_tags.each { |key,value| tags << { Key: key, Value: value } } if defined? extra_tags

  ingress = []
  security_group_rules.each do |rule|
    sg_rule = {
      FromPort: 1433,
      IpProtocol: 'TCP',
      ToPort: 1433,
    }
    if rule['security_group_id']
      sg_rule['SourceSecurityGroupId'] = FnSub(rule['security_group_id'])
    else 
      sg_rule['CidrIp'] = FnSub(rule['ip']) 
    end
    if rule['desc']
      sg_rule['Description'] = FnSub(rule['desc'])
    end
    ingress << sg_rule
  end if defined?(security_group_rules)

  EC2_SecurityGroup "SecurityGroupRDS" do
    VpcId Ref('VPCId')
    GroupDescription FnJoin(' ', [ Ref(:EnvironmentName), component_name, 'security group' ])
    SecurityGroupIngress ingress if ingress.any?
    SecurityGroupEgress ([
      {
        CidrIp: "0.0.0.0/0",
        Description: "outbound all for ports",
        IpProtocol: -1,
      }
    ]) 
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'security-group' ])}]
  end
  Output(:SecurityGroup) {
    Value(Ref(:SecurityGroupRDS))
    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-SecurityGroup")
  }


  RDS_DBSubnetGroup 'SubnetGroupRDS' do
    DBSubnetGroupDescription FnJoin(' ', [ Ref(:EnvironmentName), component_name, 'subnet group' ])
    SubnetIds Ref('SubnetIds')
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'subnet-group' ])}]
  end

  RDS_DBParameterGroup 'ParametersRDS' do
    Description FnJoin(' ', [ Ref(:EnvironmentName), component_name, 'parameter group' ])
    Family family
    Parameters parameters if defined? parameters
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'parameter-group' ])}]
  end

  if defined?(native_backup_restore) and native_backup_restore

    IAM_Role('RDSOptionGroupRole') do
      AssumeRolePolicyDocument ({
        Statement: [
          {
            Effect: 'Allow',
            Principal: { Service: [ 'rds.amazonaws.com' ] },
            Action: [ 'sts:AssumeRole' ]
          }
        ]
      })
      Path '/'
      Policies ([
        PolicyName: 'RDSOptionGroupRole',
        PolicyDocument: {
            Statement: [
                {
                    Effect: 'Allow',
                    Action: [
                      's3:ListBucket',
                        's3:GetBucketLocation',
                        's3:GetObjectMetaData',
                        's3:GetObject',
                        's3:PutObject',
                        's3:ListMultipartUploadParts',
                        's3:AbortMultipartUpload'
                    ],
                    Resource: [
                      FnJoin('', ['arn:aws:s3:::', Ref('DatabaseBucket')]),
                      FnJoin('', ['arn:aws:s3:::', Ref('DatabaseBucket'), '/*'])
                    ]
                }
            ]
        }
      ])
    end

    RDS_OptionGroup 'OptionGroupRDS' do
      DeletionPolicy 'Retain'
      EngineName engine
      MajorEngineVersion engine_version[0..4]
      OptionGroupDescription 'MSSQL Native Backup & Restore'
      OptionConfigurations [{
        OptionName: 'SQLSERVER_BACKUP_RESTORE',
        OptionSettings: [{
            Name: 'IAM_ROLE_ARN',
            Value: FnGetAtt('RDSOptionGroupRole','Arn')
        }]
      }]
      Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'option-group' ])}]
    end

  end

  instance_username = defined?(master_username) ? master_username : FnJoin('', [ '{{resolve:ssm:', FnSub(master_login['username_ssm_param']), ':1}}' ])
  instance_password = defined?(master_password) ? master_password : FnJoin('', [ '{{resolve:ssm-secure:', FnSub(master_login['password_ssm_param']), ':1}}' ])

  maintenance_window = external_parameters.fetch(:maintenance_window, nil)
  backup_window = external_parameters.fetch(:backup_window, nil)
  backup_retention_period = external_parameters.fetch(:backup_retention_period, nil)
  allow_major_version_upgrade = external_parameters.fetch(:allow_major_version_upgrade, nil)

  RDS_DBInstance 'RDS' do
    AllowMajorVersionUpgrade allow_major_version_upgrade unless allow_major_version_upgrade.nil?
    DeletionPolicy deletion_policy if defined? deletion_policy
    DBInstanceClass Ref('RDSInstanceType')
    AllocatedStorage Ref('RDSAllocatedStorage')
    StorageType Ref('RDSStorageType')
    Engine engine
    EngineVersion engine_version
    DBParameterGroupName Ref('ParametersRDS')
    MasterUsername  instance_username
    MasterUserPassword instance_password
    DBSnapshotIdentifier  Ref('RDSSnapshotID')
    DBSubnetGroupName  Ref('SubnetGroupRDS')
    VPCSecurityGroups [Ref('SecurityGroupRDS')]
    MultiAZ Ref('MultiAZ')
    PubliclyAccessible publicly_accessible if defined? publicly_accessible
    OptionGroupName Ref('OptionGroupRDS') if defined? native_backup_restore
    CharacterSetName character_set if defined? character_set
    LicenseModel license_model if defined? license_model
    PreferredBackupWindow backup_window unless backup_window.nil?
    PreferredMaintenanceWindow maintenance_window unless maintenance_window.nil?
    BackupRetentionPeriod backup_retention_period unless backup_retention_period.nil?
    Tags  tags + [
      { Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'instance' ])},
      { Key: 'SnapshotID', Value: Ref('RDSSnapshotID')},
      { Key: 'Version', Value: family}
    ]
    Metadata({
      cfn_nag: {
        rules_to_suppress: [
          { id: 'F23', reason: 'ignoring until further action is required' },
          { id: 'F24', reason: 'ignoring until further action is required' }
        ]
      }
    })
    StorageEncrypted storage_encrypted if defined? storage_encrypted
    KmsKeyId kms_key_id if (defined? kms_key_id) && (storage_encrypted == true)
  end

  record = defined?(dns_record) ? dns_record : 'mssql'

  Route53_RecordSet('DatabaseIntHostRecord') do
    HostedZoneName FnJoin('', [ Ref('EnvironmentName'), '.', Ref('DnsDomain'), '.'])
    Name FnJoin('', [ record, '.', Ref('EnvironmentName'), '.', Ref('DnsDomain'), '.' ])
    Type 'CNAME'
    TTL 60
    ResourceRecords [ FnGetAtt('RDS','Endpoint.Address') ]
  end

end