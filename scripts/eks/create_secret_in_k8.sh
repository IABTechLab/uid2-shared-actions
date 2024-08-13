source "uid2-shared-actions/scripts/jq_helper.sh"

ENCLAVE_PROTOCOL="aws-nitro"
# OPERATOR_FILE="${METADATA_ROOT}/operators/operators.json"
# # Fetch operator key
# OPERATOR_KEY=$(jq -r '.[] | select(.protocol=="'${ENCLAVE_PROTOCOL}'") | .key' ${OPERATOR_FILE})
OPERATOR_KEY="test-operator-key"

SECRET_JSON_FILE="uid2-shared-actions/scripts/eks/secret.json"

jq_string_update ${SECRET_JSON_FILE} core_base_url "http://${BORE_URL_CORE}"
jq_string_update ${SECRET_JSON_FILE} optout_base_url "http://${BORE_URL_OPTOUT}"
jq_string_update ${SECRET_JSON_FILE} api_token "${OPERATOR_KEY}"

kubectl create secret generic github-test-secret --from-file=config=uid2-shared-actions/scripts/eks/secret.json