#!/usr/bin/env bash
# template.sh - basic templating engine

# nightmare fuel
# render(array, template_file)
function render() {
	local template="$(cat "$2" | tr -d $'\01'$'\02' | sed 's/\&/�UwU�/g')"
	local -n ref=$1
	local tmp=$(mktemp)
	for key in ${!ref[@]}; do
		if [[ "$key" == "_"* ]]; then # iter mode
			local value=''
			subtemplate=$(mktemp)
			subtemplate_tmp=$(mktemp)
			echo "$template" | sed 's/\&/�UwU�/g' | grep "{{start $key}}" -A99999 | grep "{{end $key}}" -B99999 | tr -d $'\01'$'\02' | tr '\n' $'\01' > "$subtemplate"

			echo 's'$'\02''\{\{start '"$key"'\}\}.*\{\{end '"$key"'\}\}'$'\02''\{\{'"$key"'\}\}'$'\02'';' >> "$tmp"

			local -n asdf=${ref[$key]}
			value=''
			
			for j in ${!asdf[@]}; do
				local -n fdsa=_${asdf[$j]}

				# TODO: somewhere here, it should recurse. it does not.
				# recursion is fun! let's do recursion! 

				for _i in ${!fdsa[@]}; do
					echo 's'$'\02''\{\{\.'"$_i"'\}\}'$'\02'''"${fdsa[$_i]}"''$'\02''g;' | tr '\n' $'\01' | sed -E 's/'$'\02'';'$'\01''/'$'\02'';/g;s/'$'\02''g;'$'\01''/'$'\02''g;/g' >> "$subtemplate_tmp"
				done

				echo 's'$'\02''\{\{start '"$key"'\}\}'$'\02'$'\02' >> "$subtemplate_tmp"
				echo 's'$'\02''\{\{end '"$key"'\}\}'$'\02'$'\02' >> "$subtemplate_tmp"
				
				value+="$(cat "$subtemplate" | tr '\n' $'\01' | sed -E -f "$subtemplate_tmp" | tr $'\01' '\n')"
				rm "$subtemplate_tmp"
			done

			echo 's'$'\02''\{\{'"$key"'\}\}'$'\02'''"$value"''$'\02'';' >> "$tmp"
			rm "$subtemplate"
		elif [[ "$key" == "@"* && "${ref[$key]}" != '' ]]; then
			local value="$(sed -E 's/\&/�UwU�/g' <<< "${ref[$key]}")"
			echo 's'$'\02''\{\{\'"$key"'\}\}'$'\02'''"$value"''$'\02''g;' >> "$tmp"
		elif [[ "$key" == '?'* ]]; then
			_key="\\?${key/?/}"

			subtemplate=$(mktemp)
			echo 's'$'\02''\{\{start '"$_key"'\}\}(.*)\{\{end '"$_key"'\}\}'$'\02''\{\{(\1)\}\}'$'\02'';' >> "$subtemplate"
			cat <<< $(cat "$subtemplate" "$tmp") > "$tmp" # call that cat abuse

		elif [[ "${ref[$key]}" != "" ]]; then
			local value="$(html_encode "${ref[$key]}" | sed -E 's/\&/�UwU�/g')"
			echo 's'$'\02''\{\{\.'"$key"'\}\}'$'\02'''"$value"''$'\02''g;' >> "$tmp"
		else
			echo 's'$'\02''\{\{\.'"$key"'\}\}'$'\02'$'\02''g;' >> "$tmp"
		fi
	done

	cat "$tmp" | tr '\n' $'\01' | sed -E 's/'$'\02'';'$'\01''/'$'\02'';/g;s/'$'\02''g;'$'\01''/'$'\02''g;/g' > "${tmp}_"

	echo 's/\{\{start \?([a-zA-Z0-9_-]*[^}])\}\}.*\{\{end \?(\1)\}\}//g' >> "${tmp}_"
	template="$(tr '\n' $'\01' <<< "$template" | sed -E -f "${tmp}_" | tr $'\01' '\n')"
	sed -E 's/�UwU�/\&/g' <<< "$template"
	rm "$tmp"
}

# render_unsafe(array, template_file)
function render_unsafe() {
	local template="$(cat "$2")"
	local -n ref=$1
	local tmp=$(mktemp)
	for key in ${!ref[@]}; do
		if [[ "$key" == "_"* ]]; then # iter mode
			# grep "start _test" -A99999 | grep "end _test" -B99999
			local -n item_array=${ref[$key]}
			local value
			for ((_i = 0; _i < ${#item_array[@]}; _i++)); do
				value+="$(xxd -p <<< "${item_array[$_i]}" | tr -d '\n' | sed -E 's/../\\x&/g')"
			done
			echo 's/\{\{'"$key"'\}\}/'"$value"'/g' >> "$tmp"
		else
			local value="$(xxd -p <<< "${ref[$key]}" | tr -d '\n' | sed -E 's/../\\x&/g')"
			echo 's/\{\{\.'"$key"'\}\}/'"$value"'/g' >> "$tmp"
		fi
	done

	sed -E -f "$tmp" <<< "$template"
	rm "$tmp"
}


# mmmm this should be a library because i am so much copying those later
# _nested_random
function _nested_random() {
	dd if=/dev/urandom bs=1 count=16 status=none | xxd -p
}

# nested_declare(ref)
function nested_declare() {
	declare -g -a $1
}

# nested_add(ref, array)
function nested_add() {
	local nested_id=$(_nested_random)
	declare -n nested_ref=$2
	declare -g -A _$nested_id
	
	# poor man's array copy
	for k in ${!nested_ref[@]}; do
		declare -g -A _$nested_id[$k]="${nested_ref[$k]}"
	done
	
	local -n ref=$1
	ref+=("$nested_id")
}

# nested_get(ref, i)
function nested_get() {
	local -n ref=$1
	declare -g -n res=_${ref[$2]}
}
