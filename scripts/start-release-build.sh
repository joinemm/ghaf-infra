#!/usr/bin/env bash

set -e

GITREF=ghaf-24.09.2
CONTROLLER=ghaf-jenkins-controller-release.northeurope.cloudapp.azure.com
JOB=ghaf-release-pipeline

cd terraform || exit
./terraform-init.sh -w release
terraform apply -var="convince=true" --auto-approve

echo ""
echo "Waiting for Jenkins to come online..."
while [[ $(curl -s -w "%{http_code}" https://$CONTROLLER -o /dev/null) != "200" ]]; do
    sleep 5
    echo -n "."
done

ssh-keygen -R "$CONTROLLER"

# shellcheck disable=SC2029
ssh -o StrictHostKeyChecking=no "$CONTROLLER" "
    set -e
    AUTH=admin:\$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
    jenkins-cli -auth \$AUTH build $JOB -w
    sleep 2
    jenkins-cli -auth \$AUTH stop-builds $JOB 
    sleep 2
    jenkins-cli -auth \$AUTH build $JOB -p GITREF=$GITREF -w
    "

echo ""
echo "Build started at https://$CONTROLLER/job/$JOB"
