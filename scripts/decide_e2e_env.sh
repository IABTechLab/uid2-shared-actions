if [ -z "${GITHUB_OUTPUT}" ]; then
    echo "Not in GitHub action"
    exit 1
fi

if [ -z "${OPERATOR_TYPE}" ]; then
    echo "OPERATOR_TYPE not set"
    exit 1
elif [ "${OPERATOR_TYPE}" == "public" ]; then
    echo "uid2_e2e_pipeline_operator_type=PUBLIC" >> ${GITHUB_OUTPUT}
    echo "uid2_e2e_pipeline_operator_url=http://publicoperator:8080" >> ${GITHUB_OUTPUT}
    echo "uid2_e2e_pipeline_operator_cloud_provider=PUBLIC" >> ${GITHUB_OUTPUT}
    echo "uid2_e2e_pipeline_core_url=http://core:8088" >> ${GITHUB_OUTPUT}
    echo "uid2_e2e_pipeline_optout_url=http://optout:8081" >> ${GITHUB_OUTPUT}
elif [ "${OPERATOR_TYPE}" == "eks" ]; then
    echo "uid2_e2e_pipeline_operator_type=PRIVATE" >> ${GITHUB_OUTPUT}

    echo "uid2_e2e_pipeline_operator_url=http://publicoperator:8080" >> ${GITHUB_OUTPUT}
    echo "uid2_e2e_pipeline_operator_cloud_provider=PUBLIC" >> ${GITHUB_OUTPUT}
    
    echo "uid2_e2e_pipeline_core_url=http://${BORE_URL_CORE}" >> ${GITHUB_OUTPUT}
    echo "uid2_e2e_pipeline_optout_url=http://${BORE_URL_OPTOUT}" >> ${GITHUB_OUTPUT}
else
    echo "uid2_e2e_pipeline_operator_type=PRIVATE" >> ${GITHUB_OUTPUT}
    if [ "${OPERATOR_TYPE}" == "gcp" ]; then
        echo "uid2_e2e_pipeline_operator_cloud_provider=GCP" >> ${GITHUB_OUTPUT}
        echo "uid2_e2e_pipeline_operator_url=${GCP_OPERATOR_URL}" >> ${GITHUB_OUTPUT}
    elif [ "${OPERATOR_TYPE}" == "azure" ]; then
        echo "uid2_e2e_pipeline_operator_cloud_provider=AZURE" >> ${GITHUB_OUTPUT}
        echo "uid2_e2e_pipeline_operator_url=${AZURE_OPERATOR_URL}" >> ${GITHUB_OUTPUT}
    elif [ "${OPERATOR_TYPE}" == "aws" ]; then
        echo "uid2_e2e_pipeline_operator_cloud_provider=AWS" >> ${GITHUB_OUTPUT}
        echo "uid2_e2e_pipeline_operator_url=${AWS_OPERATOR_URL}" >> ${GITHUB_OUTPUT}
    fi
    echo "uid2_e2e_pipeline_core_url=http://${BORE_URL_CORE}" >> ${GITHUB_OUTPUT}
    echo "uid2_e2e_pipeline_optout_url=http://${BORE_URL_OPTOUT}" >> ${GITHUB_OUTPUT}
fi

if [ -z "${IDENTITY_SCOPE}" ]; then
    echo "IDENTITY_SCOPE not set"
    exit 1
elif [ "${IDENTITY_SCOPE}" == "UID2" ]; then
    echo "uid2_e2e_phone_support=true" >> ${GITHUB_OUTPUT}
elif [ "${IDENTITY_SCOPE}" == "EUID" ]; then
    echo "uid2_e2e_phone_support=false" >> ${GITHUB_OUTPUT}
fi