#!/bin/bash

if [[ $# -lt 1 ]] || [[ $1 = "-h" ]] || [[ $1 = "--help" ]] || [[ $1 = "-help" ]]; then
	echo "Please provide a csv file in usermanager.sh format"
	echo "example:"
	echo "		./check_for_lastlog.sh a_usermanager_userlist.csv"
elif [[ $(head -n 1 $1 2>/dev/null | tr -cd , | wc -c) -ne 4 ]]; then
	echo "Incorrect format file"
	exit 1
else
	cat $1 | cut -d , -f 5 >tmp
	lastlog | grep -f tmp | cut -f 1 >tmp2 # en algunos sistemas hay que comentar esta linea y descomentar la siguiente
	#lastlog | grep -f tmp | cut -f 1 " " >tmp2
	lastlog | grep -f tmp | grep "\*\*" | cut -f 1 >tmp3

	echo "USERS LOG ACTIVITY REPORT FOR $(hostname)"
	echo ""
	echo "Active users"
	echo "------------------------------------------------"
	while read L; do
		grep $L /etc/passwd | cut -d : -f 1,3
	done <tmp2
	echo ""
	echo "Users who have never logged in:"
	echo "------------------------------------------------"
	while read L; do
		grep $L /etc/passwd | cut -d : -f 1,3
	done <tmp3
	echo ""
	echo "Users from input file not found on this system:"
	echo "------------------------------------------------"

	while read L; do
		grep $L tmp2 >/dev/null || grep $L $1 | cut -d , -f 5,4
	done <tmp

	rm tmp tmp2 tmp3

fi
