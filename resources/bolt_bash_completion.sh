#####################################################################
###
### Bash autocompletion for bolt
### include this file in your .bash_profile or .bashrc to use completion
### "source bolt_bash_completion.sh"
###
### Marc Schoechlin ms-github@256bit.org

_bolt()
{
    local cur=${COMP_WORDS[COMP_CWORD]}
    local prev=${COMP_WORDS[COMP_CWORD-1]}
    local next=""

    local all_options="-q, --query --noop --description --params -u, --user -p, --password --private-key --[no-]host-key-check --[no-]ssl --[no-]ssl-verify --run-as --sudo-password -c, --concurrency --modulepath --boltdir --configfile --inventoryfile --transport --connect-timeout --[no-]tty --tmpdir --format --[no-]color -h, --help --verbose --debug --trace --version"

    case $prev in
      bolt)
         next="command file task plan"
		;;
      command)
         next="run"
      ;;
      file)
         next="upload"
      ;;
      task)
         next="show run"
      ;;
      plan)
         next="show run"
      ;;
      run|upload|show)
         next=""
      ;;
      --nodes|-n)
         # TODO: add automatic lookup here, ideally bolt should have a lookup function suitable for this 
         # to provide completions from the ~/.puppetlabs/bolt/inventory.yaml file
         next=""
      ;;
      --query|-q|--description|--params|--user|-u|-p|--password|--private-key|--run-as|--sudo-password|--concurrency|-c|--modulepath|--boltdir|--configfile|--inventoryfile|--transport|--connect-timeout|--tmpdir|--format)
         next=""
         ;;
      *)
         next="$all_options"
         ;;
     esac

    # Sort the options
    COMPREPLY=( $(compgen -W "$next" -- $cur) )
}

complete -F _bolt bolt
