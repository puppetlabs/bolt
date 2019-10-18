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
    local prevprev=${COMP_WORDS[COMP_CWORD-2]}
    local next=""

    local all_options="-q --query --noop --description --params -u --user -p --password --private-key --[no-]host-key-check --[no-]ssl --[no-]ssl-verify --run-as --sudo-password -c --concurrency --modulepath --boltdir --configfile --inventoryfile --transport --connect-timeout --tty --no-tty --tmpdir --format --color --no-color -h --help --verbose --debug --trace --version"

    local general_opts="-h --help --debug --format"
    case $prev in
      bolt)
         next="command file task plan group inventory puppetfile secret"
		;;
      --format)
         next="json human"
		;;
      secret)
         next="createkeys encrypt decrypt"
		;;
      puppetfile)
         next="install show-modules"
		;;
      command|script)
         next="run"
      ;;
      file)
         next="upload"
      ;;
      task)
         next="show run"
      ;;
      plan)
         next="show run convert"
      ;;
      run|upload)
         next="$all_options"
      ;;
      group)
         next="show"
      ;;
      inventory)
         next="show"
      ;;
      show)
         if [ "$prevprev" == "group" ];then
            next="--boltdir --configfile -i --inventoryfile"
         elif [ "$prevprev" == "inventory" ];then
            next="-n --nodes -q --query --description --boltdir --configfile -i --inventoryfile"
         fi
      ;;
      --nodes|-n|-t|--targets)
         # executing "bolt group show" or "bolt inventory show --nodes all" tends to be slowish
         # it might be a good idea to accelerate this
         groups="$(bolt group show|grep -v -P '\d+ groups'|tr '\n' ' ')"
         nodes="$(bolt inventory show --nodes all|grep -v -P '\d+ targets'|tr '\n' ' ')"
         next="$groups $nodes"
      ;;
      --query|-q|--description|--params|--user|-u|-p|--password|--private-key|--run-as|--sudo-password|--concurrency|-c|--modulepath|--boltdir|--configfile|--inventoryfile|--transport|--connect-timeout|--tmpdir|--format)
         next=""
         ;;
      *)
         next="$all_options"
         ;;
     esac

    # Sort the options
    COMPREPLY=( $(compgen -W "$next $general_opts" -- $cur) )
}

complete -F _bolt bolt
