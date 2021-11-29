#!/bin/bash
set -ex

# Install ack
curl https://beyondgrep.com/ack-2.22-single-file >/usr/local/bin/ack && chmod 0755 /usr/local/bin/ack

hash ack 2>/dev/null || {
    echo >&2 "ack required, but it's not installed."
    exit 1
}

APP_NAME_INPUT=${kobiton_app_name}
APP_PATH_INPUT=${kobiton_app_path}
APP_ID_INPUT=${kobiton_app_id}
KOB_USERNAME_INPUT=${kobiton_user_name}
KOB_APIKEY_INPUT=${kobiton_api_key}
APP_SUFFIX_INPUT=${kobiton_app_type}
IS_PUBLIC_APP=${kobiton_is_public_app}

BASICAUTH=$(echo -n $KOB_USERNAME_INPUT:$KOB_APIKEY_INPUT | base64)

echo "Using Auth: $BASICAUTH"

if [ -z "$APP_ID_INPUT" ]; then
    JSON="{\"filename\":\"${APP_NAME_INPUT}.${APP_SUFFIX_INPUT}\"}"
else
    JSON="{\"filename\":\"${APP_NAME_INPUT}.${APP_SUFFIX_INPUT}\",\"appId\":$APP_ID_INPUT}"
fi

curl --silent -X POST https://api-test.kobiton.com/v1/apps/uploadUrl \
    -H "Authorization: Basic $BASICAUTH" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d $JSON \
    -o ".tmp.upload-url-response.json"

UPLOAD_URL=$(cat ".tmp.upload-url-response.json" | ack -o --match '(?<=url\":")([_\%\&=\?\.aA-zZ0-9:/-]*)')
KAPPPATH=$(cat ".tmp.upload-url-response.json" | ack -o --match '(?<=appPath\":")([_\%\&=\?\.aA-zZ0-9:/-]*)')

echo "Uploading: ${APP_NAME_INPUT} (${APP_PATH_INPUT})"
echo "URL: ${UPLOAD_URL}"

curl --progress-bar -T "${APP_PATH_INPUT}" \
    -H "Content-Type: application/octet-stream" \
    -H "x-amz-tagging: unsaved=true" \
    -X PUT "${UPLOAD_URL}"
#--verbose

echo "Processing: ${KAPPPATH}"

JSON="{\"filename\":\"${APP_NAME_INPUT}.${APP_SUFFIX_INPUT}\",\"appPath\":\"${KAPPPATH}\"}"
curl -X POST https://api-test.kobiton.com/v1/apps \
    -H "Authorization: Basic $BASICAUTH" \
    -H 'Content-Type: application/json' \
    -d $JSON
    -o ".tmp.upload-app-response.json"

cat ".tmp.upload-url-response.json"

APP_ID=$(cat ".tmp.upload-app-response.json" | ack -o --match '(?<=appId\":")([_\%\&=\?\.aA-zZ0-9:/-]*)')

echo "Uploaded app to kobiton repo, appId: ${APP_ID}"

if [ -z "$IS_PUBLIC_APP" ]; then
    echo "Making appId: ${APP_ID} to public"
    curl -X PUT https://api.kobiton.com/v1/apps/{$APP_ID}/public \
        -H "Authorization: Basic $BASICAUTH"
fi

echo "...done"

#
# --- Export Environment Variables for other Steps:
# You can export Environment Variables for other Steps with
#  envman, which is automatically installed by `bitrise setup`.
# A very simple example:
# envman add --key EXAMPLE_STEP_OUTPUT --value 'the value you want to share'

envman add --key KOBITON_APP_ID --value ${APP_ID}
envman add --key KOBITON_UPLOAD_URL --value ${UPLOAD_URL}
envman add --key KOBITON_APP_PATH --value ${KAPPPATH}

# Envman can handle piped inputs, which is useful if the text you want to
# share is complex and you don't want to deal with proper bash escaping:
#  cat file_with_complex_input | envman add --KEY EXAMPLE_STEP_OUTPUT
# You can find more usage examples on envman's GitHub page
#  at: https://github.com/bitrise-io/envman

#
# --- Exit codes:
# The exit code of your Step is very important. If you return
#  with a 0 exit code `bitrise` will register your Step as "successful".
# Any non zero exit code will be registered as "failed" by `bitrise`.

exit 0
