#!/bin/bash

# parallelStegCracker is a steganography brute-force tool that takes advantage of parallel computing
# author - mamatb
# location - https://gitlab.com/mamatb/parallelStegCracker.git

# acknowledgement - this tool is based on Paradoxis' StegCracker (https://github.com/Paradoxis/StegCracker)
# acknowledgement - this tool is built upon Stefan Hetzl's Steghide (https://github.com/StefanoDeVuono/steghide)
# acknowledgement - O. Tange (2011): GNU Parallel - The Command-Line Power Tool

unalias -a
THREADS="$(nproc)"
USAGE="Usage:\n\t$0 <file> <wordlist>\n\toutput file will be <file>.out in case of success"
WORDLIST_FRAGMENT_NAME="$(date +%s)_splitted_"

# usage check
if [ $# != '2' ];
then
        echo -e $USAGE
        exit 1
fi

# parallel installation check
if [[ ! $(which parallel) ]]; 
then
        echo "ERROR - you need to have parallel installed in order to use the script \"$0\""
        echo "INFO - installation in Debian-based distros: sudo apt install parallel"
        exit 1
fi

# steghide installation check
if [[ ! $(which steghide) ]]; 
then
        echo "ERROR - you need to have steghide installed in order to use the script \"$0\""
        echo "INFO - installation in Debian-based distros: sudo apt install steghide"
        exit 1
fi

# directory permissions check
if [ ! -r $(pwd) -o ! -w $(pwd) ];
then
        echo "ERROR - you need read and write permissions in the working directory in order to use the script \"$0\""
        echo -e $USAGE
        exit 1
fi

# file permissions check
if [ ! -f $1 -o ! -r $1 ];
then
        echo "ERROR - the file \"$1\" passed as 1st argument either does not exist or is not accesible"
        echo -e $USAGE
        exit 1
fi

# file extension check
if [[ ! $(echo $1 | egrep ".*\.(jpg|jpeg|bmp|wav|au)$") ]]; 
then
        echo "ERROR - the file extension used at the 1st argument \"$1\" is not supported"
        echo "INFO - supported extensions: jpg, jpeg, bmp, wav, au"
        echo -e $USAGE
        exit 1
fi

# wordlist permissions check
if [ ! -f $2 -o ! -r $2 ];
then
        echo "ERROR - the wordlist \"$2\" passed as 2nd argument either does not exist or is not accesible"
        echo -e $USAGE
        exit 1
fi

# output file check
if [ -f $1.out ];
then
        echo "ERROR - the output file \"$1.out\" already exists!"
        echo -e $USAGE
        exit 1
fi

# start
echo "Trying to crack file \"$1\" with wordlist \"$2\" using $THREADS threads..."
LINES_PER_THREAD="$(( $(wc -l $2 | egrep -o "^[0-9]*") / $THREADS + 1 ))"
split -l $LINES_PER_THREAD $2 $WORDLIST_FRAGMENT_NAME

StegCrack_function() {
        while read PASSWORD;
        do
                if steghide extract -sf $1 -xf $1.out -p $PASSWORD -f &> /dev/null;
                then
                        echo -n $PASSWORD > $2
                        exit 0
                fi
        done < $3
}

export -f StegCrack_function
parallel --no-notice --arg-sep , StegCrack_function $1 $WORDLIST_FRAGMENT_NAME , $(ls $WORDLIST_FRAGMENT_NAME*)

# end
unset -f StegCrack_function

if [ -f $1.out ];
then
        echo "INFO - file crack succeeded, check \"$1.out\" to see the hidden data in \"$1\""
        echo "INFO - the password used was: $(cat $WORDLIST_FRAGMENT_NAME)"
        rm $WORDLIST_FRAGMENT_NAME*
        exit 0
else
        echo "ERROR - file crack failed, no hidden data found in \"$1\" using \"$2\" as wordlist"
        rm $WORDLIST_FRAGMENT_NAME*
        exit 1
fi
