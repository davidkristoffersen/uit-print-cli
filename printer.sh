#!/usr/bin/env bash

help() {
	echo -e "Usage: ./printer [all|store|upload|print] file"
}

config="$HOME/.config/printer/"
cookies="${config}cookie.txt"
out="${config}out.html"
file="${config}test.txt"

urlmain="https://mobilprint.uit.no/"
urllogin="${urlmain}login.cfm"
urlpost="${urlmain}webprint.cfm"
urlprint="${urlmain}afunctions.cfm"
urlindex="${urlmain}index.cfm"

content_type="\"Content-Type: application/x-www-form-urlencoded\""

file_types="pdf|jpg|gif|png|tif|bmp|txt|docx|docm|dotx|dotm|xlsx|xlsm|xltx|xltm|xlsb|xlam|pptx|pptm|potx|potm|ppam|ppsx|ppsm|sldx|sldm|thmx"

store() {
	# echo -e "In store"
	read -p 'Username: ' username
	read -sp 'Password: ' password
	echo
	querylogin="\"LoginAction=login&LoginString=&Username=$username&Password=$password\""

	rm -f $cookies
	sh -c "curl -s -X POST $urllogin -d $querylogin -H $content_type -c $cookies"
}

upload() {
	# echo -e "In upload"
	sh -c "curl -s -F 'type=file' -b $cookies -F 'FileToPrint=@$1' -o $out $urlpost"
}

wait_on_upload() {
	# echo "Waiting"
	sleep 5
}

print_f() {
	# echo -e "In print"
	# Poll check if upload is complete
	wait_on_upload

	sh -c "curl -s -b $cookies -o $out $urlindex"
	jid="$(pup 'input[name=JID]' <$out | head -1 | grep -Po "(?<=value=\").*(?=\")")"
	pid="$(pup 'input[name=PID]' <$out | head -1 | grep -Po "(?<=value=\").*(?=\")")"
	pagefrom="$(pup 'input[name=PageFrom]' <$out | head -1 | grep -Po "(?<=value=\")\d*(?=\")")"
	pageto="$(pup 'input[name=PageTo]' <$out | head -1 | grep -Po "(?<=value=\")\d*(?=\")")"

	queryprint="JID=$jid&PID=$pid&NumberOfCopies=1&PageFrom=$pagefrom&PageTo=$pageto"
	queryprint="${queryprint}&Duplex=1&PrintBW=True&method=printjob"

	sh -c "curl -s -X POST -H $content_type -d '$queryprint' $urlprint -b $cookies" >/dev/null
}

mkdir -p $config

if [ ! -z "$1" ]; then
	if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
		help
		exit
	fi

	p_type=""
	file=""
	if [ "$#" -eq 1 ]; then
		p_type="all"
		file=$1
	elif [ "$#" -eq 2 ]; then
		p_type=$1
		file=$2
	else
		echo "Invalid number of arguments"
		help
		exit
	fi

	if [ -f "$file" ]; then
		# Input fileformats: Microsoft Office and OpenOffice
		if ! [[ "${file: -3}" =~ ^($file_types)$ ]]; then
			echo "Invalid file type"
			echo -e "Supported file types:\n$file_types"
			exit
		elif (($(stat -c %s $file) == 0)); then
			echo "File is empty"
			exit
		fi
	else
		echo -e "File: \"$file\"\tdoes not exist"
		exit
	fi

	if [ "$p_type" == "all" ]; then
		touch $out
		if [ ! -f "$cookies" ] || (($(($(date +%s) - $(stat -c %Y $cookies))) > 120)); then
			store
		fi
		upload "$file"
		print_f
	elif [ "$p_type" == "store" ]; then
		store
	elif [ "$p_type" == "upload" ]; then
		touch $out
		upload "$file"
	elif [ "$p_type" == "print" ]; then
		touch $out
		print_f
	else
		echo -e "Print type argument: \"$p_type\"\tis invalid"
		help
	fi
else
	echo "Invalid number of arguments"
	help
fi
