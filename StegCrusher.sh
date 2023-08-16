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
# readme.md rework
# replace file extension check with magic numbers check
# save dictionary fragments in /tmp/
# show progress while cracking
# replace GNU Parallel with built-in parallel mechanisms
# parse arguments with getops

declare -ir THREADS="$(nproc)" # number of threads = number of processing units
readonly WORDLIST_FRAGMENT_NAME='.StegCrusher_tmp_'

readonly DEPENDENCIES=(
'parallel'
'steghide'
)

function print_usage()
{
    echo -e 'Usage:\n\tStegCrusher.sh "${STEGO_FILE}" "${WORDLIST_FILE}"\n\toutput file will be "${STEGO_FILE}".out in case of success' >&2
}

# arguments number check
if [ ${#} -ne 2 ]
then
    print_usage
    exit 1
fi

readonly STEGO_FILE="${1}"
readonly WORDLIST_FILE="${2}"

# dependencies check
for dependency in "${DEPENDENCIES[@]}"
do
    if ! command -v "${dependency}" &> '/dev/null'
    then
        echo 'ERROR - you need to have '"${dependency}"' installed in order to use StegCrusher.sh' >&2
        echo 'INFO - installation in Debian-based distros: sudo apt install '"${dependency}" >&2
        exit 1
    fi
done

# working directory permissions check
if [ ! -r "${PWD}" ] || [ ! -w "${PWD}" ]
then
    echo 'ERROR - you need read and write permissions in the working directory in order to use StegCrusher.sh' >&2
    print_usage
    exit 1
fi

# stego file permissions check
if [ ! -f "${STEGO_FILE}" ] || [ ! -r "${STEGO_FILE}" ]
then
    echo 'ERROR - the stego file "'"${STEGO_FILE}"'" passed as 1st argument either does not exist or is not readable' >&2
    print_usage
    exit 1
fi

# stego file extension check
if [[ ! "${STEGO_FILE}" =~ ^.*\.(jpg|jpeg|bmp|wav|au)$ ]]
then
    echo 'ERROR - the stego file extension used at the 1st argument "'"${STEGO_FILE}"'" is not supported' >&2
    echo 'INFO - supported extensions: jpg, jpeg, bmp, wav, au' >&2
    print_usage
    exit 1
fi

# wordlist file permissions check
if [ ! -f "${WORDLIST_FILE}" ] || [ ! -r "${WORDLIST_FILE}" ]
then
    echo 'ERROR - the wordlist file "'"${WORDLIST_FILE}"'" passed as 2nd argument either does not exist or is not readable' >&2
    print_usage
    exit 1
fi

# output file existence check
if [ -e "${STEGO_FILE}.out" ]
then
    echo 'ERROR - the output file "'"${STEGO_FILE}.out"'" already exists!' >&2
    print_usage
    exit 1
fi

# checks finished, cracking start
echo 'Trying to crack the stego file "'"${STEGO_FILE}"'" with wordlist "'"${WORDLIST_FILE}"'" using '"${THREADS}"' threads ...' >&2

# dictionary split to distribute the computing load (fragments will be deleted later)
declare -ir LINES_PER_THREAD="$(wc --lines "${WORDLIST_FILE}" | cut --delimiter=' ' --fields='1' | xargs -I {} bash -c 'echo "$(( {} / THREADS + 1 ))"')"
split --lines="${LINES_PER_THREAD}" "${WORDLIST_FILE}" "${WORDLIST_FRAGMENT_NAME}"

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
ls "${WORDLIST_FRAGMENT_NAME}"* | xargs parallel --no-notice --arg-sep , StegCrusher_main "${STEGO_FILE}" "${WORDLIST_FRAGMENT_NAME}" ,

if [ -f "${STEGO_FILE}.out" ]

# cracking success
then
    echo 'INFO - crack succeeded, check "'"${STEGO_FILE}.out"'" to see the hidden data in the stego file "'"${STEGO_FILE}"'"' >&2
    cat "${WORDLIST_FRAGMENT_NAME}" | xargs echo 'INFO - the password used was: ' >&2
    rm --force "${WORDLIST_FRAGMENT_NAME}"*
    exit 0

# cracking failure
else
    echo 'ERROR - crack failed, no hidden data found in the stego file "'"${STEGO_FILE}"'" using "'"${WORDLIST_FILE}"'" as wordlist' >&2
    rm --force "${WORDLIST_FRAGMENT_NAME}"*
    exit 1
fi
