#!/usr/bin/env bash

if [ -z "${GITHUB_OUTPUT}" ]; then
    echo "Not in GitHub action"
    exit 1
fi

if [ -z "${OPERATOR_TYPE}" ]; then
    echo "OPERATOR_TYPE can not be empty"
    exit 1
fi

if [ -z "${IDENTITY_SCOPE}" ]; then
    echo "IDENTITY_SCOPE can not be empty"
    exit 1
fi

if [ -z "${TARGET_ENVIRONMENT}" ]; then
    echo "TARGET_ENVIRONMENT can not be empty"
    exit 1
fi

if [ "${TARGET_ENVIRONMENT}" == "mock" ]; then
    echo "e2e_network=e2e_default" >> ${GITHUB_OUTPUT}
else
    echo "e2e_network=bridge" >> ${GITHUB_OUTPUT}
fi

if [ "${OPERATOR_TYPE}" == "public" ]; then
    echo "e2e_suites=E2ECoreTestSuite,E2EPublicOperatorTestSuite" >> ${GITHUB_OUTPUT}
    echo "e2e_env=github-test-pipeline-local" >> ${GITHUB_OUTPUT}
    echo "uid2_core_e2e_core_url=http://core:8088" >> ${GITHUB_OUTPUT}
    echo "uid2_core_e2e_optout_url=http://optout:8081" >> ${GITHUB_OUTPUT}
    echo "uid2_pipeline_e2e_core_url=http://core:8088" >> ${GITHUB_OUTPUT}
    echo "uid2_pipeline_e2e_operator_url=http://publicoperator:8080" >> ${GITHUB_OUTPUT}
    echo "uid2_pipeline_e2e_operator_type=PUBLIC" >> ${GITHUB_OUTPUT}
    echo "uid2_pipeline_e2e_operator_cloud_provider=PUBLIC" >> ${GITHUB_OUTPUT}
else
    echo "uid2_pipeline_e2e_operator_type=PRIVATE" >> ${GITHUB_OUTPUT}

    if [ "${TARGET_ENVIRONMENT}" == "mock" ]; then
        echo "e2e_suites=E2ECoreTestSuite,E2EPrivateOperatorTestSuite" >> ${GITHUB_OUTPUT}
        echo "e2e_env=github-test-pipeline-local" >> ${GITHUB_OUTPUT}
        echo "uid2_core_e2e_core_url=${BORE_URL_CORE}" >> ${GITHUB_OUTPUT}
        echo "uid2_core_e2e_optout_url=${BORE_URL_OPTOUT}" >> ${GITHUB_OUTPUT}
        echo "uid2_pipeline_e2e_core_url=${BORE_URL_CORE}" >> ${GITHUB_OUTPUT}
    else
        echo "e2e_suites=E2EPrivateOperatorTestSuite" >> ${GITHUB_OUTPUT}
        echo "e2e_env=github-test-pipeline" >> ${GITHUB_OUTPUT}
    fi

    if [ "${OPERATOR_TYPE}" == "gcp" ]; then
        echo "uid2_pipeline_e2e_operator_url=${GCP_OPERATOR_URL}" >> ${GITHUB_OUTPUT}
        echo "uid2_pipeline_e2e_operator_cloud_provider=GCP" >> ${GITHUB_OUTPUT}
    elif [ "${OPERATOR_TYPE}" == "azure" ]; then
        echo "uid2_pipeline_e2e_operator_url=${AZURE_OPERATOR_URL}" >> ${GITHUB_OUTPUT}
        echo "uid2_pipeline_e2e_operator_cloud_provider=AZURE" >> ${GITHUB_OUTPUT}
    elif [ "${OPERATOR_TYPE}" == "aws" ]; then
        echo "uid2_pipeline_e2e_operator_url=${AWS_OPERATOR_URL}" >> ${GITHUB_OUTPUT}
        echo "uid2_pipeline_e2e_operator_cloud_provider=AWS" >> ${GITHUB_OUTPUT}
    elif [ "${OPERATOR_TYPE}" == "aks" ]; then
        echo "uid2_pipeline_e2e_operator_url=${AKS_OPERATOR_URL}" >> ${GITHUB_OUTPUT}
        echo "uid2_pipeline_e2e_operator_cloud_provider=AZURE" >> ${GITHUB_OUTPUT}
    fi
fi

if [ "${IDENTITY_SCOPE}" == "UID2" ]; then
    echo "e2e_phone_support=true" >> ${GITHUB_OUTPUT}
elif [ "${IDENTITY_SCOPE}" == "EUID" ]; then
    echo "e2e_phone_support=false" >> ${GITHUB_OUTPUT}
fi
