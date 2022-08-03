#!/bin/bash

LONG=project:
SHORT=p:
OPTS=$(getopt -a -n testscript --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"
while :
do
    case "$1" in --project | -p )
        declare PROJECT_IDS="$2"
        shift 2
     ;;
     -- )
        shift;
        break
        ;;
        *)
        exit 2
    esac
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

for PROJECT_ID in $PROJECT_IDS; do
    PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
	PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
	PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');

	gcloud config set project $PROJECT_ID;
	declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

	if [[ $INSTANCES != "[]" ]]; then
	
		echo "---------------------------------------------------------------------------------";
		echo "Instances for Project $PROJECT_ID";
        echo "Project Application: $PROJECT_APPLICATION";
	    echo "Project Owner: $PROJECT_OWNER";
		echo "---------------------------------------------------------------------------------";

		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do

			NAME=$(echo $INSTANCE | jq -rc '.name');
			SHIELDED_INSTANCE_CONFIG=$(echo $INSTANCE | jq -rc '.shieldedInstanceConfig');
			ENABLE_INTEGRITY_MONITORING=$(echo $INSTANCE | jq -rc '.shieldedInstanceConfig.enableIntegrityMonitoring' | tr '[:upper:]' '[:lower:]');
			ENABLE_SECURE_BOOT=$(echo $INSTANCE | jq -rc '.shieldedInstanceConfig.enableSecureBoot' | tr '[:upper:]' '[:lower:]');
			ENABLE_VTPM=$(echo $INSTANCE | jq -rc '.shieldedInstanceConfig.enableVtpm' | tr '[:upper:]' '[:lower:]');
						
			if [[ $SHIELDED_INSTANCE_CONFIG =~ "false" ]]; then
				echo "Instance Name: $NAME";
				echo "Shielded instance Configuration: $SHIELDED_INSTANCE_CONFIG";
				if [[ $ENABLE_INTEGRITY_MONITORING == "false" ]]; then
					echo "VIOLATION: Integrity monitoring is not enabled";
				fi;
				if [[ $ENABLE_SECURE_BOOT == "false" ]]; then
					echo "VIOLATION: Secure boot is not enabled";
				fi;
				if [[ $ENABLE_VTPM == "false" ]]; then
					echo "VIOLATION: Virtual TPM is not enabled";
				fi;
				echo "";
			fi;
		done;
		echo "";
	else
		echo "No instances found for Project $PROJECT_ID";
		echo "";
	fi;
	sleep 0.5;
done;

