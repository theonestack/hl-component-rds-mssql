# rds-mssql CfHighlander component

## Parameters

| Name | Use | Default | Global | Type | Allowed Values |
| ---- | --- | ------- | ------ | ---- | -------------- |
| EnvironmentName | Tagging | dev | true | string
| EnvironmentType | Tagging | development | true | string | ['development','production']
| SubnetIds | List of subnets | None | false | CommaDelimitedList
| RDSInstanceType | RDS Instance Type to use | None | false | string
| RDSAllocatedStorage | Amount of storage in GB to assign | None | false | string
| RDSStorageType | The storage type for the RDS instance | gp2 | false | string | ['gp2','gp3','io1','standard']
| DnsDomain | DNS domain to use | None | true | string
| DatabaseBucket | Used when *native_backup_restore* is specified, defines the bucket to use | None | false | string
| MultiAZ | Specifies whether the database instance is a multiple Availability Zone deployment  | false | false | ['true','false']
| RDSSnapshotID | The name or Amazon Resource Name (ARN) of the DB snapshot that's used to restore the DB instance | false | false | string

## Outputs/Exports

| Name | Value | Exported |
| ---- | ----- | -------- |
| SecurityGroup | Security Group Name | true

## Included Components

[lib-ec2](https://github.com/theonestack/hl-component-lib-ec2)
[lib-iam](https://github.com/theonestack/hl-component-lib-iam)

## Example Configuration
### Highlander
```
  Component name:'database', template: 'rds-mssql' do
    parameter name: 'DnsDomain', value: root_domain
    parameter name: 'DnsFormat', value: FnSub("${EnvironmentName}.#{root_domain}")
    parameter name: 'SubnetIds', value: cfout('vpcv2', 'PersistenceSubnets')
    parameter name: 'RDSInstanceType', value: 'db.m5.large'
    parameter name: 'MultiAZ', value: 'false'
    parameter name: 'StackOctet', value: '120'
    parameter name: 'RDSAllocatedStorage', value: '100'
    parameter name: 'NamespaceId', value: cfout('servicediscovery', 'NamespaceId')
  end

```

### RDS-MSSQL Configuration

```
engine: 'sqlserver-se'
engine_version: '15.00.4073.23.v1'
family: 'sqlserver-se-15.0'
dns_record: db
deletion_policy: Snapshot
native_backup_restore: true

license_model: license-included
storage_encrypted: true
maintenance_window: sat:18:00-sat:18:30
backup_window: 16:00-17:00
backup_retention_period: 10

security_group:
  -
    rules:
      -
        IpProtocol: tcp
        FromPort: 1433
        ToPort: 1433
    ips:
      - stack

master_login:
  username_ssm_param: /project/rds/RDS_MASTER_USERNAME
  password_ssm_param: /project/rds/RDS_MASTER_PASSWORD

service_discovery:
  name: db
```

## Cfhighlander Setup

install cfhighlander [gem](https://github.com/theonestack/cfhighlander)

```bash
gem install cfhighlander
```

or via docker

```bash
docker pull theonestack/cfhighlander
```
## Testing Components

Running the tests

```bash
cfhighlander cftest rds-mssql
```