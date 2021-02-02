#####################################################################
###
### Bash autocompletion for bolt
### include this file in your .bash_profile or .bashrc to use completion
### "source bolt_bash_completion.sh"
###
### Marc Schoechlin ms-github@256bit.org

_bolt() {
	local cur=${COMP_WORDS[COMP_CWORD]}
	local prev=${COMP_WORDS[COMP_CWORD - 1]}
	[[ ${#COMP_WORDS[@]} -gt 2 ]] && local prevprev=${COMP_WORDS[COMP_CWORD - 2]}
	local next=""

	local all_options="--cleanup --color -c --concurrency --connect-timeout --format -h --help --host-key-check -i --inventoryfile --log-level -m --modulepath --no-cleanup --no-color --no-host-key-check --no-ssl --no-ssl-verify --no-tty --noop -p --password --password-prompt --private-key --project -q --query --run-as --ssl --ssl-verify --sudo-executable --sudo-password --sudo-password-prompt --tmpdir --trace --transport --tty -u --user -v --verbose --version"

	local general_opts="-h --help --format --version"
	local targeting_opts="-t --targets -q --query --rerun --save-rerun --no-save-rerun"
	local project_config_opts="--project"

	local inventory_list_cache_file="/tmp/bolt_inventory_cache_list.$$.tmp"

	if ([[ $prev == -* ]] || [[ $prevprev == -* ]]) && [[ " -t --targets --format --log-level --rerun " != *" ${prev} "* ]]
	then
		if [[ ${COMP_WORDS[1]} == "apply" ]]
		then
			prev=${COMP_WORDS[1]}
			prevprev=${COMP_WORDS[0]}
		else
			prev=${COMP_WORDS[2]}
			prevprev=${COMP_WORDS[1]}
		fi
	fi

	case $prev in
	*bolt)
		next="command file task plan project group inventory secret script apply"
		;;
	command | script)
		next="run"
		;;
	task)
		next="show run"
		;;
	plan)
		next="show run convert"
		;;
	file)
		next="upload"
		;;
	group | inventory)
		next="show"
		;;
	secret)
		next="createkeys encrypt decrypt"
		;;
	encrypt | decrypt | createkeys)
		next="-m --modulepath --plugin ${project_config_opts}"
		[[ $prev == "createkeys" ]] && next="${next} --force"
		;;
	module)
		next="install show generate-types"
		;;
	install)
		next="--log-level -m --modulepath ${project_config_opts}"
		;;
	show-modules | generate-types)
		next="--log-level -m --modulepath ${project_config_opts}"
		;;
	convert)
		next="--log-level -m -modulepath ${project_config_opts}"
		;;
	show)
		if [ "$prevprev" == "group" ]; then
			next="${project_config_opts} -i --inventoryfile --log-level"
		elif [ "$prevprev" == "inventory" ]; then
			next="${targeting_opts} ${project_config_opts} --detail -i --inventoryfile --log-level"
		elif [ "$prevprev" == "plan" ] || [ "$prevprev" == "task" ]; then
			next="${general_opts} ${project_config_opts} -m --modulepath --filter --format"
		fi
		;;
	run)
		next="${all_options} ${targeting_opts} --params --tmpdir --ssh-command --copy-command"
		[[ ${prevprev} == "plan" ]] && next="${next} --compile-concurrency --hiera-config"
		;;
	upload | apply)
		next="${all_options} ${targeting_opts} --ssh-command --copy-command"
		[[ ${prev} == "apply" ]] && next="${next} --compile-concurrency --hiera-config"
		;;
	project)
		next="init migrate"
		;;
	init)
		next="--log-level --modules"
		;;
	migrate)
		next="--log-level -i --inventoryfile ${project_config_opts}"
		;;
	-t | --targets)
		if [[ -f ${inventory_list_cache_file} ]]; then
			local next=$(cat ${inventory_list_cache_file})
		else
			local jsondata=$(bolt --detail --targets all inventory show | sed -e '$d')
			jsondata=${jsondata//\"/\\\"}

			next=$(
				/usr/bin/env ruby <<-EOF
					require 'json'
					jdata = JSON.parse("${jsondata}")
					puts jdata["targets"].map {|t|
						t["groups"] << t["name"]
					}.flatten.uniq.sort.join(' ')
				EOF
			)
			echo -n "${next}" >${inventory_list_cache_file}
		fi
		;;
	--format)
		next="json human"
		;;
	--log-level)
		next="debug info notice warn error fatal"
		;;
	--rerun)
		next="failure success"
		;;
	--query | -q | --params | --user | -u | -p | --password | --private-key | --run-as | --sudo-password | --concurrency | -c | --modulepath | --inventoryfile | --transport | --connect-timeout | --tmpdir | --format)
		next=""
		;;
	*)
		next="$all_options"
		;;
	esac

	# Sort the options
	COMPREPLY=($(compgen -W "$next $general_opts" -- $cur))
}

complete -F _bolt bolt
