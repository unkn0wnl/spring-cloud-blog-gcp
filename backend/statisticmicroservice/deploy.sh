#!/bin/bash

#check inital variables
[ -z "$project" ] && echo "Var project is empty. Please set var project. For example:\n\texport project=your-projects-id"
[ -z "$cluster" ] && echo "Var cluster is empty. Please set var cluster. For example:\n\texport cluster=application"
[ -z "$zone" ] && echo "Var zone is empty. Please set var zone. For example:\n\texport zone=europe-west1"


microservice=statistic-microservice
jarfile=build/libs/statisticmicroservice-0.0.1-SNAPSHOT.jar

echo ### create service account and secret ###
gcloud iam service-accounts create $microservice
gcloud projects add-iam-policy-binding $project --member serviceAccount:$microservice@$project.iam.gserviceaccount.com --role roles/pubsub.admin
gcloud projects add-iam-policy-binding $project --member serviceAccount:$microservice@$project.iam.gserviceaccount.com --role roles/datastore.owner
gcloud iam service-accounts keys create --iam-account $microservice@$project.iam.gserviceaccount.com $microservice-credentials.json
kubectl create secret generic statistic-secret --from-file=credentials.json=$microservice-credentials.json

# create docker file
docker build -t eu.gcr.io/$project/$microservice:latest --build-arg JAR_FILE=$jarfile .

# push docker file
docker push eu.gcr.io/$project/$microservice:latest

# generate kubernetes files from templates
mkdir -p kubernetes/generated
sed "s/PROJECT_NAME/$project/g" kubernetes/template/deployment.yaml > kubernetes/generated/deployment.yaml
yes | cp kubernetes/template/service.yaml kubernetes/generated

RANDOM_STRING=$(cat /dev/urandom | tr -dc "a-zA-Z0-9" | fold -w 32 | head -n 1)

kubectl apply -f kubernetes/generated/
kubectl patch deployment $microservice -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"modified\":\"$RANDOM_STRING\"}}}}}"
