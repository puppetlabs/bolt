#####################################################################
###
### Bash autocompletion for bolt
### include this file in your .bash_profile or .bashrc to use completion
### "source bolt_bash_completion.sh"
###
### Marc Schoechlin ms-github@256bit.org

get_json_keys() {
/opt/puppetlabs/bolt/bin/ruby <<-EOF
  require 'json'
  data = JSON.parse(File.read("${1}"))
  puts data.keys.uniq.sort.join(' ')
EOF
}

_bolt_complete() {
  local prev
  local cur
  # Get the current word and previous word without colons
  _get_comp_words_by_ref -n : cur
  _get_comp_words_by_ref -n : prev

  local next=""
  local subcommand=${COMP_WORDS[1]}
  [[ ${#COMP_WORDS[@]} -gt 2 ]] && local action=${COMP_WORDS[2]}
  local context_opts="-m --modulepath --project"
  local global_opts="--clear-cache -h --help --log-level --version"
  local inventory_opts="-q --query --rerun -t --targets"
  local authentication_opts="-u --user -p --password --password-prompt --private-key --host-key-check --no-host-key-check --ssl --no-ssl --ssl-verify --no-ssl-verify"
  local escalation_opts="--run-as --sudo-password --sudo-password-prompt --sudo-executable"
  local run_context_opts="-c --concurrency -i --inventoryfile --save-rerun --no-save-rerun --cleanup --no-cleanup"
  local transport_opts="--transport --connect-timeout --tty --no-tty --native-ssh --no-native-ssh --ssh-command --copy-command"
  local display_opts="--format --color --no-color -v --verbose --no-verbose --trace --stream"
  local action_opts="${inventory_opts} ${context_opts} ${authentication_opts} ${escalation_opts} ${run_context_opts} ${transport_opts} ${display_opts}"
  local apply_opts="--compile-concurrency --hiera-config"
  local file_opts=" -m --modulepath --project --private-key -i --inventoryfile --hiera-config "

  # If there's only one word and it's "bolt", tab complete the subcommand
  if [ $COMP_CWORD -eq 1 ]; then
    next="apply command file group guide inventory lookup module plan plugin project script secret task"
  fi

  # Tab complete files for options that accept files. The spaces are important!
  # They make it so `bolt inventory` isn't confused with `--inventoryfile`.
  if [[ $file_opts =~ " ${prev} " ]]; then
    next=$(compgen -f -d "" -- $cur)
  # Handle tab completing enumerable CLI options
  elif [ "$prev" == "--log-level" ]; then
    next="trace debug info warn error fatal any"
  elif [ "$prev" == "--transport" ]; then
    next="docker local lxd pcp podman remote ssh winrm"
  elif [ "$prev" == "--format" ]; then
    next="human json rainbow"
  else
    # Once we have subcommands, tab complete actions
    case $subcommand in
      apply)
        next="${action_opts} ${apply_opts} -e --execute"
        ;;
      command)
        if [ $COMP_CWORD -eq 2 ]; then
          next="run"
        elif [ $action = "run" ]; then
          next="${action_opts} --env-var"
        fi
        ;;
      file)
        if [ $COMP_CWORD -eq 2 ]; then
          next="download upload"
        else
          case $action in
            download) next="${action_opts} --tmpdir";;
            upload) next=$action_opts;;
          esac
        fi
        ;;
      group)
        if [ $COMP_CWORD -eq 2 ]; then
          next="show"
        elif [ $action == 'show' ]; then
          next="--project --format --inventoryfile"
        fi
        ;;
      guide)
        next="--format"
        ;;
      inventory)
        if [ $COMP_CWORD -eq 2 ]; then
          next="show"
        elif [ $action == 'show' ]; then
          next="${inventory_opts} --project --format --inventoryfile --detail"
        fi
        ;;
      lookup)
        next="${action_opts} --hiera-config --plan-hierarchy"
        ;;
      module)
        if [ $COMP_CWORD -eq 2 ]; then
          next="add generate-types install show"
        else
          case $action in
            add | install) next="--project";;
            generate-types) next="${context_opts}";;
            show) next="${context_opts} --filter --format";;
          esac
        fi
        ;;
      plan)
        if [ $COMP_CWORD -eq 2 ]; then
          next="convert new run show"
        elif [[ ($COMP_CWORD -eq 3 || \
          ( $COMP_CWORD -eq 4 && "$cur" == *"::" ) || \
          ( $COMP_CWORD -eq 5 && "$cur" == *"::"* )) &&
          $action != "new" ]]; then

          if [ -f "${PWD}/.plan_cache.json" ]; then
            # Use Puppet's ruby instead of jq since we know it will be there.
            next=$(get_json_keys "${PWD}/.plan_cache.json")
          elif [ -f "${HOME}/.puppetlabs/bolt/.plan_cache.json" ]; then
            next=$(get_json_keys "${HOME}/.puppetlabs/bolt/.plan_cache.json")
          else
            case $action in
              convert) next="${context_opts}";;
              new) next="--project --pp";;
              run) next="${action_opts} ${apply_opts} --params --tmpdir";;
              show) next="${context_opts} --filter --format";;
            esac
          fi
        else
          case $action in
            convert) next="${context_opts}";;
            new) next="--project --pp";;
            run) next="${action_opts} ${apply_opts} --params --tmpdir";;
            show) next="${context_opts} --filter --format";;
          esac
        fi
        ;;
      plugin)
        if [ $COMP_CWORD -eq 2 ]; then
          next="show"
        else
          next="${context_opts} --format --color --no-color"
        fi
        ;;
      project)
        if [ $COMP_CWORD -eq 2 ]; then
          next="init migrate"
        else
          case $action in
            init) next="--modules";;
            migrate) next="--project --inventoryfile";;
          esac
        fi
        ;;
      script)
        if [ $COMP_CWORD -eq 2 ]; then
          next="run"
        elif [[ $COMP_CWORD -eq 3 && $action == 'run' ]]; then
          # List files and directories
          next=$(compgen -f -d "" -- $cur)
        elif [ $action == 'run' ]; then
          next="${action_opts} --env-var --tmpdir"
        fi
        ;;
      secret)
        if [ $COMP_CWORD -eq 2 ]; then
          next="createkeys encrypt decrypt"
        else
          case $action in
            createkeys) next="${context_opts} --plugin --force";;
            encrypt | decrypt) next="${context_opts} --plugin";;
          esac
        fi
        ;;
      task)
        if [ $COMP_CWORD -eq 2 ]; then
          next="run show"
        elif [[ $COMP_CWORD -eq 3 || \
          ( $COMP_CWORD -eq 4 && "$cur" == *"::" ) || \
          ( $COMP_CWORD -eq 5 && "$cur" == *"::"* ) ]]; then
          if [ -f "${PWD}/.task_cache.json" ]; then
            # Use Puppet's ruby instead of jq since we know it will be there.
            next=$(get_json_keys "${PWD}/.task_cache.json")
          elif [ -f "${HOME}/.puppetlabs/bolt/.task_cache.json" ]; then
            next=$(get_json_keys "${HOME}/.puppetlabs/bolt/.task_cache.json")
          else
            case $action in
              run) next="${action_opts} --env-var --tmpdir";;
              show) next="${context_opts} --filter --format";;
            esac
          fi
        else
          case $action in
            run) next="${action_opts} --env-var --tmpdir";;
            show) next="${context_opts} --filter --format";;
          esac
        fi
        ;;
    esac
  fi

  # If any of the next options are flags, we've reached the end of the
  # building-a-Bolt-command part and can re-enable file and directory name
  # completion and include Bolt's global flags.
  if [[ "$next" =~ "--" ]]; then
    next+=" ${global_opts}"
  fi

  COMPREPLY=($(compgen -W "$next" -- $cur))
  __ltrim_colon_completions $cur
}

complete -F _bolt_complete bolt
