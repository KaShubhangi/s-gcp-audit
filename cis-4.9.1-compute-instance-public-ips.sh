#!/bin/bash

PROJECT_IDS="";
DEBUG="False";
HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 		set -- "$@" "-h" ;;
    "--debug") 		set -- "$@" "-d" ;;
    "--project")   	set -- "$@" "-p" ;;
    *)        		set -- "$@" "$arg"
  esac
done

while getopts "hdp:" option
do 
    case "${option}"
        in
        p)
        	PROJECT_IDS=${OPTARG};;
        d)
        	DEBUG="True";;
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

for PROJECT_ID in $PROJECT_IDS; do	
	gcloud config set project $PROJECT_ID;
	declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

	if [[ $INSTANCES != "[]" ]]; then

		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');
		
		echo "---------------------------------------------------------------------------------";
		echo "Instances for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";

		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do

			NAME=$(echo $INSTANCE | jq -rc '.name');			
			EXTERNAL_NETWORK_INTERFACES=$(echo $INSTANCE | jq -rc '.networkInterfaces' | jq 'select("accessConfigs")');
			IS_GKE_NODE=$(echo $INSTANCE | jq '.labels' | jq 'has("goog-gke-node")');
		
			echo $EXTERNAL_NETWORK_INTERFACES | jq -rc '.[]' | while IFS='' read -r INTERFACE;do

				HAS_NAT_IP=$(echo $INTERFACE | jq -rc '.accessConfigs // empty');

				if [[ $HAS_NAT_IP != "" ]]; then
					
					INTERFACE_NAME=$(echo $INTERFACE | jq -rc '.name');
					NAT_IP=$(echo $INTERFACE | jq -rc '.accessConfigs[].natIP');

					echo "Project Name: $PROJECT_NAME";
					echo "Project Application: $PROJECT_APPLICATION";
					echo "Project Owner: $PROJECT_OWNER";
					echo "Instance Name: $NAME";
					echo "Interface Name: $INTERFACE_NAME";
					echo "IP Address: $NAT_IP";
					if [[ $IS_GKE_NODE == "false" ]]; then
						echo "VIOLATION: Exterally routable IP address detected";
					else
						echo "VIOLATION: GKE cluster is not a Private Kubernetes Cluster";
					fi;
					echo "";
				else
					echo "Skipping interface with no external IP address";
				fi;
			done;
		done;
		echo "";
	else
		echo "No instances found for Project $PROJECT_ID";
		echo "";
	fi;
	sleep 0.5;
done;

