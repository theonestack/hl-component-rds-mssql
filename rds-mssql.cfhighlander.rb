CfhighlanderTemplate do

    Name 'rds-mssql'
    Description "#{component_name} - #{component_version}"
    
    ComponentVersion component_version
    DependsOn 'vpc'
    DependsOn 'lib-iam'
    Parameters do
      ComponentParam 'VPCId', type: 'AWS::EC2::VPC::Id'
      ComponentParam 'StackOctet', isGlobal: true
      ComponentParam 'RDSSnapshotID'
      ComponentParam 'MultiAZ', 'false', allowedValues: ['true','false']
      ComponentParam 'EnvironmentName', 'dev', isGlobal: true
      ComponentParam 'EnvironmentType', 'development', isGlobal: true, allowedValues: ['development', 'production']
      ComponentParam 'RDSInstanceType'
      ComponentParam 'RDSAllocatedStorage'
      ComponentParam 'DnsDomain'
      ComponentParam 'SubnetIds', type: 'CommaDelimitedList'
      ComponentParam 'DatabaseBucket' if defined?(native_backup_restore) and native_backup_restore
    end

    LambdaFunctions 'tg_custom_resources' unless disable_custom_resources

end

