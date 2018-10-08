#!/bin/bash

# StegCrusher is a steganography brute-force tool that takes advantage of parallel computing
# author - mamatb
# location - https://gitlab.com/mamatb/StegCrusher.git

# acknowledgement - this tool is based on Paradoxis' StegCracker (https://github.com/Paradoxis/StegCracker)
# acknowledgement - this tool is built upon Stefan Hetzl's Steghide (https://github.com/StefanoDeVuono/steghide)
# acknowledgement - O. Tange (2011): GNU Parallel - The Command-Line Power Tool


################


# number of threads = number of available processing units
THREADS=$(nproc)

# other declarations
WORDLIST_FRAGMENT_NAME=".StegCrusher_tmp_"
print_usage() {
	echo -e "Usage:\n\t${0} <stego_file> <wordlist_file>\n\toutput file will be <stego_file>.out in case of success"
}

# arguments usage check
if [ "${#}" != "2" ];
then
	print_usage
	exit 1
fi

# parallel installation check (parallel computing tool)
if [ ! "$(which parallel)" ];
then
	echo "ERROR - you need to have parallel installed in order to use the script \"${0}\""
	echo "INFO - installation in Debian-based distros: sudo apt install parallel"
	exit 1
fi

# steghide installation check (steganography tool)
if [ ! "$(which steghide)" ];
then
	echo "ERROR - you need to have steghide installed in order to use the script \"${0}\""
	echo "INFO - installation in Debian-based distros: sudo apt install steghide"
	exit 1
fi

# working directory permissions check
if [ ! -r "${PWD}" ] || [ ! -w "${PWD}" ];
then
	echo "ERROR - you need read and write permissions in the working directory in order to use the script \"${0}\""
	print_usage
	exit 1
fi

# stego file permissions check
if [ ! -f "${1}" ] || [ ! -r "${1}" ];
then
	echo "ERROR - the stego file \"${1}\" passed as 1st argument either does not exist or is not readable"
	print_usage
	exit 1
fi

# stego file extension check
if [[ ! "${1}" =~ ^.*\.(jpg|jpeg|bmp|wav|au)$ ]];
then
	echo "ERROR - the stego file extension used at the 1st argument \"${1}\" is not supported"
	echo "INFO - supported extensions: jpg, jpeg, bmp, wav, au"
	print_usage
	exit 1
fi

# wordlist file permissions check
if [ ! -f "${2}" ] || [ ! -r "${2}" ];
then
	echo "ERROR - the wordlist file \"${2}\" passed as 2nd argument either does not exist or is not readable"
	print_usage
	exit 1
fi

# output file existence check
if [ -e "${1}.out" ];
then
	echo "ERROR - the output file \"${1}.out\" already exists!"
	print_usage
	exit 1
fi

# checking finished, stego cracking start
echo "Trying to crack the stego file \"${1}\" with wordlist \"${2}\" using ${THREADS} threads..."

# dictionary split to distribute the computing load (fragments will be deleted later)
LINES_PER_THREAD="$(( $(wc -l "${2}" | awk '{print $1}') / THREADS + 1 ))"
split -l "${LINES_PER_THREAD}" "${2}" "${WORDLIST_FRAGMENT_NAME}"

# main function
StegCrusher_function() {
	while read -r PASSWORD;
	do

		# exit if the password has already been found by other thread
		if [ -f "${2}" ];
		then
			exit 0

		# exit if the password is found
		else
			if steghide extract -sf "${1}" -xf "${1}.out" -p "${PASSWORD}" -f &> /dev/null;
			then
				echo -n "${PASSWORD}" > "${2}"
				exit 0
			fi
		fi
	done < "${3}"
}

# parallel execution
export -f StegCrusher_function
parallel --no-notice --arg-sep , StegCrusher_function "${1}" "${WORDLIST_FRAGMENT_NAME}" , "$(ls "${WORDLIST_FRAGMENT_NAME}"*)"

# stego cracking end
unset -f StegCrusher_function

if [ -f "${1}.out" ];

# cracking success
then
	echo "INFO - crack succeeded, check \"${1}.out\" to see the hidden data in the stego file \"${1}\""
	echo "INFO - the password used was: $(cat "${WORDLIST_FRAGMENT_NAME}")"
	rm -f "${WORDLIST_FRAGMENT_NAME}"*
	exit 0

# cracking failure
else
	echo "ERROR - crack failed, no hidden data found in the stego file \"${1}\" using \"${2}\" as wordlist"
	rm -f "${WORDLIST_FRAGMENT_NAME}"*
	exit 1
fi