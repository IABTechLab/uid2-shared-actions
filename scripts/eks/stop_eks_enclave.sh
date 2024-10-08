if [ -z "${IDENTITY_SCOPE}" ]; then
  echo "IDENTITY_SCOPE can not be empty"
  exit 1
fi

kubectl delete namespace ${IDENTITY_SCOPE,,} --ignore-not-found=true
