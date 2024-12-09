#!/opt/homebrew/bin/bash

read -p "enter username" USER_NAME
read -p "enter groupname" GROUP_NAME

function gen_tmp_pw {
    local pw_len=16
    local TEMP_PW=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()-_=+' </dev/urandom | head -c16)
    echo $TEMP_PW
}

function gen_tmp_keys {
    local TEMP_ACCESS_KEY_ID=$(aws iam create-access-key --user-name "$USER_NAME" --query 'AccessKey.AccessKeyId' --output text)
    local TEMP_SECRET_ACCESS_KEY=$(aws iam create-access-key --user-name "$USER_NAME" --query 'AccessKey.SecretAccessKey' --output text)
    echo -e "Access key: $TEMP_ACCESS_KEY\nSecret key: $TEMP_SECRET_ACCESS_KEY"
}

TMP_PW=$(gen_tmp_pw)
TMP_KEYS=$(gen_tmp_keys)

(
    aws iam create-user --user-name $USER_NAME
    aws iam add-user-to-group --user-name $USER_NAME --group-name $GROUP_NAME
    aws iam create-login-profile --user-name $USER_NAME --password $TEMP_PW --password-reset-required
    aws iam attach-user-policy --user-name $USER_NAME --policy-arn arn:aws:iam::aws:policy/IAMUserChangePassword
) || echo "failed somewhere in user creation"

echo "all done. provide temp creds to " $USER_NAME "\nPassword: " $TEMP_PW "\nTemp keys: " $TMP_KEYS
