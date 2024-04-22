#!/usr/bin/env bash

# variable definitions
username="bucket_user"
password="password"
host="localhost"
port="8091"

# bucket names
offline_writes="offline-writes"
offline_reads="offline-reads"
meta="meta"

# Initialize cluster
function init_cluster(){
    couchbase-cli cluster-init -c $host:$port --cluster-username $username --cluster-password $password --cluster-port $port --services data,index,query,fts,eventing --cluster-ramsize 3070
    if [[ $? != 0 ]]; then
        echo "Error: Cluster init failed." >&2
        exit 1
    else
        sleep 4s
        echo "Cluster initialized successfully."
    fi
}

# Create bucket function
function create_bucket(){
    bucket_name=$1
    couchbase-cli bucket-create -c $host:$port --username $username --password $password --bucket=$bucket_name --bucket-type=couchbase --bucket-ramsize=1000 --bucket-replica=0 --wait
    if [[ $? != 0 ]]; then
        echo "Error: Bucket creation failed." >&2
        return 1
    fi

    echo "SUCCESS: Bucket, $bucket_name, created successfully"
}

# create the index and wait until it is created
function create_index() {
    script=$1
    cbq -e http://$host:8093 -u $username -p $password --script="$script"
    if [[ $? != 0 ]]; then
        echo "Error: Index creation failed." >&2
        return 1
    else
        echo "Index created successfully"
    fi
}

/entrypoint.sh couchbase-server &
if [[ $? != 0 ]]; then
    echo "Couchbase startup failed. Exiting." >&2
    exit 1
fi

# wait for service to come up
until $(curl --output /dev/null --silent --head --fail http://$host:$port); do
    sleep 10
done

if couchbase-cli server-list -c $host:$port --username $username --password $password ; then
    echo "Couchbase already initialized, skipping initialization"
else
    # Initialize cluster
    init_cluster

    # Create buckets
    create_bucket $offline_reads
    create_bucket $offline_writes
    create_bucket $meta

    # Wait for 15 seconds
    sleep 15

    # Create Indices
    create_index 'CREATE PRIMARY INDEX `#primary` ON `offline-writes`'
    create_index 'CREATE INDEX `idx_users` ON `offline-reads`((meta().`id`)) PARTITION BY hash((meta().`id`))'
    create_index 'CREATE PRIMARY INDEX `#primary` ON `meta`'

    # offline-reads scopes and collections
    create_index 'CREATE SCOPE `offline-reads`.`rwanda` IF NOT EXISTS'
    create_index 'CREATE COLLECTION `offline-reads`.`rwanda`.`fineractclients` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`rwanda`.`fineractgroups` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`rwanda`.`fineractloans` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`rwanda`.`fineractrepayments` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`rwanda`.`fineracthealthypaths` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`rwanda`.`odooorders` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`rwanda`.`odoooffers` IF NOT EXISTS;'

    create_index 'CREATE SCOPE `offline-reads`.`kenya` IF NOT EXISTS'
    create_index 'CREATE COLLECTION `offline-reads`.`kenya`.`fineractclients` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`kenya`.`fineractgroups` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`kenya`.`fineractloans` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`kenya`.`fineractrepayments` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`kenya`.`fineracthealthypaths` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`kenya`.`odooorders` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`kenya`.`odoooffers` IF NOT EXISTS;'

    create_index 'CREATE SCOPE `offline-reads`.`zambia` IF NOT EXISTS'
    create_index 'CREATE COLLECTION `offline-reads`.`zambia`.`fineractclients` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`zambia`.`fineractgroups` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`zambia`.`fineractloans` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`zambia`.`fineractrepayments` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`zambia`.`fineracthealthypaths` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`zambia`.`odooorders` IF NOT EXISTS;'
    create_index 'CREATE COLLECTION `offline-reads`.`zambia`.`odoooffers` IF NOT EXISTS;'

    # offline-writes scopes and collections
    create_index 'CREATE SCOPE `offline-writes`.`rwanda` IF NOT EXISTS'
    create_index 'CREATE COLLECTION `offline-writes`.`rwanda`.`api-requests` IF NOT EXISTS;'

    create_index 'CREATE SCOPE `offline-writes`.`kenya` IF NOT EXISTS'
    create_index 'CREATE COLLECTION `offline-writes`.`kenya`.`api-requests` IF NOT EXISTS;'

    create_index 'CREATE SCOPE `offline-writes`.`zambia` IF NOT EXISTS'
    create_index 'CREATE COLLECTION `offline-writes`.`zambia`.`api-requests` IF NOT EXISTS;'
fi

# entrypoint.sh launches the server but since config.sh is pid 1 we keep it
# running so that the docker container does not exit.
wait
