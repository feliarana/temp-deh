#!/bin/bash

function install_xcode {
    if ! xcode-select --print-path; then
	echo "attempting install of xcode cli tools..."
	xcode-select --install
	if test $? -ne 0; then
	    echo "Command Line Tools for Xcode not found. Installing from softwareupdate…"
	    # This temporary file prompts the 'softwareupdate' utility to list the Command Line Tools
	    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress;
	    CLI_UPDATES=$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')
	    softwareupdate -i "$CLI_UPDATES" --verbose;
	else
	    echo "Command Line Tools for Xcode have been installed."
	fi
    fi

#    sudo xcodebuild -license accept mmmm?
}

function install_brew {
    if ! command -v brew; then
	/bin/bash -c "$(curl -fsSL -o install.sh https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	if brew doctor; then
	    echo "Appending brew path to dotrc"
	    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
	    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.bash_profile
	    source ~/.zprofile
	    echo "Successfully installed brew"
	else
	    echo "Failed to install homebrew...Ping someone on devops"
	    exit 1
	fi
	else
	    echo "homebrwe already installed."
    fi
}

function pkg_install {
    for pkg in "$@"; do
	if brew list --formula |grep -q "^${pkg}\$"; then
	    echo "$pkg is already installed"
	else
	    echo "installing: $pkg"
	    brew install "$pkg"
	fi
    done
}

function cask_install {
    for pkg in "$@"; do
	if brew list --cask |grep -q "^${pkg}\$"; then
	    echo "$pkg is already installed"
	else
	    echo "installing: $pkg"
	    brew install --cask "$pkg"
	fi
    done
}

function aws_setup_cfg {
    default_region="us-east-1"
    profile_name=$(whoami)
    if test -f ~/.aws/config; then
	echo "config already exists"
    else
	cat <<EOF> ~/.aws/config
[default]
region = $default_region
output = json

[profile $profile_name]
region = $default_region
EOF
	echo "aws config setup using $profile_name for your profile name."
    fi

    (
	temp_dir=$(mktemp -d)
	pushd "$temp_dir"

        curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac_arm64/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
        test $? -eq 0 || { echo "failed to download the session manager bundle."; popd; rm -rf "$temp_dir"; exit 1; }

        unzip sessionmanager-bundle.zip
        test $? -eq 0 || { echo "failed to unzip the session manager bundle."; popd; rm -rf "$temp_dir"; exit 1; }

        sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
        test $? -eq 0 || { echo "failed to install the session manager plugin."; popd; rm -rf "$temp_dir"; exit 1; }

        session-manager-plugin --version

        popd
        rm -rf "$temp_dir"
    )

    if test $? -eq 0; then
        echo "Session Manager Plugin installed successfully."
    else
        echo "Session Manager Plugin installation failed."
    fi
}

function aws_setup_mfa {
    USER_NAME=$1

    MFA_DEVICE_NAME="mfa-device-$USER_NAME"
    MFA_DEVICE_ARN=$(aws iam create-virtual-mfa-device --virtual-mfa-device-name $MFA_DEVICE_NAME --output text --query 'VirtualMFADevice.SerialNumber')
    echo "Virtual MFA device created with ARN: " $MFA_DEVICE_ARN

    aws iam create-virtual-mfa-device --virtual-mfa-device-name $MFA_DEVICE_NAME --output text --query 'VirtualMFADevice.Base32StringSeed' | base32 | qrencode -o - -t UTF8
    echo "Please use your authenticator app to scan the QR code displayed above."

    read -p "Enter the first MFA code: " MFA_CODE_1
    read -p "Enter the second MFA code: " MFA_CODE_2

    aws iam enable-mfa-device --user-name $USER_NAME --serial-number $MFA_DEVICE_ARN --authentication-code-1 $MFA_CODE_1 --authentication-code-2 $MFA_CODE_2
    echo "MFA device enabled for user: " $USER_NAME

#    SERIAL=$(aws iam create-virtual-mfa-device --virtual-mfa-device-name "$USER_NAME-mfa" --outfile /dev/null --query 'VirtualMFADevice.SerialNumber' --output text)
#    ARN=$(aws iam create-virtual-mfa-device --virtual-mfa-device-name "$USER_NAME-mfa" --query 'VirtualMFADevice.SerialNumber' --output text)
#    aws iam enable-mfa-device --user-name "$USER_NAME" --serial-number "$SERIAL" --authentication-code-1 "$MFA_CODE1" --authentication-code-2 "$MFA_CODE2"
#    aws iam change-password --user-name "$USER_NAME" --old-password "$TEMP_PW" --new-password "$NEW_PW"

    sed -i '' "s|<FIXME>|$SERIAL|g" ~/.aws/config

    echo "MFA setup is complete. Your AWS config has been updated."
}

function run_it {
    pkgs_list="git bash git-flow awscli coreutils docker docker-compose openjdk dpkg jq rvm" #split up pkgs
    cask_list="aws-vault"

    install_xcode
    install_brew
    pkg_install "$pkgs_list"
    cask_install "$cask_list"
    aws_setup_cfg
#    aws_setup_mfa
}

#run_it
