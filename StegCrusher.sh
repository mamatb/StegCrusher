#!/usr/bin/env bash

# StegCrusher is a steganography brute-force tool that takes advantage of parallel computing
# author - mamatb (t.me/m_amatb)
# location - https://github.com/mamatb/StegCrusher
# style guide - https://google.github.io/styleguide/shellguide.html

# acknowledgement - this tool is based on Paradoxis' StegCracker (https://github.com/Paradoxis/StegCracker)
# acknowledgement - this tool is built upon Stefan Hetzl's Steghide (https://github.com/StefanoDeVuono/steghide)
# acknowledgement - O. Tange (2011): GNU Parallel - The Command-Line Power Tool

# TODO
#
# readme.md
# replace file extension check with magic numbers check
# save dictionary fragments in /tmp/
# show progress while cracking
# use colored output
# replace GNU Parallel with built-in parallel mechanisms
# parse arguments with getops

# number of threads = number of available processing units
declare -ir THREADS="$(nproc)"

# other declarations
readonly WORDLIST_FRAGMENT_NAME='.StegCrusher_tmp_'
function print_usage()
{
    echo -e 'Usage:\n\t'"${0}"' <stego_file> <wordlist_file>\n\toutput file will be <stego_file>.out in case of success' >&2
}

# arguments usage check
if [ ${#} -ne 2 ]
then
    print_usage
    exit 1
fi

# parallel installation check (parallel computing tool)
if ! command -v 'parallel' &> '/dev/null'
then
    echo 'ERROR - you need to have parallel installed in order to use "'"${0}"'"' >&2
    echo 'INFO - installation in Debian-based distros: sudo apt install parallel' >&2
    exit 1
fi

# steghide installation check (steganography tool)
if ! command -v 'steghide' &> '/dev/null'
then
    echo 'ERROR - you need to have steghide installed in order to use "'"${0}"'"' >&2
    echo 'INFO - installation in Debian-based distros: sudo apt install steghide' >&2
    exit 1
fi

# working directory permissions check
if [ ! -r "${PWD}" ] || [ ! -w "${PWD}" ]
then
    echo 'ERROR - you need read and write permissions in the working directory in order to use "'"${0}"'"' >&2
    print_usage
    exit 1
fi

# stego file permissions check
if [ ! -f "${1}" ] || [ ! -r "${1}" ]
then
    echo 'ERROR - the stego file "'"${1}"'" passed as 1st argument either does not exist or is not readable' >&2
    print_usage
    exit 1
fi

# stego file extension check
if [[ ! "${1}" =~ ^.*\.(jpg|jpeg|bmp|wav|au)$ ]]
then
    echo 'ERROR - the stego file extension used at the 1st argument "'"${1}"'" is not supported' >&2
    echo 'INFO - supported extensions: jpg, jpeg, bmp, wav, au' >&2
    print_usage
    exit 1
fi

# wordlist file permissions check
if [ ! -f "${2}" ] || [ ! -r "${2}" ]
then
    echo 'ERROR - the wordlist file "'"${2}"'" passed as 2nd argument either does not exist or is not readable' >&2
    print_usage
    exit 1
fi

# output file existence check
if [ -e "${1}.out" ]
then
    echo 'ERROR - the output file "'"${1}.out"'" already exists!' >&2
    print_usage
    exit 1
fi

# checking finished, stego cracking start
echo 'Trying to crack the stego file "'"${1}"'" with wordlist "'"${2}"'" using '"${THREADS}"' threads...' >&2

# dictionary split to distribute the computing load (fragments will be deleted later)
declare -ir LINES_PER_THREAD="$(wc --lines "${2}" | cut --delimiter=' ' --fields='1' | xargs -I {} bash -c 'echo "$(( {} / THREADS + 1 ))"')"
split --lines="${LINES_PER_THREAD}" "${2}" "${WORDLIST_FRAGMENT_NAME}"

# main function
function StegCrusher_main()
{
    while read -r password
    do

        # exit if the password has already been found by other thread
        if [ -f "${2}" ]
        then
            exit 0

        # exit if the password is found
        else
            if steghide extract --stegofile "${1}" --extractfile "${1}.out" --passphrase "${password}" --force --quiet
            then
                echo -n "${password}" > "${2}"
                exit 0
            fi
        fi
    done < "${3}"
}

# parallel execution
export -f StegCrusher_main
ls "${WORDLIST_FRAGMENT_NAME}"* | xargs parallel --no-notice --arg-sep , StegCrusher_main "${1}" "${WORDLIST_FRAGMENT_NAME}" ,

# stego cracking end
unset -f StegCrusher_main

if [ -f "${1}.out" ]

# cracking success
then
    echo 'INFO - crack succeeded, check "'"${1}.out"'" to see the hidden data in the stego file "'"${1}"'"' >&2
    cat "${WORDLIST_FRAGMENT_NAME}" | xargs echo 'INFO - the password used was: ' >&2
    rm --force "${WORDLIST_FRAGMENT_NAME}"*
    exit 0

# cracking failure
else
    echo 'ERROR - crack failed, no hidden data found in the stego file "'"${1}"'" using "'"${2}"'" as wordlist' >&2
    rm --force "${WORDLIST_FRAGMENT_NAME}"*
    exit 1
fi
