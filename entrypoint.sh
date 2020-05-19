#!/bin/bash
jwt=$(curl -v --silent 'http://'$MANAGER_ADDRESS':9000/api/auth' \
--data '{"username":"'$ADMIN_USER'","password":"'$ADMIN_PASSWORD'"}' --stderr - | grep -o '"jwt": *"[^"]*' | grep -o '[^"]*$')

SERVICE_NAME="portainer-integration-${PORTAINER_PORT:-9100}"
DATA_FOLDER="/tmp/integration/${PORTAINER_PORT:-9100}"

mkdir -pv "${DATA_FOLDER}"

echo "Cleanup environment"

curl 'http://'$MANAGER_ADDRESS':9000/api/endpoints/1/docker/services/'$SERVICE_NAME'' -X DELETE -H 'Authorization: Bearer '$jwt''

rm -rf "${DATA_FOLDER}/*"

echo "Copying Portainer data"

cp -rp /tmp/data/* "${DATA_FOLDER}/"

echo "Deploying Portainer"

curl 'http://'$MANAGER_ADDRESS':9000/api/endpoints/1/docker/services/create' -H 'Authorization: Bearer '$jwt'' --data-raw 
'{
    "Name": "test",
    "TaskTemplate": {
        "ContainerSpec": {
            "Mounts": [
                {
                    "Source": "'${DATA_FOLDER}'",
                    "Target": "/data",
                    "ReadOnly": false,
                    "Type": "bind",
                    "Id": ""
                }
            ],
            "Image": "'${PORTAINER_IMAGE:-portainerci/portainer:develop}'",
            "Args": [
                "-H",
                "tcp://tasks.agent:9001",
                "--tlsskipverify"
            ]
        },
        "Placement": {
            "Constraints": [
                "node.role==manager"
            ]
        }
    },
    "Mode": {
        "Replicated": {
            "Replicas": 1
        }
    },
    "EndpointSpec": {
        "Ports": [
            {
                "Protocol": "tcp",
                "PublishMode": "ingress",
                "TargetPort": 9000,
                "PublishedPort": '${PORTAINER_PORT:-9100}'
            },
            {
                "Protocol": "tcp",
                "PublishMode": "ingress",
                "TargetPort": 8000,
                "PublishedPort": '${PORTAINER_EDGE_PORT:-10000}'
            }
        ]
    },
    "Networks": [
        {
            "Target": "portainer_agent_network"
        }
    ]
}'

exit 0
