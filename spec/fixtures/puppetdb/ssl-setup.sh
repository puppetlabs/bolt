#!/bin/bash

ssl_command="puppetdb ssl-setup"

#############
# FUNCTIONS #
#############

# Display usage information and exit
#
# This function simply displays the usage information to the screen and exits
# with exit code 0.
#
# Example:
#
#   usage
#
function usage() {
  echo "Usage: ${ssl_command} [-if]"
  echo "Configuration helper for enabling SSL for PuppetDB."
  echo
  echo "This tool will attempt to copy the necessary Puppet SSL PEM files into "\
       "place for use by the PuppetDB HTTPS service. It also is able to update "\
       "the necessary PuppetDB configuration files if necessary to point to "\
       "the location of these files and also configures the host and port for "\
       "SSL to listen on."
  echo
  echo "Options:"
  echo " -i  Interactive mode"
  echo " -f  Force configuration file update. By default if the configuration "\
       "already exists in your jetty.ini or if your configuration is otherwise "\
       "in a state we believe we shouldn't touch by default, you must use this "\
       "option to override it"
  echo " -h  Help"
  exit 0
}

# Backs up a file, if it hasn't already been backed up
#
# $1 - file to backup
#
# Example:
#
#   backupfile "/etc/myconfig"
#
function backupfile() {
  # Create the global array if it doesn't already exist
  if [ -z $backupfile_list ]; then
    # backupfile_list=()
    backupfile_list=""
  fi

  # We check the array to make sure the file isn't already backed up
  # if ! contains ${backupfile_list[@]} $1; then
  if ! contains $backupfile_list $1; then
    local backup_path="$1.bak.`date +%s`"
    echo "Backing up $1 to ${backup_path} before making changes"
    cp -p $1 $backup_path

    # Append to the array, so we don't need to back it up again later
    # backupfile_list+=($1)
    backupfile_list="$backupfile_list $1"
  fi
}

# This function searches for an element in an array returning 1 if it exists.
#
# $1 - array
# $2 - item to search for
#
# Example:
#
#   myarray=('element1', 'element2')
#   if contains ${myarray[@]}, "element1'; then
#     echo "element1 exists in the array"
#   fi
#
function contains() {
#   local n=$#
#   local value=${!n}
#   for ((i=1;i < $#;i++)); do
#     if [ "${!i}" == "${value}" ]; then
#       return 0
#     fi
#   done
#   return 1
  echo "$1" | grep -q "$2"
}

# This function wraps sed for a line focused search and replace.
#
# * Makes sure its atomic by writing to a temp file and moving it _after_
# * Escapes any forward slashes and ampersands on the RHS for you
#
# $1 - regexp to match
# $2 - line to replace
# $3 - file to operate on
#
# Example:
#
#    replaceline "^$mysetting.*" "mysetting = myvalue" /etc/myconfig
#
function replaceline {
  backupfile $3
  tmp=$3.tmp.`date +%s`
  sed "s/$1/$(echo $2 | sed -e 's/[\/&]/\\&/g')/g" $3 > $tmp
  mv $tmp $3
  chmod 644 $3
}

# This function comments out a line in a file, based on a regexp
#
# $1 = regexp to match
# $2 = file to operate on
#
# Example:
#
#    commentline "^$mysetting.*" /etc/myconfig
#
function commentline {
  backupfile $2
  tmp=$2.tmp.`date +%s`
  sed "/$1/ s/^/# /" $2 > $tmp
  mv $tmp $2
}

# This function appends a line to a file
#
# $1 - line to append
# $2 - file to operate on
#
# Example:
#
#    appendline "mysetting = myvalue" /etc/myconfig
#
function appendline {
  backupfile $2
  tmp=$2.tmp.`date +%s`
  cat $2 > ${tmp}
  echo $1 >> ${tmp}
  mv ${tmp} $2
}

# This function copies the necessary PEM files from Puppet to the PuppetDB
# SSL directory.
#
# This expects various environment variables to have already been set to work.
function copy_pem_from_puppet {
  # orig_files=($orig_ca_file $orig_private_file $orig_public_file)
  orig_files="$orig_ca_file $orig_private_file $orig_public_file"
  # for orig_file in "${orig_files[@]}"; do
  for orig_file in $orig_files; do
    if [ ! -e $orig_file ]; then
      echo "Warning: Unable to find all puppet certificates to copy"
      echo
      echo "  This tool requires the following certificates to exist:"
      echo
      echo "  * $orig_ca_file"
      echo "  * $orig_private_file"
      echo "  * $orig_public_file"
      echo
      echo "  These files may be missing due to the fact that your host's Puppet"
      echo "  certificates may not have been signed yet, probably due to the"
      echo "  lack of a complete Puppet agent run. Try running puppet first, for"
      echo "  example:"
      echo
      echo "      puppet agent --test"
      echo
      echo "  Afterwards re-run this tool then restart PuppetDB to complete the SSL"
      echo "  setup:"
      echo
      echo "      ${ssl_command} -f"
      exit 1
    fi
  done
  rm -rf $ssl_dir
  mkdir -p $ssl_dir
  echo "Copying files: ${orig_ca_file}, ${orig_private_file} and ${orig_public_file} to ${ssl_dir}"
  cp -pr $orig_ca_file $ca_file
  cp -pr $orig_private_file $private_file
  cp -pr $orig_public_file $public_file
}

########
# MAIN #
########

# Gather command line options
while getopts "ifh" opt;
do
  case $opt in
    i)
      interactive=true ;;
    f)
      force=true ;;
    h)
      usage ;;
    *)
      usage ;;
  esac
done

${interactive:=false}
${force:=false}

# Deal with interactive setups differently to non-interactive
if $interactive
then
    echo "interactive mode not yet implemented"
    exit 1
#   dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#   cd $dir
#   answers_file="puppetdb-ssl-setup-answers.txt"
#   if [ -f "$answers_file" ]
#   then
#     echo "Reading answers file '$answers_file'"
#     . $answers_file
#   fi

#   vars=( agent_confdir agent_vardir puppetdb_confdir )
#   prompts=( "Puppet Agent confdir" "Puppet Agent vardir" "PuppetDB confdir" )

#   for (( i=0; i<${#vars[@]}; i++ ))
#   do
#     read -p "${prompts[$i]} [${!vars[$i]}]: " input
#     export ${vars[$i]}=${input:-${!vars[$i]}}
#   done

#   cat /dev/null > $answers_file
#   for (( i=0; i<${#vars[@]}; i++ ))
#   do
#     echo "${vars[$i]}=${!vars[$i]}" >> $answers_file
#   done
else
  # This should be run on the host with PuppetDB
  PATH=/opt/puppetlabs/bin:/opt/puppet/bin:$PATH
  # agent_confdir=`puppet agent --configprint confdir`
  agent_confdir="/etc/puppetlabs/puppet"
  # agent_vardir=`puppet agent --configprint vardir`
  agent_vardir="/etc/puppetlabs/puppet/cache"
  # user=<%= EZBake::Config[:user] %>
  # group=<%= EZBake::Config[:group] %>
  user=$USER
  group=$GROUP

  puppetdb_confdir="/etc/puppetlabs/puppetdb"
fi

set -e

mycertname="pdb"

# orig_public_file=`puppet agent --confdir=$agent_confdir --vardir=$agent_vardir --configprint  hostcert`
orig_public_file="/etc/puppetlabs/puppet/ssl/certs/${mycertname}.pem"
# orig_private_file=`puppet agent --confdir=$agent_confdir --vardir=$agent_vardir --configprint hostprivkey`
orig_private_file="/etc/puppetlabs/puppet/ssl/private_keys/${mycertname}.pem"
# orig_ca_file=`puppet agent --confdir=$agent_confdir --vardir=$agent_vardir --configprint localcacert`
orig_ca_file="/etc/puppetlabs/puppet/ssl/certs/ca.pem"

ssl_dir=${puppetdb_confdir}/ssl

pw_file=${ssl_dir}/puppetdb_keystore_pw.txt
keystore_file=${ssl_dir}/keystore.jks
truststore_file=${ssl_dir}/truststore.jks

private_file=${ssl_dir}/private.pem
public_file=${ssl_dir}/public.pem
ca_file=${ssl_dir}/ca.pem

jettyfile="${puppetdb_confdir}/conf.d/jetty.ini"

# Scan through the old settings to see if any are still set, exiting and
# prompting the user for the -f switch to force the tool to run anyway.
if ! ${force}; then
  # old_settings=('key-password' 'trust-password' 'keystore' 'truststore')
  # new_settings=('ssl-key' 'ssl-cert' 'ssl-ca-cert')
  old_settings="key-password trust-password keystore truststore"
  new_settings="ssl-key ssl-cert ssl-ca-cert"
  # for old_setting in "${old_settings[@]}"; do
  for old_setting in $old_settings; do
    if grep -qe "^${old_setting}" $jettyfile; then
      # If we see both old settings and new, it may point to a problem so alert
      # the user.
      # for new_setting in "${new_settings[@]}"; do
      for new_setting in $new_settings; do
        if grep -qe "^${new_setting}" $jettyfile; then
          echo "Error: Your Jetty configuration file contains legacy entry '${old_setting}' and a new entry '${new_setting}'"
          echo
          echo "  By default PuppetDB uses the new settings over the old ones,"
          echo "  which indicates your setup is probably okay, but removing"
          echo "  the old settings is recommended for clarity."
          echo
          echo "  Use the following to ignore this error and force this tool to repair"
          echo "  your setup anyway:"
          echo
          echo "      ${ssl_command} -f"
          echo
          exit 1
        fi
      done

      # Otherwise cowardly refuse to make a change without -f
      echo "Error: Your Jetty configuration file contains legacy entry '${old_setting}'"
      echo
      echo "  PuppetDB now provides a PEM based mechanism for retrieving SSL"
      echo "  related files as opposed to its legacy Java Keystore mechanism."
      echo
      echo "  Your configuration indicates you may have a legacy keystore based setup,"
      echo "  and if we modify this on our own we may break things. Especially if"
      echo "  there has been specialized setup in the past, for example"
      echo "  the keystores may have been created without 'puppetdb ssl-setup'."
      echo
      echo "  Your can however force this tool to overwrite your existing"
      echo "  configuration with the newer PEM based configuration with:"
      echo
      echo "      ${ssl_command} -f"
      echo
      exit 1
    fi
  done
fi

# Deal with pem files
if [ -f $ca_file -a -f $private_file -a -f $public_file ]; then
  echo "PEM files in ${ssl_dir} already exists, checking integrity."

  # filediffs=(
  #   "${orig_ca_file}:${ca_file}"
  #   "${orig_private_file}:${private_file}"
  #   "${orig_public_file}:${public_file}"
  # )
  filediffs="
    ${orig_ca_file}:${ca_file}
    ${orig_private_file}:${private_file}
    ${orig_public_file}:${public_file}
  "

  # for i in "${filediffs[@]}"; do
  for i in $filediffs; do
    orig="${i%%:*}"
    new="${i#*:}"

    if ! diff -q $orig $new > /dev/null; then
      echo "Warning: ${new} does not match the file used by Puppet (${orig})"
    fi
  done

  if $force; then
    echo "Overwriting existing PEM files due to -f flag"
    copy_pem_from_puppet
  fi
else
  echo "PEM files in ${ssl_dir} are missing, we will move them into place for you"
  copy_pem_from_puppet
fi

# Fix SSL permissions
chmod 600 ${ssl_dir}/*
chmod 700 ${ssl_dir}
chown -R ${user}:${group} ${ssl_dir}

if [ -f "$jettyfile" ] ; then
  # Check settings are correct and fix or warn
  # settings=(
  #   "ssl-host:0.0.0.0"
  #   "ssl-port:8081"
  #   "ssl-key:${private_file}"
  #   "ssl-cert:${public_file}"
  #   "ssl-ca-cert:${ca_file}"
  # )
  settings="
    ssl-host:0.0.0.0
    ssl-port:8081
    ssl-key:${private_file}
    ssl-cert:${public_file}
    ssl-ca-cert:${ca_file}
  "

  # for i in "${settings[@]}"; do
  for i in $settings; do
    setting="${i%%:*}"
    value="${i#*:}"

    if grep -qe "^${setting}" ${jettyfile}; then
      if grep -qe "^${setting}[[:space:]]*=[[:space:]]*${value}$" ${jettyfile}; then
        echo "Setting ${setting} in ${jettyfile} already correct."
      else
        if $force; then
          replaceline "^${setting}.*" "${setting} = ${value}" ${jettyfile}
          echo "Updated setting ${setting} in ${jettyfile}."
        else
          echo "Warning: Setting ${setting} in ${jettyfile} should be ${value}. This can be remedied with ${ssl_command} -f."
        fi
      fi
    else
      if grep -qE "^# ${setting} = <[A-Za-z_]+>$" ${jettyfile}; then
        replaceline "^# ${setting}.*" "${setting} = ${value}" ${jettyfile}
        echo "Updated default settings from package installation for ${setting} in ${jettyfile}."
      else
        if $force; then
          echo "Appending setting ${setting} to ${jettyfile}."
          appendline "${setting} = ${value}" ${jettyfile}
        else
          echo "Warning: Could not find active ${setting} setting in ${jettyfile}. Include that setting yourself manually. Or force with ${ssl_command} -f."
        fi
      fi
    fi
  done

  # Check old settings are commented out, and fix or warn
  # settings=('keystore' 'truststore' 'key-password' 'trust-password')
  settings="keystore truststore key-password trust-password"
  # for setting in "${settings[@]}"; do
  for setting in $settings; do
    if grep -qe "^${setting}" ${jettyfile}; then
      if $force; then
        echo "Commenting out setting '${setting}'"
        commentline "^${setting}" ${jettyfile}
      else
        echo "Warning: The setting '${setting}' is not commented out in ${jettyfile}. Allow us to comment it out for you with ${ssl_command} -f."
      fi
    fi
  done

else
  echo "Error: Unable to find PuppetDB Jetty configuration at ${jettyfile} so unable to provide automatic configuration for that file."
  echo
  echo "   Confirm the file exists in the path specified before running the"
  echo "   tool again. The file should have been created automatically when"
  echo "   the package was installed."
fi

if $interactive
then
  echo "Certificate generation complete.  You will need to make sure that the puppetdb.conf"
  echo "file on your puppet master looks like this:"
  echo
  echo "    [main]"
  echo "    server = ${mycertname}"
  echo "    port   = 8081"
  echo
  echo "And that the config.ini (or other *.ini) on your puppetdb system contains the"
  echo "following:"
  echo
  echo "    [jetty]"
  echo "    #host       = localhost"
  echo "    port        = 8080"
  echo "    ssl-host    = 0.0.0.0"
  echo "    ssl-port    = 8081"
  echo "    ssl-key     = ${private_file}"
  echo "    ssl-cert    = ${public_file}"
  echo "    ssl-ca-cert = ${ca_file}"
fi
