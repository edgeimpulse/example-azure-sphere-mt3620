#!/bin/bash

# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# This file is licensed under the MIT License.
#
# install_azure_sphere_sdk.sh
#
# Bash script to install the Azure Sphere SDK for Linux.
# --------------------------------------------------------------------------------------------

SDK_TARBALL_URL="https://aka.ms/AzureSphereSDKDownload/Linux"
SDK_LICENSE_URL="https://aka.ms/AzureSphereSDKLicense/Linux"
SDK_INSTALL_DOC_URL="https://aka.ms/AzureSphereSDK/Linux"
SDK_DOC_URL="https://aka.ms/AzureSphereSDK"
SDK_CLI_SELECTION_DOC_URL="https://aka.ms/AzureSphereCLIVersions"

MICROSOFT_PUBLIC_GPG_KEY_DETAILS_URL="https://aka.ms/AzureSphereSDKVerification/Linux"
MICROSOFT_PUBLIC_GPG_KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"

ROOT_DIR_NAME="azurespheresdk"

INSTALL_DIR="/opt/"
INSTALL_LOCATION="${INSTALL_DIR}${ROOT_DIR_NAME}"
APP_DATA_DIR="/var/opt/${ROOT_DIR_NAME}"
INSTALLED_FILE_LIST="${APP_DATA_DIR}/installed_files"
INSTALLED_VERSION_FILE="${APP_DATA_DIR}/version"

FORCE_OVERWRITE=false

CURRENT_USER=$(logname)
UDEV_GROUP=azsphere
UDEV_FILE_NAME="75-mt3620.rules"
UDEV_FILE="/etc/udev/rules.d/$UDEV_FILE_NAME"
PROFILED_PATH="/etc/profile.d/azure-sphere-sdk.sh"

# USB VID/PID and product identifier for the FTDI USB-serial chip as used on Azure Sphere dev boards
DEVICE_VID="0403"
DEVICE_PID="6011"
PRODUCT_ID="MSFT MT3620 Std Interface"

# Localisation strings
DEFAULT_LOCALE="en"
declare -A LOCALISATIONS=( ["en"]="en-US" ["fr"]="fr-FR" )
declare -A LOCAL_Yy=( ["en"]="Yy" ["fr"]="Oo" )
declare -A LOCAL_Nn=( ["en"]="Nn" ["fr"]="Nn" )
declare -A LOCAL_CONFIRM
LOCAL_CONFIRM["en"]="Please answer '${LOCAL_Yy["en"]:0:1}' or '${LOCAL_Nn["en"]:0:1}'."
LOCAL_CONFIRM["fr"]="Appuyez sur '${LOCAL_Yy["fr"]:0:1}' pour accepter ou sur '${LOCAL_Nn["fr"]:0:1}' pour refuser."
declare -A LOCAL_EULA_CHECK
LOCAL_EULA_CHECK["en"]="By proceeding with this installation you agree to the license terms available at $SDK_LICENSE_URL and which will be installed to $INSTALL_LOCATION. Proceed?"
LOCAL_EULA_CHECK["fr"]="En continuant cette installation, vous acceptez les termes du contrat de licence disponible sur $SDK_LICENSE_URL et qui sera installé sur $INSTALL_LOCATION. Voulez-vous continuer?"

# Logging config
LOG_LEVEL_ERROR="ERROR"
LOG_LEVEL_WARN="WARN"
LOG_LEVEL_INFO="INFO"
LOG_LEVEL_VERBOSE="VERBOSE"
LOG_LEVEL_DIAG="DIAG"

DEFAULT_LOG_LEVEL="$LOG_LEVEL_INFO"
CURRENT_LOG_LEVEL="$DEFAULT_LOG_LEVEL"

mode_diag(){ if [[ "$CURRENT_LOG_LEVEL" == "$LOG_LEVEL_DIAG" ]]; then return 0; else return 1; fi }
mode_verbose(){ if [[ "$CURRENT_LOG_LEVEL" == "$LOG_LEVEL_VERBOSE" ]] || mode_diag; then return 0; else return 1; fi }
mode_info(){ if [[ "$CURRENT_LOG_LEVEL" == "$LOG_LEVEL_INFO" ]] || mode_verbose; then return 0; else return 1; fi }
mode_warn(){ if [[ "$CURRENT_LOG_LEVEL" == "$LOG_LEVEL_WARN" ]] || mode_info; then return 0; else return 1; fi }
mode_error(){ if [[ "$CURRENT_LOG_LEVEL" == "$LOG_LEVEL_ERROR" ]] || mode_warn; then return 0; else return 1; fi }

set_diag_color() { echo -e -n "\e[90m" | tee /dev/stderr; }
set_verbose_color() { echo -e -n "\e[90m" | tee /dev/stderr; }
set_info_color() { echo -e -n "\e[0m" | tee /dev/stderr; }
set_warn_color() { echo -e -n "\e[33m" | tee /dev/stderr; }
set_error_color() { echo -e -n "\e[31m" | tee /dev/stderr; }
set_default_color() { echo -e -n "\e[0m" | tee /dev/stderr; }
set_normal_weight() { echo -e -n "\033[0m" | tee /dev/stderr; }
set_bold_weight() { echo -e -n "\033[1m" | tee /dev/stderr; }

log_diag() { if mode_diag; then set_diag_color; echo -e "DIAG: $1"; set_default_color; fi }
log_verbose() { if mode_verbose; then set_verbose_color; echo -e "VERBOSE: $1"; set_default_color; fi }
log_info() { if mode_info; then set_info_color; echo -e "$1"; set_default_color; fi }
log_warn() { if mode_warn; then set_warn_color; echo -e >&2 "WARN: $1"; set_default_color; fi }
log_error() { if mode_error; then set_error_color; echo -e >&2 "ERROR: $1"; set_default_color; fi }

# Usage
show_usage() {
  log_info "Microsoft Azure Sphere SDK - Install script"
  log_info "Usage: azure_sphere_sdk_install.sh [-i SDK_TARBALL] [-k MS_GPG_KEY] [-f] [-q|-v|-d]"
  log_info "       azure_sphere_sdk_install.sh -h"
  log_info "Params:"
  log_info "-i SDK_TARBALL   [Optional] The path to a local copy of the SDK"
  log_info "                 tarball. By default this script will download this from"
  log_info "                 $SDK_TARBALL_URL"
  log_info "-k MS_GPG_KEY    [Optional] The path to a local copy of the Microsoft GPG public"
  log_info "                 key. By default this script will download this from"
  log_info "                 $MICROSOFT_PUBLIC_GPG_KEY_URL"
  log_info "-f               Overwrite existing install without displaying a warning."
  log_info "-q               Quiet mode. Display errors only."
  log_info "-v               Verbose mode. Display additional information."
  log_info "-d               Diagnostic mode. Display diagnostic information."
  log_info "-h               Show this help."
  log_info "Run this script to install the Microsoft Azure Sphere SDK. Requires root permissions."
}

error_show_help() {
  log_error "$1\n"
  show_usage
  exit 1
}

error_multiple_options_specified() {
  error_show_help "Only one of options '-q' '-v' or '-d' may be specified at once."
}

parse_args() {
  while getopts "hi:k:qvdf" opt; do
    case "$opt" in
      h)
        show_usage
        exit 0
        ;;
      i)
        SDK_TARBALL=$OPTARG
        if [[ ! -f "$SDK_TARBALL" ]]; then error_show_help "Invalid value for -i parameter. File '$SDK_TARBALL' does not exist or you do not have access to it."; fi
        ;;
      k)
        MS_GPG_KEY=$OPTARG
        if [[ ! -f "$MS_GPG_KEY" ]]; then error_show_help "Invalid value for -k parameter. File '$MS_GPG_KEY' does not exist or you do not have access to it."; fi
        ;;
      v)
        if [[ "$CURRENT_LOG_LEVEL" != "$DEFAULT_LOG_LEVEL" ]]; then error_multiple_options_specified; fi
        CURRENT_LOG_LEVEL="$LOG_LEVEL_VERBOSE"
        ;;
      d)
        if [[ "$CURRENT_LOG_LEVEL" != "$DEFAULT_LOG_LEVEL" ]]; then error_multiple_options_specified; fi
        CURRENT_LOG_LEVEL="$LOG_LEVEL_DIAG"
        ;;
      q)
        if [[ "$CURRENT_LOG_LEVEL" != "$DEFAULT_LOG_LEVEL" ]]; then error_multiple_options_specified; fi
        CURRENT_LOG_LEVEL="$LOG_LEVEL_ERROR"
        ;;
      f)
        FORCE_OVERWRITE=true
        ;;
      ?)
        show_usage
        exit 1
        ;;
    esac
  done
}

clear_staging() {
  if [[ -d "$STAGING_DIR" ]]; then
    log_verbose "Clearing staged install files."
    rm -rf $STAGING_DIR
  fi
}

remove_files() {
  if [[ "$UNINSTALL_PHASE" == true ]]; then
    uninstall_previous_version_files
  elif [[ -f "$STAGED_FILE_LIST" ]]; then
    log_info "Removing installed files."
    remove_files_from_list $STAGED_FILE_LIST
  fi

  remove_app_data_dir
}

remove_udev_config() {
  if remove_default_udev_rule; then
    remove_current_user_from_default_udev_group
    remove_default_udev_group
  else
    log_warn "Could not remove udev configuration. See instructions on $SDK_INSTALL_DOC_URL for manual removal if required."
  fi
}

remove_install() {
  remove_files
  log_info "Removing Azure Sphere CLI from PATH, if present."
  remove_cli_tools_from_path
  log_info "Removing default udev configuration, if present."
  remove_udev_config
  clear_staging
}

exit_with_error() {
  # Exit, logging optional param $1 as an error
  set_default_color
  if [[ ! -z "$1" ]]; then log_error "$1"; fi
  if [[ "$INSTALL_STARTED" = true ]]; then
    log_info "Cancelled during installation, rolling back to clean state."
    remove_install
  fi
  log_info "Azure Sphere SDK installation cancelled."
  exit 1
}

exit_with_error_default_suffix(){
  exit_with_error "${1} Please try again or visit $SDK_INSTALL_DOC_URL for more information."
}

exit_with_unexpected_error() {
  exit_with_error_default_suffix "An unexpected error occurred."
}

set_up_interrupt_catch() {
  trap 'exit_with_error "Process was interrupted."' SIGINT SIGTERM SIGHUP SIGQUIT
}

check_running_as_sudo() {
  if [[ "$EUID" -ne 0 ]]; then exit_with_error "This script must be run with root permissions."; fi
}

check_if_known_locale(){
  # Takes params:
  # $1 localisation code to check for - could be of formats 'en' or 'en-US' or 'en-US.UTF-8'
  # $2 description of source of value to check for - for diagnostic message
  # Checks whether the supplied locale code $1 matches any of the locales the script knows about
  # and sets SCRIPT_LOCALE to that value if so.
  # Returns 0 if known locale, and 1 otherwise
  for supported_localization in "${!LOCALISATIONS[@]}"; do
    if [[ $1 == $supported_localization* ]]; then
      log_diag "Supported locale found $2: $1; setting script locale to '$supported_localization'"
      SCRIPT_LOCALE=$supported_localization
      return 0
    fi
  done
  return 1
}

set_script_locale() {
  # Uses localization environment variables to set the script locale to a known locale if appropriate
  SCRIPT_LOCALE="$DEFAULT_LOCALE"
  if [[ ! -z "$LC_ALL" ]] && [[ "$LC_ALL" == "C" ]]; then log_diag "LC_ALL set to 'C', using default script localization '$SCRIPT_LOCALE'"; return
  elif [[ ! -z "$LANG" ]] && [[ "$LANG" == "C" ]]; then log_diag "LANG set to 'C', using default script localization '$SCRIPT_LOCALE'"; return
  elif [[ ! -z "$LANGUAGE" ]]; then
    PREVIOUS_IFS=$IFS
    IFS=":"
    read -ra LANGUAGE_CODES <<< $LANGUAGE
    if [ $? -ne 0 ]; then exit_with_unexpected_error; fi

    IFS=$PREVIOUS_IFS
    for selected_localization in "${LANGUAGE_CODES[@]}"; do
      if check_if_known_locale $selected_localization; then return; fi
    done
  fi
  if [[ ! -z "$LC_ALL" ]] && check_if_known_locale $LC_ALL "LC_ALL"; then return; fi
  if [[ ! -z "$LC_MESSAGES" ]] && check_if_known_locale $LC_MESSAGES "LC_MESSAGES"; then return; fi
  if [[ ! -z "$LANG" ]] && check_if_known_locale $LANG "LANG"; then return; fi
}

user_confirm(){
  return 0
  # Takes up to two parameters:
  # $1 Confirmation question, to be followed by a localised " (Y/N)", repeated until the user answers
  # #2 Optional preamble, not repeated with question. Useful for long confirmation dialogs.
  RESPONSE=0
  if [[ ! -z "$2" ]]; then
    echo -e "$2"
  fi
  while true; do
    read -p "$1 (${LOCAL_Yy["$SCRIPT_LOCALE"]:0:1}/${LOCAL_Nn["$SCRIPT_LOCALE"]:0:1}) " response
    case $response in
      [${LOCAL_Yy["$SCRIPT_LOCALE"]}] ) RESPONSE=0; break; ;;
      [${LOCAL_Nn["$SCRIPT_LOCALE"]}] ) RESPONSE=1; break; ;;
      * ) echo "${LOCAL_CONFIRM["$SCRIPT_LOCALE"]}"; ;;
    esac
  done
  return $RESPONSE
}

user_confirm_or_abort() {
  # Takes up to two parameters:
  # $1 Confirmation question, to be followed by a localised " (Y/N)", repeated until the user answers
  # #2 Optional preamble, not repeated with question. Useful for long confirmation dialogs.
  if user_confirm "$1" "$2"; then return; else exit_with_error; fi
}

check_EULA() {
  user_confirm_or_abort "${LOCAL_EULA_CHECK["$SCRIPT_LOCALE"]}"
}

check_packages() {
  log_verbose "Checking for required packages:"

  # Per https://docs.microsoft.com/en-us/azure-sphere/install/install-sdk-linux we support only Ubuntu 18.04 and 20.04
  # Add 19.10 for now since we have test machines using 19.10.
  lsb_release="$(lsb_release -sr)"
  if [[ $lsb_release == "18.04" ]] || [[ $lsb_release == "19.10" ]]
  then
    DEPENDENCIES=(
    "curl"
    "libssl1.1"
    "libc6"
    "libgcc1"
    "libstdc++6"
    )
  else
    DEPENDENCIES=(
    "curl"
    "libssl1.1"
    "libc6"
    "libgcc-s1"
    "libstdc++6"
    )
  fi

  PACKAGES_MISSING=false
  PACKAGES_MISSING_LIST=""

  for DEPENDENCY in "${DEPENDENCIES[@]}"; do
    DPKG_OUTPUT="$(dpkg -s $DEPENDENCY 2>&1)"
    DPKG_RESULT=$?
    if mode_diag; then log_diag "dpkg output: $DPKG_OUTPUT"; fi
    if [ $DPKG_RESULT -ne 0 ]; then
      PACKAGES_MISSING=true
      PACKAGES_MISSING_LIST="$PACKAGES_MISSING_LIST $DEPENDENCY"
      log_error "Required package '$DEPENDENCY' missing."
    else
      INSTALL_STATE=$(echo "$DPKG_OUTPUT" | grep -e "^Status: .\+$" -o)
      INSTALL_STATE_RESULT=$?
      if [ $INSTALL_STATE_RESULT -ne 0 ]; then
        log_warn "Could not determine status of required package '$DEPENDENCY'. Please confirm it is installed correctly."
      elif [[ $INSTALL_STATE != "Status: install ok installed" ]]; then
        log_warn "Required package '$DEPENDENCY' did not have expected status. Please confirm it is installed correctly. Status reported as:\n$INSTALL_STATE"
      else
        log_verbose "Required package '$DEPENDENCY' present."
      fi
    fi
  done
  if [[ "$PACKAGES_MISSING" == true ]]; then
    exit_with_error "Required package check failed. Please install missing packages and retry:\n    sudo apt-get install -y$PACKAGES_MISSING_LIST"
  fi
  log_verbose "Package check complete."
}

create_staging_dir() {
  STAGING_DIR="$(mktemp -d)"
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not create staging directory."; fi

  log_diag "Created temporary directory '$STAGING_DIR'."

  STAGED_FILE_LIST="${STAGING_DIR}/installed_files"
  > $STAGED_FILE_LIST
}

curl_download_file(){
  # Takes parameters:
  # $1 - URL
  # $2 - matcher for downloaded file name
  # $3 - description of downloaded item
  # $4 - description of matcher for downloaded file name
  # Sets variable DOWNLOADED_FILE_NAME to name of file downloaded and DOWNLOADED_FILE_PATH to the full path
  TEMP_OUT_FILE="$(mktemp -p $STAGING_DIR)"

  PREVIOUS_DIR="$(pwd)"
  cd $STAGING_DIR

  if mode_diag; then
    set_diag_color
    curl -L -O -J -w "%{filename_effective}\n" $1 | tee $TEMP_OUT_FILE
    CURL_RESULT="${PIPESTATUS[0]}"
    set_default_color
    DOWNLOADED_FILE_NAME="$(tail -n 1 $TEMP_OUT_FILE)"
  else
    DOWNLOADED_FILE_NAME="$(curl -L -O -J -w "%{filename_effective}\n" -s -S --stderr $TEMP_OUT_FILE $1)"
    CURL_RESULT=$?
    CURL_ERROR="$(<$TEMP_OUT_FILE)"
  fi

  DOWNLOADED_FILE_PATH="$STAGING_DIR/$DOWNLOADED_FILE_NAME"

  cd $PREVIOUS_DIR

  if [[ $CURL_RESULT -ne 0 && ! -z "$CURL_ERROR" ]]; then
    exit_with_error_default_suffix "Curl encountered an error downloading $3.\n    $CURL_ERROR\n"
  elif [ $CURL_RESULT -ne 0 ]; then
    exit_with_error_default_suffix "Curl encountered an error downloading $3."
  elif [[ ! -z "$CURL_ERROR" && mode_verbose ]]; then
    log_verbose "Encountered non-fatal curl error downloading $3:\n$CURL_ERROR"
  fi

  # Check the file wasn't empty
  if [[ ! -s "$DOWNLOADED_FILE_PATH" ]]; then exit_with_error_default_suffix "The downloaded file is empty."; fi

  # Check we got the type of file we were expecting from the download
  if [[ ! "$DOWNLOADED_FILE_NAME" =~ $2 ]]; then exit_with_error_default_suffix "The downloaded file at $DOWNLOADED_FILE_NAME is not in the expected $4 format."; fi
}

get_sdk_tarball() {
  if [[ ! -z "$SDK_TARBALL" ]]; then
    # Use local tarball
    log_verbose "Installing Azure Sphere SDK tarball '$SDK_TARBALL'..."
  else
    # Otherwise download the SDK tarball to install
    log_info "Downloading Azure Sphere SDK tarball from '$SDK_TARBALL_URL'..."

    EXPECTED_FORMAT="\.tar.\gz$"
    curl_download_file $SDK_TARBALL_URL $EXPECTED_FORMAT "the Azure Sphere SDK" "tar archive"
    SDK_TARBALL="$DOWNLOADED_FILE_PATH"
  fi
}

unpack() {
  log_diag "Unpacking '$1' to '$2'"
  if mode_diag; then
    set_diag_color
    tar -xvzf "$1" -C "$2"
    TAR_RESULT=$?
    set_default_color
  else
    tar -xzf "$1" -C "$2"
    TAR_RESULT=$?
  fi

  if [ $TAR_RESULT -ne 0 ]; then exit_with_error_default_suffix "Tar encountered an error extracting $1 to $2."; fi
}

unpack_sdk_top_level_tarball() {
  STAGED_SDK_DIR=$STAGING_DIR/sdk_tarball_staging
  mkdir $STAGED_SDK_DIR
  log_verbose "Unpacking to staging location '$STAGED_SDK_DIR'."
  unpack "$SDK_TARBALL" "$STAGED_SDK_DIR"
}

check_versions() {
  PREVIEW_VERSION_STRING="Preview"
  UNKNOWN_VERSION_STRING="Unknown"

  STAGED_VERSION_FILE="$STAGED_SDK_DIR/version"

  if [[ ! -f "$STAGED_VERSION_FILE" ]]; then
    # Applies if you're installing an older Preview version
    log_diag "No staged version file detected, creating staged version file"
    echo "$PREVIEW_VERSION_STRING" > $STAGED_VERSION_FILE
  fi

  STAGED_VERSION="$( cat $STAGED_VERSION_FILE | tr -d '[:space:]' )"

  if [[ -f "$INSTALLED_VERSION_FILE" ]]; then
    log_diag "Installed version file found; install detected"

    CURRENT_INSTALLED_VERSION="$( cat $INSTALLED_VERSION_FILE | tr -d '[:space:]' )"

    if [[ "$FORCE_OVERWRITE" == false ]]; then
      if [[ "$CURRENT_INSTALLED_VERSION" == "$PREVIEW_VERSION_STRING" ]]; then
        MESSAGE_PREFIX="An Azure Sphere SDK Preview version is currently installed."
      else
        if [[ "$CURRENT_INSTALLED_VERSION" == "$STAGED_VERSION" ]]; then
          MESSAGE_PREFIX="Azure Sphere SDK version '$CURRENT_INSTALLED_VERSION' already installed."
        else
          MESSAGE_PREFIX="Azure Sphere SDK version '$CURRENT_INSTALLED_VERSION' currently installed."
        fi
      fi

      if [[ "$STAGED_VERSION" == "$PREVIEW_VERSION_STRING" ]]; then
        MESSAGE_SUFFIX="Overwrite it with an Azure Sphere SDK Preview version?"
      else
        if [[ "$CURRENT_INSTALLED_VERSION" == "$STAGED_VERSION" ]]; then
          MESSAGE_SUFFIX="Reinstall Azure Sphere SDK version ${STAGED_VERSION}?"
        else
          MESSAGE_SUFFIX="Overwrite it with Azure Sphere SDK version ${STAGED_VERSION}?"
        fi
      fi

      user_confirm_or_abort "$MESSAGE_PREFIX $MESSAGE_SUFFIX"
    fi
  elif [[ -e "$INSTALL_LOCATION" ]]; then
    # e.g. SDK installed with a pre-20.01 install script
    # Or if files are left over in install directory
    log_diag "No installed version file found but possible install detected"
    CURRENT_INSTALLED_VERSION="$UNKNOWN_VERSION_STRING"

    log_warn "Installation directory '$INSTALL_LOCATION' is not empty. You may have an Azure Sphere SDK Preview version already installed."
    set_warn_color
    set_bold_weight
    user_confirm_or_abort "Are you sure you want to proceed with this installation?" "Proceeding with this installation will permanently remove all files and subdirectories currently in the directory '$INSTALL_LOCATION'."
    set_normal_weight
    set_default_color
  fi

  if [[ "$STAGED_VERSION" == "$PREVIEW_VERSION_STRING" ]]; then
    log_info "Installing Azure Sphere SDK Preview."
  else
    log_info "Installing Azure Sphere SDK version $STAGED_VERSION."
  fi
  if [[ "$CURRENT_INSTALLED_VERSION" == "$PREVIEW_VERSION_STRING" ]]; then
    log_verbose "Overwriting existing Azure Sphere SDK Preview install."
  elif [[ "$CURRENT_INSTALLED_VERSION" == "$UNKNOWN_VERSION_STRING" ]]; then
    log_verbose "Overwriting files in '$INSTALL_LOCATION'."
  elif [[ ! -z "$CURRENT_INSTALLED_VERSION" ]]; then
    log_verbose "Overwriting existing Azure Sphere SDK version '$CURRENT_INSTALLED_VERSION' install."
  fi
}

download_microsoft_gpg_public_key() {
  log_verbose "Downloading the Microsoft Public GPG key from '$MICROSOFT_PUBLIC_GPG_KEY_URL'."

  EXPECTED_FORMAT="\.asc$"
  curl_download_file $MICROSOFT_PUBLIC_GPG_KEY_URL $EXPECTED_FORMAT "the Microsoft Public GPG key" "ASCII file used by Pretty Good Privacy (PGP)"
  MS_GPG_KEY="$DOWNLOADED_FILE_PATH"
}

validate_gpg_import_output() {
  if [[ -z "$1" ]]; then exit_with_error_default_suffix "No output from gpg --import command."; fi

  if [[ ! "$1" == *"Microsoft (Release signing) <gpgsecurity@microsoft.com>"* ]]; then exit_with_error_default_suffix "Imported key has unexpected publisher."; fi
}

import_key_to_temporary_keyring() {
  SIG_VALIDATION_TEMP_HOMEDIR="$STAGING_DIR/temp_homedir"
  log_diag "Creating temporary keyring in '$SIG_VALIDATION_TEMP_HOMEDIR'."

  mkdir -m 700 $SIG_VALIDATION_TEMP_HOMEDIR

  if [[ -z "$MS_GPG_KEY" ]]; then
    download_microsoft_gpg_public_key
  else
    log_verbose "Using public key file '$MS_GPG_KEY'."
  fi

  log_diag "Importing public key from '$MS_GPG_KEY' into temporary keyring in '$SIG_VALIDATION_TEMP_HOMEDIR'."

  GPG_OUTPUT=$(gpg --homedir "$SIG_VALIDATION_TEMP_HOMEDIR" --import "$MS_GPG_KEY" 2>&1)
  GPG_RESULT=$?

  log_diag "gpg --import command output:\n$GPG_OUTPUT"

  if [ $GPG_RESULT -ne 0 ]; then exit_with_error_default_suffix "Error importing the public key for signature verification."; fi

  validate_gpg_import_output "$GPG_OUTPUT"
}

validate_gpg_verify_output() {
  if [[ -z "$1" ]]; then exit_with_error_default_suffix "No output from gpg --verify command."; fi

  if [[ ! "$1" == *"Microsoft (Release signing) <gpgsecurity@microsoft.com>"* ]]; then exit_with_error_default_suffix "Signature was not signed by 'Microsoft (Release signing) <gpgsecurity@microsoft.com>'."; fi

  FINGERPRINT_MATCHER="^.\+[0-9A-Z]\{4\} [0-9A-Z]\{4\} [0-9A-Z]\{4\} [0-9A-Z]\{4\} [0-9A-Z]\{4\}  [0-9A-Z]\{4\} [0-9A-Z]\{4\} [0-9A-Z]\{4\} [0-9A-Z]\{4\} [0-9A-Z]\{4\}$"
  KEY_FINGERPRINT_LINES=$(echo "$1" | grep -e "$FINGERPRINT_MATCHER" -o)

  if [ $? -ne 0 ]; then exit_with_error_default_suffix "No key fingerprint information found."; fi

  user_confirm_or_abort "Proceed with installation?" "The SDK tarball signature is valid. The fingerprint of the key used is:\n\n    $KEY_FINGERPRINT_LINES\n\nPlease check that this fingerprint matches the Microsoft GPG public key fingerprint shown on $MICROSOFT_PUBLIC_GPG_KEY_DETAILS_URL before proceeding. Do not proceed if these values do not match."
}

check_sdk_signature() {
  log_info "Validating signature."
  log_diag "Validating '$SDK_INNER_TARBALL' against signature file '$SDK_SIGNATURE'."

  GPG_OUTPUT="$(gpg --homedir $SIG_VALIDATION_TEMP_HOMEDIR --verify $SDK_SIGNATURE $SDK_INNER_TARBALL 2>&1)"
  GPG_RESULT=$?

  log_diag "gpg --verify command output:\n$GPG_OUTPUT"

  if [ $GPG_RESULT -ne 0 ]; then exit_with_error_default_suffix "SDK installer signature could not be verified."; fi

  validate_gpg_verify_output "$GPG_OUTPUT"
}

validate_sdk_contents() {
  INNER_TARBALL_FILES="$(find $STAGED_SDK_DIR -name "Azure_Sphere_SDK*.tar.gz" -type f | wc -l)"
  if [[ ! "$INNER_TARBALL_FILES" == 1 ]]; then
    exit_with_error_default_suffix "Invalid SDK bundle."
  else
    SDK_INNER_TARBALL="$(find $STAGED_SDK_DIR -name "Azure_Sphere_SDK*.tar.gz" -type f)"
  fi

  INNER_SIGNATURE_FILES="$(find $STAGED_SDK_DIR -name "Azure_Sphere_SDK*.pgp" -type f | wc -l)"
  if [[ ! "$INNER_SIGNATURE_FILES" == 1 ]]; then
    exit_with_error_default_suffix "Invalid SDK bundle."
  else
    SDK_SIGNATURE="$(find $STAGED_SDK_DIR -name "Azure_Sphere_SDK*.pgp" -type f)"
  fi

  import_key_to_temporary_keyring
  check_sdk_signature
}

remove_files_from_list() {
  if mode_diag; then
    set_diag_color
    tac "$1" | while read line; do
      if [[ -f "$line" ]]; then
        rm "$line" $verbose_param
      elif [[ -L "$line" ]]; then
        rm "$line" $verbose_param
      elif [[ -d "$line" ]]; then
        rm -d "$line" $verbose_param
      fi
    done
    set_default_color
  else
    tac "$1" | while read line; do
      if [[ -f "$line" ]]; then
        rm "$line" > /dev/null 2>&1
      elif [[ -L "$line" ]]; then
        rm "$line" > /dev/null 2>&1
      elif [[ -d "$line" ]]; then
        rm -d "$line" > /dev/null 2>&1
      fi
    done
  fi
}

remove_install_location() {
  log_diag "Removing $INSTALL_LOCATION"
  rm -rf "$INSTALL_LOCATION"
}

remove_app_data_dir() {
  log_diag "Removing $APP_DATA_DIR"
  rm -rf $APP_DATA_DIR
}

uninstall_previous_version_files() {
  if [[ ! -z "$CURRENT_INSTALLED_VERSION" ]]; then
    if [[ -f "$INSTALLED_FILE_LIST" ]]; then
      log_info "Uninstalling previous instance."
      UNINSTALL_PHASE=true
      remove_files_from_list $INSTALLED_FILE_LIST
      remove_app_data_dir
      UNINSTALL_PHASE=false
    elif [[ "$CURRENT_INSTALLED_VERSION" == "$UNKNOWN_VERSION_STRING" ]]; then
      log_info "Clearing install location."
      UNINSTALL_PHASE=true
      remove_install_location
      remove_app_data_dir
      UNINSTALL_PHASE=false
    else
      exit_with_error_default_suffix "Could not uninstall previous SDK instance. Please follow manual uninstall instructions on $SDK_INSTALL_DOC_URL before retrying."
    fi
  fi
}

set_sdk_file_permissions() {
  log_diag "Setting permissions on all installed files to 644"
  chmod 644 "$INSTALL_LOCATION" -R
  if [ $? -ne 0 ]; then
    log_warn "Could not set installed file permissions correctly. This may mean some files have incorrect permissions."
  fi

  log_diag "Setting permissions on all installed dirs to 755"
  find "$INSTALL_LOCATION" -type d -exec chmod 755 {} \;
  if [ $? -ne 0 ]; then
    log_warn "Could not set installed directory permissions correctly. This may mean some directories have incorrect permissions."
  fi

  if check_if_sdk_includes_v2_cli; then
    EXECUTABLES=(
      "$INSTALL_LOCATION/Tools/azsphere"
      "$INSTALL_LOCATION/DeviceConnection/azsphere_connect.sh"
      "$INSTALL_LOCATION/DeviceConnection/azsphere_slattach")
  else
    EXECUTABLES=(
      "$INSTALL_LOCATION/Tools/azsphere"
      "$INSTALL_LOCATION/Tools/azsphere_connect.sh"
      "$INSTALL_LOCATION/Tools/azsphere_slattach")
  fi

  log_diag "Setting permissions on installed symlinks to 755"
  for FILE in "${EXECUTABLES[@]}"; do
    chmod 755 "$FILE"
    if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not mark file $FILE as executable."; fi
  done
}

install_sdk_tarball() {
  # Record what files are to be installed for rollback/uninstall support
  tar --list -f "$SDK_INNER_TARBALL" | sed -r -e 's~^~/opt/~' >> $STAGED_FILE_LIST
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "There was an error extracting the tarball contents from '$SDK_INNER_TARBALL'."; fi

  # Install files
  unpack "$SDK_INNER_TARBALL" "$INSTALL_DIR"
  set_sdk_file_permissions
}

install_sdk_toolchains() {
  log_verbose "Unpacking toolchains."

  SYSROOTS="$INSTALL_LOCATION/Sysroots/"
  TOOLCHAIN_ROOT_DIR_NAME="tools/"
  TOOLCHAIN_SH_NAME="exp23-appsdk-linux-blanca.sh"
  for TOOLCHAIN_VERSION_DIR in "$SYSROOTS"*/ ; do
    TOOLCHAIN_DIR="${TOOLCHAIN_VERSION_DIR}${TOOLCHAIN_ROOT_DIR_NAME}"
    TOOLCHAIN_SH_PATH="${TOOLCHAIN_DIR}${TOOLCHAIN_SH_NAME}"
    TOOLCHAIN_VERSION="$(basename $TOOLCHAIN_VERSION_DIR)"

    if [[ ! -f "$TOOLCHAIN_SH_PATH" ]]; then exit_with_error_default_suffix "Unexpected error: toolchain bundle missing."; fi

    log_diag "Setting permission on toolchain bundle installer to 755"
    chmod 755 "$TOOLCHAIN_SH_PATH"
    if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not mark toolchain bundle as executable."; fi

    log_info "Installing toolchain version '$TOOLCHAIN_VERSION'."
    log_diag "Installing from '$TOOLCHAIN_SH_PATH'."
    echo $TOOLCHAIN_SH_PATH >> $STAGED_FILE_LIST

    # Record what files are to be installed for rollback/uninstall support
    # Format of self-extracting tarball list, e.g.:
    # -rwxr-xr-x root/root     14680 2019-11-05 01:01 ./sysroots/x86_64-pokysdk-linux/lib/libutil-2.28.so
    # lrwxrwxrwx root/root         0 2019-11-05 01:01 ./sysroots/x86_64-pokysdk-linux/lib/ld-linux-x86-64.so.2 -> ld-2.28.so
    # hrwxr-xr-x root/root         0 2019-11-08 23:29 ./sysroots/x86_64-pokysdk-linux/usr/bin/python3.5.real link to ./sysroots/x86_64-pokysdk-linux/usr/bin/python3.5m
    # So to log the list of installed files, we strip off the front and anything after " ->" or " link to", as well
    # as resulting lines only containing . or empty lines, and finally add the location prefix before writing out.
    $TOOLCHAIN_SH_PATH -l | sed -r -e 's/^.{48}//' -e 's/ ->.*//' -e 's/ link to .*//' -e 's/^..$//' -e '/^$/d' -e "s~^./~$TOOLCHAIN_DIR~" >> $STAGED_FILE_LIST
    if [ $? -ne 0 ]; then exit_with_error_default_suffix "There was an error extracting the toolchain information from '$TOOLCHAIN_SH_PATH'."; fi

    # Install files
    if mode_diag; then
      set_diag_color
      $TOOLCHAIN_SH_PATH -d $TOOLCHAIN_DIR -y
      TOOLCHAIN_UNPACK_RESULT=$?
      set_default_color
    else
      TOOLCHAIN_UNPACK_ERRORS="$($TOOLCHAIN_SH_PATH -d $TOOLCHAIN_DIR -y 2>&1 > /dev/null)"
      TOOLCHAIN_UNPACK_RESULT=$?
    fi

    if [[ ! -z "$TOOLCHAIN_UNPACK_ERRORS" ]]; then log_warn "Non-fatal errors occurred whilst unpacking toolchain:\n$TOOLCHAIN_UNPACK_ERRORS"; fi

    if [ $TOOLCHAIN_UNPACK_RESULT -ne 0 ]; then exit_with_error_default_suffix "There was an error extracting the toolchain from '$TOOLCHAIN_SH_PATH'."; fi

    log_diag "Tidying up $TOOLCHAIN_SH_PATH"
    rm $TOOLCHAIN_SH_PATH

    if [ $? -ne 0 ]; then log_warn "Could not remove '$TOOLCHAIN_SH_PATH' after install. Please retry or delete this file manually."; fi

    log_verbose "Toolchain version '$TOOLCHAIN_VERSION' installed."
  done
}

check_if_sdk_includes_v2_cli() {
  MAJOR_VERSION_THR="20"
  MINOR_VERSION_THR="11"

  VERSION_SEGMENTS=($(echo $STAGED_VERSION | tr "." "\n"))
  VERSION_LENGTH=${#VERSION_SEGMENTS[@]}

  if [ ! $VERSION_LENGTH -ge 2 ]; then
    exit_with_error_default_suffix "Invalid version."
  fi

  MAJOR_VERSION_SEGMENT=${VERSION_SEGMENTS[0]}
  MINOR_VERSION_SEGMENT=${VERSION_SEGMENTS[1]}

  if [ $MAJOR_VERSION_SEGMENT -gt $MAJOR_VERSION_THR ]; then
    return 0
  elif [ $MAJOR_VERSION_SEGMENT -lt $MAJOR_VERSION_THR ]; then
    return -1
  else # Major equal
    if [ $MINOR_VERSION_SEGMENT -ge $MINOR_VERSION_THR ]; then
      return 0
    else
      return -1
    fi
  fi
}

configure_links() {
  CLI_V1_PATH="../Tools/azsphere"
  CLI_V2_PATH="../Tools_v2/azsphere"
  CONNECT_PATH="../DeviceConnection/azsphere_connect.sh"

  LINKS_DIR="${INSTALL_LOCATION}/Links"
  mkdir -p $LINKS_DIR
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "Failed to create directory ${LINKS_DIR}."; fi

  # Symlinks to the CLIs
  ln -s $CLI_V1_PATH "${LINKS_DIR}/azsphere_v1"
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not create symlink ${LINKS_DIR}/azsphere_v1."; fi

  ln -s $CLI_V2_PATH "${LINKS_DIR}/azsphere_v2"
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not create symlink ${LINKS_DIR}/azsphere_v2."; fi

  # Symlinks to device communication scripts
  ln -s $CONNECT_PATH "${LINKS_DIR}/azsphere_connect.sh"
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not create symlink ${LINKS_DIR}/azsphere_connect.sh."; fi

  # Configure default CLI
  CONFIGURE_CLI_MESSAGE="This SDK contains two versions of the Azure Sphere CLI: the new Azure Sphere CLI (recommended) \
and Azure Sphere classic CLI (deprecated). \
See ${SDK_CLI_SELECTION_DOC_URL} for more information on the versions.

You can choose which version is available through the command 'azsphere'.

Note that the Azure Sphere classic CLI will always be available to use with 'azsphere_v1' \
and the new Azure Sphere CLI will always be available to use with 'azsphere_v2'."

  DEFAULT_CLI_PATH=$CLI_V1_PATH
  if user_confirm "Use the recommended (new) CLI for 'azsphere'?" "${CONFIGURE_CLI_MESSAGE}"; then
    DEFAULT_CLI_PATH=$CLI_V2_PATH
  fi

  ln -s $DEFAULT_CLI_PATH "${LINKS_DIR}/azsphere"
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not create symlink ${LINKS_DIR}/azsphere."; fi

  # Set permissions and store in staging list
  EXECUTABLES=(
      "${LINKS_DIR}/azsphere"
      "${LINKS_DIR}/azsphere_v1"
      "${LINKS_DIR}/azsphere_v2"
      "${LINKS_DIR}/azsphere_connect.sh")

  log_diag "Setting permissions on installed executable files to 755"
  for FILE in "${EXECUTABLES[@]}"; do
    chmod 755 "$FILE"
    if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not mark file $FILE as executable."; fi

    echo $FILE >> $STAGED_FILE_LIST
    if [ $? -ne 0 ]; then exit_with_error_default_suffix "There was an error adding executable link to the SDK file list."; fi
  done
}

install_cli_v2() {
  log_info "Installing CLI."

  # Preparation
  CLI_INSTALLER_DIR="${INSTALL_LOCATION}/Tools_v2_Installer"

  log_diag "Listing CLI files for install file list."

  CLI_TARBALL="${CLI_INSTALLER_DIR}/azsphere-cli-v2.tar.gz"
  if [[ ! -f "${CLI_TARBALL}" ]]; then exit_with_error_default_suffix "Unexpected error: CLI tarball missing."; fi

  tar --list -f ${CLI_TARBALL} | sed 's/^../\/opt\/azurespheresdk\/Tools_v2\//g' >> ${STAGED_FILE_LIST}
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "There was an error extracting the tarball contents from '$CLI_TARBALL'."; fi

  # Install files
  log_diag "Installing CLI files."

  CLI_DIR="${INSTALL_LOCATION}/Tools_v2"

  mkdir -p ${CLI_DIR}
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "There was an error creating CLI directory '${CLI_DIR}'."; fi

  unpack ${CLI_TARBALL} ${CLI_DIR}

  # Install auto-completion
  log_diag "Installing auto-completion for CLI."

  COMPLETION_DIR="/etc/bash_completion.d"
  COMPLETION_SCRIPT="${COMPLETION_DIR}/azsphere-cli"
  COMPLETION_INSTALL_SCRIPT="${CLI_INSTALLER_DIR}/azsphere.completion"

  mkdir -p ${COMPLETION_DIR}
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "There was an error creating bash completion directory."; fi

  cat ${COMPLETION_INSTALL_SCRIPT} > ${COMPLETION_SCRIPT}
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "There was an error creating CLI bash completion script."; fi

  log_diag "Listing CLI auto-completion files for install file list."
  echo ${COMPLETION_SCRIPT} >> $STAGED_FILE_LIST
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "There was an error adding CLI bash completion script to the SDK file list."; fi

  # Remove CLI installation directory
  log_diag "Removing CLI installer directory."
  rm -rf $CLI_INSTALLER_DIR
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "There was an error removing the CLI installation directory '$CLI_INSTALLER_DIR'."; fi
}

install_application_data() {
  # Set up app data dir if it doesn't already exist
  if [[ ! -d $APP_DATA_DIR ]]; then
    mkdir $APP_DATA_DIR
    if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not create application data directory '$APP_DATA_DIR'."; fi
    log_diag "Created application data directory '$APP_DATA_DIR'."
  fi

  # Save installed version to SDK for version show (azsphere show-version)
  SDK_VERSION_FILE="${INSTALL_LOCATION}/VERSION"
  cp $STAGED_VERSION_FILE $SDK_VERSION_FILE
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not add version file '${SDK_VERSION_FILE}'."; fi
  chmod 644 $SDK_VERSION_FILE

  echo ${SDK_VERSION_FILE} >> $STAGED_FILE_LIST
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "There was an error adding '${SDK_VERSION_FILE}' file to the SDK file list."; fi

  # Save installed version to config for uninstall
  cp $STAGED_VERSION_FILE $INSTALLED_VERSION_FILE
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not add application data '${INSTALLED_VERSION_FILE}'."; fi
  chmod 644 $INSTALLED_VERSION_FILE

  # Save installed file list to config for uninstall
  cp $STAGED_FILE_LIST $INSTALLED_FILE_LIST
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not add application data '${INSTALLED_FILE_LIST}'."; fi
}

install_sdk_files() {
  log_info "Installing SDK files."

  install_sdk_tarball
  install_sdk_toolchains

  if check_if_sdk_includes_v2_cli; then
    install_cli_v2
    configure_links
  fi

  install_application_data

  log_info "SDK installed to '$INSTALL_LOCATION'."
}

add_default_udev_group() {
  if getent group $UDEV_GROUP > /dev/null; then
    log_verbose "Group '$UDEV_GROUP' already exists, skipping."
  else
    log_verbose "Adding group '$UDEV_GROUP'."
    groupadd $UDEV_GROUP
    if [ $? -ne 0 ]; then exit_with_error_default_suffix "Failed to set up udev rule: could not add group '$UDEV_GROUP'."; fi

    UDEV_GROUP_ADDED=true
    log_diag "Group '$UDEV_GROUP' added."
  fi
}

remove_default_udev_group () {
  # Removes the azsphere udev group if it's empty
  if getent group $UDEV_GROUP > /dev/null; then
    log_diag "Removing group '$UDEV_GROUP'."

    if mode_diag; then
      set_diag_color
      delgroup $UDEV_GROUP --only-if-empty
      DELGROUP_RESULT=$?
      set_default_color
    else
      delgroup $UDEV_GROUP --only-if-empty > /dev/null
      DELGROUP_RESULT=$?
    fi

    if [ $DELGROUP_RESULT -ne 0 ]; then log_warn "Could not remove group '$UDEV_GROUP'. See instructions on $SDK_INSTALL_DOC_URL for manual removal if required."; fi
  fi
}

add_current_users_to_default_udev_group() {
  if [ -z $CURRENT_USER ]; then
    log_warn "Could not determine current user: please add yourself to the '$UDEV_GROUP' group once this install has finished."
  else
    if id -nG "$CURRENT_USER" | grep -qw $UDEV_GROUP; then
      log_verbose "User '$CURRENT_USER' is already in group '$UDEV_GROUP', skipping."
    else
      log_verbose "Adding user '$CURRENT_USER' to group '$UDEV_GROUP'."
      usermod -a -G $UDEV_GROUP $CURRENT_USER

      if [ $? -ne 0 ]; then exit_with_error_default_suffix "Failed to set up udev rule: could not add user '$CURRENT_USER' to group '$UDEV_GROUP'."; fi

      UDEV_USER_ADDED=true
      log_diag "User '$CURRENT_USER' added to group '$UDEV_GROUP'."
    fi
  fi
}

remove_current_user_from_default_udev_group() {
  # Removes the current user from the azsphere udev group
  if getent group $UDEV_GROUP > /dev/null; then
    # group exists
    if [ ! -z $CURRENT_USER ]; then
      # We have a user
      if id -nG "$CURRENT_USER" | grep -qw $UDEV_GROUP; then
        # they're in the group
        log_diag "Removing user '$CURRENT_USER' to group '$UDEV_GROUP'."

        if mode_diag; then
          set_diag_color
          gpasswd -d $CURRENT_USER $UDEV_GROUP
          GPASSWD_RESULT=$?
          set_default_color
        else
          gpasswd -d $CURRENT_USER $UDEV_GROUP > /dev/null
          GPASSWD_RESULT=$?
        fi

        if [ $GPASSWD_RESULT -ne 0 ]; then log_warn "Could not remove current user '$CURRENT_USER' from group '$UDEV_GROUP'. See instructions on $SDK_INSTALL_DOC_URL for manual removal if required."; fi
      fi
    fi
  fi
}

create_temp_udev_rule() {
  TEMP_UDEV_FILE="$STAGING_DIR/$UDEV_FILE_NAME"
  log_diag "Creating temporary udev file $TEMP_UDEV_FILE"

  cat > $TEMP_UDEV_FILE <<EOT
# Grant ownership of Azure Sphere (MT3620) USB devices to the $UDEV_GROUP group

SUBSYSTEMS=="usb", ATTRS{idVendor}=="$DEVICE_VID", ATTRS{idProduct}=="$DEVICE_PID", ATTRS{product}=="$PRODUCT_ID", GROUP="$UDEV_GROUP"
EOT
}

add_default_udev_rule() {
  create_temp_udev_rule
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "Failed to create temporary udev rule file '$TEMP_UDEV_FILE'."; fi

  if [ -e "$UDEV_FILE" ]; then
    diff "$TEMP_UDEV_FILE" "$UDEV_FILE" > /dev/null
    if [ $? -ne 0 ]; then
      log_warn "A different udev rule already exists at '$UDEV_FILE', skipping."
    else
      log_verbose "Default udev rule file '$UDEV_FILE' already exists, skipping."
    fi
    return
  fi

  log_verbose "Adding udev rule in '$UDEV_FILE'."
  cp $TEMP_UDEV_FILE $UDEV_FILE
  if [ $? -ne 0 ]; then exit_with_error_default_suffix "Failed to create udev rule file '$UDEV_FILE'."; fi

  UDEV_RULE_ADDED=true
  log_diag "'$UDEV_FILE' created succesfully."
  log_diag "udev file contents:\n$(cat $UDEV_FILE)"
}

remove_default_udev_rule() {
  # Removes the azsphere udev file if the contents match the default azsphere udev file
  if [[ -f $UDEV_FILE ]]; then
    if [[ ! -f $TEMP_UDEV_FILE ]]; then
      # Create default temp udev rule file to compare the installed udev file
      create_temp_udev_rule
      if [ $? -ne 0 ]; then log_warn "Could not remove udev rule '$UDEV_FILE'. See instructions on $SDK_INSTALL_DOC_URL for manual removal."; fi
    fi
    if [[ -f $TEMP_UDEV_FILE ]]; then
      cmp $TEMP_UDEV_FILE $UDEV_FILE --silent
      COMPARE_RESULT=$?

      if [ $COMPARE_RESULT -eq 0 ]; then
        log_diag "Removing udev rule $UDEV_FILE"
        rm $UDEV_FILE
        if [ $? -ne 0 ];
            then log_warn "Could not remove udev rule '$UDEV_FILE'. See instructions on $SDK_INSTALL_DOC_URL for manual removal."
        else
           return 0
        fi
      elif [ $COMPARE_RESULT -eq 1 ]; then
        log_warn "Udev rule $UDEV_FILE has been modified; skipping removal of udev rule. See instructions on $SDK_INSTALL_DOC_URL for manual removal if required.";
      else
        log_warn "Could not remove udev rule '$UDEV_FILE'. See instructions on $SDK_INSTALL_DOC_URL for manual removal.";
      fi
    fi
    return 1
  fi
  return 0
}

add_udev_rule_and_group() {
  UDEV_GROUP_ADDED=false
  UDEV_USER_ADDED=false
  UDEV_RULE_ADDED=false

  if [ -z $CURRENT_USER ]; then
    PROMPT="Set up the default udev rule and group ($UDEV_GROUP)?"
  else
    PROMPT="Set up the default udev rule and group ($UDEV_GROUP), and add the current user ($CURRENT_USER) to it?"
  fi

  if user_confirm "$PROMPT" "Some device operations require root permissions, or permissions granted by a udev rule."; then
    add_default_udev_group
    add_current_users_to_default_udev_group
    add_default_udev_rule

    if [[ "$UDEV_GROUP_ADDED" == true ]] || [[ "$UDEV_USER_ADDED" == true ]] || [[ "$UDEV_RULE_ADDED" == true ]]; then
      log_info "Default udev rule set up complete. You will need to reboot your machine for these changes to take effect."
    else
      log_info "Default udev rule set up complete."
    fi
  fi

  if user_confirm "Set network admin capabilities to azsphere_slattach. This will allow running azsphere_connect.sh with no 'sudo' elevation, if the user running it has R&W permissions on the USB Azure Sphere device is connected."; then
    log_diag "Setting network admin capabilities to azsphere_slattach"
    if check_if_sdk_includes_v2_cli; then
      setcap CAP_NET_ADMIN+ep "$INSTALL_LOCATION/DeviceConnection/azsphere_slattach"
    else
      setcap CAP_NET_ADMIN+ep "$INSTALL_LOCATION/Tools/azsphere_slattach"
    fi
    if [ $? -ne 0 ]; then exit_with_error_default_suffix "Could not set network admin capabilities to azsphere_slattach."; fi
  fi

  return 0
}

add_cli_tools_to_path() {
  # Adds the CLI to the path by creating a profile.d file
  if user_confirm "Add the Azure Sphere CLI and device connection script to the PATH for all users (this will add a file to /etc/profile.d/)?"; then
    log_verbose "Setting up PATH variable for Azure Sphere CLI and scripts."

    if check_if_sdk_includes_v2_cli; then
      AZSPHERE_PATH="${INSTALL_LOCATION}/Links"
    else
      AZSPHERE_PATH="${INSTALL_LOCATION}/Tools"
    fi

    PROFILED_CONTENT="export PATH=\"\$PATH:${AZSPHERE_PATH}\""

    log_diag "Writing to '$PROFILED_PATH'."
    echo $PROFILED_CONTENT > $PROFILED_PATH
    log_info "Azure Sphere CLI and device connection script added to PATH for all users. You will need to restart your user session for this change to take effect."
  fi
}

remove_cli_tools_from_path() {
  # Removes the CLI from the path by removing the installed profile.d file
  log_diag "Deleting $PROFILED_PATH"
  rm -rf $PROFILED_PATH
}

# Init
parse_args "$@"
set_up_interrupt_catch

# Pre-install check and set up
check_running_as_sudo
set_script_locale
check_packages
create_staging_dir

# Download SDK or use local path
get_sdk_tarball

# Unpack and verify SDK
unpack_sdk_top_level_tarball
check_versions
validate_sdk_contents

# Check EULA before proceeding
check_EULA

# Install SDK and run additional set up
INSTALL_STARTED=true
uninstall_previous_version_files
install_sdk_files

# Additional setup
add_udev_rule_and_group
add_cli_tools_to_path

# Tidy up
clear_staging
log_info "Azure Sphere SDK installation complete. Visit $SDK_DOC_URL for documentation and samples."
exit 0
