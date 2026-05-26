CfhighlanderTemplate do

    Name 'rds-mssql'
    Description "#{component_name} - #{component_version}"
    
    ComponentVersion component_version
  
    Parameters do
      ComponentParam 'VPCId', type: 'AWS::EC2::VPC::Id'
      ComponentParam 'StackOctet', isGlobal: true
      ComponentParam 'RDSSnapshotID'
      ComponentParam 'MultiAZ', 'false', allowedValues: ['true','false']
      ComponentParam 'EnvironmentName', 'dev', isGlobal: true
      ComponentParam 'EnvironmentType', 'development', isGlobal: true, allowedValues: ['development', 'production']
      ComponentParam 'RDSInstanceType'
      ComponentParam 'RDSAllocatedStorage'
      ComponentParam 'RDSStorageType', 'gp2', allowedValues: ['gp2', 'gp3', 'io1', 'standard']
      ComponentParam 'RDSIops', 3000, type: 'Number'
      ComponentParam 'DnsDomain'
      ComponentParam 'SubnetIds', type: 'CommaDelimitedList'
      ComponentParam 'DatabaseBucket' if defined?(native_backup_restore) and native_backup_restore
    end
end

