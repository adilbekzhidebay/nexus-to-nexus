#!/bin/bash

set -a

nexusSourceHost="https://source.nexus"
nexusSourceId="admin"
nexusSourcePass="admin123"
nexusDestHost="https://destination.nexus"
nexusDestId="admin"
nexusDestPass="admin123"

echo "Used creds ${nexusDestId}:${nexusDestPass} to access ${nexusDestHost}"
envsubst < settings.xml.base > settings.xml

curl -k -s -u "${nexusSourceId}:${nexusSourcePass}" -X GET \
    "${nexusSourceHost}/service/rest/v1/repositories" \
    -H "accept: application/json" > repos.json

jq -c '.[]' repos.json | while read -r repos; do
    repoType=$(jq -r '.type' <<< "$repos")
    repoFormat=$(jq -r '.format' <<< "$repos")
    repoName=$(jq -r '.name' <<< "$repos")
    if [[ "$repoType" == "hosted" ]] && [[ "$repoFormat" == "maven2" ]]; then
        echo "$repoName"
        curl -k -s -u "${nexusSourceId}:${nexusSourcePass}" -X GET \
            "${nexusSourceHost}/service/rest/v1/search/assets?repository=${repoName}" \
            -H "accept: application/json" > "${repoName}.json"

        repoDestUrl="${nexusDestHost}/repository/${repoName}/"
        echo "$repoDestUrl"
        jq -c '.items[]' "${repoName}.json" | while read -r components; do
            componentDownloadUrl=$(jq -r '.downloadUrl' <<< "$components")
            componentExtension=$(jq -r '.maven2.extension' <<< "$components")
            componentGroupId=$(jq -r '.maven2.groupId' <<< "$components")
            componentArtifactId=$(jq -r '.maven2.artifactId' <<< "$components")
            componentVersion=$(jq -r '.maven2.version' <<< "$components")
            componentClassifier=$(jq -r '.maven2.classifier' <<< "$components")
            echo "${componentDownloadUrl}"

            case $componentExtension in
              jar|module|pom|zip)
                curl -k -s -o "${componentArtifactId}.$componentExtension" \
                    -u "${nexusSourceId}:${nexusSourcePass}" \
                    -X GET -L "${componentDownloadUrl}"

                if [ "$componentClassifier" = "null" ]; then
                    dComponentClassifier=""
                else
                    dComponentClassifier="-Dclassifier=${componentClassifier}"
                fi
                envsubst < deploy.sh.base > deploy.sh
                echo "Deploy params: groupId: ${componentGroupId} version: ${componentVersion}"
                chmod +x deploy.sh
                ./deploy.sh
                echo "${dComponentClassifier}"
                echo "${componentArtifactId}"
                rm -rf "${componentArtifactId}.*"
                ;;

              *)
                echo "no"
                ;;
            esac
        done
        rm -rf "${repoName}.json"
    fi
done

rm -rf settings.xml
rm -rf repos.json
rm -rf deploy.sh
rm -rf ./*.jar
rm -rf ./*.module
rm -rf ./*.zip
rm -rf ./*.pom
