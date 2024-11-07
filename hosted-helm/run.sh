#!/bin/bash

set -a

nexusSourceHost="https://source.nexus"
nexusSourceId="admin"
nexusSourcePass="admin123"
nexusDestHost="https://destination.nexus"
nexusDestId="admin"
nexusDestPass="admin123"

echo "Used creds ${nexusDestId}:${nexusDestPass} to access ${nexusDestHost}"

curl -k -s -u "${nexusSourceId}:${nexusSourcePass}" -X GET \
    "${nexusSourceHost}/service/rest/v1/repositories" \
    -H "accept: application/json" > repos.json

jq -c '.[]' repos.json | while read -r repos; do
    repoType=$(jq -r '.type' <<< "$repos")
    repoFormat=$(jq -r '.format' <<< "$repos")
    repoName=$(jq -r '.name' <<< "$repos")
    if [[ "$repoType" == "hosted" ]] && [[ "$repoFormat" == "helm" ]]; then
        echo "$repoName"
        curl -k -s -u "${nexusSourceId}:${nexusSourcePass}" -X GET \
            "${nexusSourceHost}/service/rest/v1/search/assets?repository=${repoName}" \
            -H "accept: application/json" > "${repoName}.json"

        repoDestUrl="${nexusDestHost}/service/rest/v1/components?repository=${repoName}"
        echo "$repoDestUrl"
        jq -c '.items[]' "${repoName}.json" | while read -r components; do
            componentDownloadUrl=$(jq -r '.downloadUrl' <<< "$components")
            componentPath=$(jq -r '.path' <<< "$components")

            echo "${componentDownloadUrl}"
            curl -k -s -o "${componentPath}" \
                -u "${nexusSourceId}:${nexusSourcePass}" \
                -X GET -L "${componentDownloadUrl}"
            envsubst < deploy.sh.base > deploy.sh
            echo "Deploy params: Path: ${componentPath}"
            chmod +x deploy.sh
            ./deploy.sh
            echo "$repoDestUrl"
            rm -rf "${componentPath}"
        done
        rm -rf "${repoName}.json"
    fi
done

rm -rf repos.json
rm -rf deploy.sh
rm -rf ./*.tgz
