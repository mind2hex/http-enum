#!/usr/bin/env bash

## @author:       Johan Alexis
## @github:       https://gihub.com/mind2hex

## Project Name:  http-enum.sh
## Description:   A simple script to enumerate http directories

## @style:        https://github.com/fryntiz/bash-guide-style

## @licence:      https://www.gnu.org/licences/gpl.txt
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>



#############################
##     CONSTANTS           ##
#############################

MAGICWORD="XXX"
validStatusCodes=(`echo {100..103}` \
		      `echo {200..208}` \
		      `echo {300..308}` \
		      `echo {400..451}` \
		      `echo {500..52f1}`)
VERSION="[v1.00]"

#set -e


#############################
##     BASIC FUNCTIONS     ##
#############################

banner(){
    echo '__|HM\                     __________________ _______  '
    echo '/HH\.M|           |\     /|\__   __/\__   __/(  ____ ) '
    echo 'HMHH\.|           | )   ( |   ) (      ) (   | (    )| '
    echo '\HMHH\|           | (___) |   | |      | |   | (____)| '
    echo '\\HMHH\           |  ___  |   | |      | |   |  _____) '
    echo 'HH\HMHH\          | (   ) |   | |      | |   | (       '
    echo 'HHH\HMHH\         | )   ( |   | |      | |   | )       '
    echo '    \HMHH\-HHH\   |/     \|   )_(      )_(   |/        '
    echo '     \HMHH\.HHM\            _______  _                 _______     '
    echo '      \HMHH\.HMH\          (  ____ \( (    /||\     /|(       )    '
    echo '      |\HMHH\\HMH\         | (    \/|  \  ( || )   ( || () () |    '
    echo '      |H\HHH| \HMH\        | (__    |   \ | || |   | || || || |    '
    echo '      |MH\H/   \HMH\       |  __)   | (\ \) || |   | || |(_)| |    '
    echo '      |MH\      \HMH\      | (      | | \   || |   | || |   | |    '
    echo '      \HMH\      \HMH\     | (____/\| )  \  || (___) || )   ( |    '
    echo '       \HMH\    __|HM|     (_______/|/    )_)(_______)|/     \|    '
    echo '        \HMH\  /HH\.M|          '
    echo '         \HMH\ |MHH\.|          '
    echo '          \HMH\\HMHH\|          '"VERSION: $VERSION"
    echo '           \HMH\\HMHH\          '"AUTHOR:  min2hex"
    echo '            \HMHH\HMHH\         '
    echo ""
}

help(){
    echo 'usage: ./http-enum.sh [OPTIONS] {-i}'
    echo "Required:"
    echo "     -i,--interface       : Specify interface"
    echo "     -u,--url <url>       : Specify URL. Example: http://www.abc.com/${MAGICWORD}  MAGICWORD[$MAGICWORD]"
    echo "     -w,--wordlist        : Specify wordlist "    
    echo 'Optional:'
    echo "     -t,--threads <n>     : Specify number of threads. Default: 1"
    echo "     -p,--port <n>        : Specify number of port [default: 80]"
    echo "     -m,--method <Method> : Specify method  [GET,HEAD,POST] "
    echo "     -H,--header <header> : Specify header [Default=('User-Agent=http-enum/1.0;Connection=close;Host:<host>)"
    echo "     -B,--body <body-dat> : Specify body data. POST,PUT "
    echo "     --fs <n,n,n...>      : Filter by status code  default[200,204,301,302,307,401,403]"
    echo "     --fc <n,n,n...>      : Filter by content length"
    echo "     -v,--verbose         : Be verbose "
    echo "     --usage              : Print usage message "
    echo "     -h,--help            : Print this help message "
    exit 0
}

usage(){
    clear
    banner
    echo  -e "====================================================="
    echo "[!] Basic information about this program:"
    echo "    - This program uses mostly basic programs that come "
    echo "      preinstalled in almost all linux distros.         "
    echo "      The idea behind this program is to get a easy to  "
    echo "      use http-enumeration shellscript.                 "
    echo "    - The connections to host doesn't use curl neither  "
    echo "      wget or lwp-request. It does use /dev/tcp in this "
    echo "      form:                                             "
    echo "      [1] exec [n]<>/dev/tcp/$HOST/$PORT # Connect to host"
    echo "      [2] echo -e '$httpRequest' >&[n]   # Send request "
    echo "      [3] cat <&[n]                      # Get response "
    echo "      ...                                # Response handling"
    echo "      [n] exec [n]<&-                    # Closing FD   "
    echo "[!] Usage Examples:                                     "
    echo "    - Basic directory enumeration using GET method      "
    echo " $ ./http-enum -i <interface> -w <wordlist> -u http://google.com/ZXC "
    echo "      using this command will use default status_code filter, "
    echo "      default HEADERS  and no content_length filter, but you can specify "
    echo "    - Basic directory enumeration using POST method     "
    echo " $ ./http-enum -i <interface> -w <wordlist -u http://google.com/ZXC \ "
    echo "   -m POST -B 'variable=data'                            "
    echo "      using this command will add content-length to HEADER"
    exit
}

argument_parser(){
    ## Check if there is more than one CLI argument
    test $# -eq 0 && help

    ## The next loop handle CLI arguments
    while [[ $# -gt 0 ]];do
        case $1 in
            -i|--interface) IFACE=$2 && shift && shift;;
            -t|--threads) THREAD=$2 && shift && shift;;
            -u|--url) URL=$2 && shift && shift;;
            -p|--port) PORT=$2 && shift && shift;;
            -w|--wordlist) WORDLIST=$2 && shift && shift;;
            -m|--method) METHOD=$2 && shift && shift;;
            -H|--header) HEADER=($HEADER `echo $2 | tr " " "#"`) && shift && shift;;   
            -B|--body) BODY=`echo $2 | tr " " "#"` && shift && shift;;
            --fs) FILTERSC="$2" && shift && shift;;
            --fc) FILTERCL="$2" && shift && shift;;
            -v|--verbose) VERBOSE="TRUE" && shift;;
            --usage) usage ;;
            -h|--help) help ;;
            *) help;;
        esac
    done

    ## Setting up default variables
    ${IFACE:="NONE"} &>/dev/null
    
    ${THREAD:=1} &>/dev/null
    THREAD=`echo $THREAD | grep -o -E "[0-9]{1,}" | tr -d "\n"`
    
    ${PORT:="80"} &>/dev/null
    PORT=`echo $PORT | grep -o -E "[0-9]{1,}" | tr -d "\n"`
    
    ${URL:="NONE"}   &>/dev/null
    URL=`echo $URL | tr -d " "`
    
    ${HOST:=`echo $URL | cut -d "/" -f 3`} &>/dev/null
    
    ${WORDLIST:="NONE"}  &>/dev/null
    
    ${METHOD:="HEAD"} &>/dev/null
    $(test "$METHOD" == 'GET' ) && METHOD='HEAD'
    
    if [[ -z ${HEADER[@]} ]];then
	$(test -z `echo ${HEADER[@]} | grep -o "User-Agent"` )&& HEADER=("${HEADER[@]}" "User-Agent:#http-enum/1.0")
	$(test -z `echo ${HEADER[@]} | grep -o "Connection"` )&& HEADER=("${HEADER[@]}" "Connection:#close")
	$(test -z `echo ${HEADER[@]} | grep -o "Host"` )&& HEADER=("${HEADER[@]}" "Host:#$HOST")
	$(test "$METHOD" == "POST")&& HEADER=("${HEADER[@]}" "Content-Length:#${#BODY}")
    fi
    
    ${BODY:="NONE"} &>/dev/null
    
    ${FILTERSC:="200,204,301,302,307,401,403"}  &>/dev/null
    
    ${FILTERCL:="NONE"} &>/dev/null
    
    ${VERBOSE:="FALSE"} &>/dev/null

    ## Declaring global associative array WordlistArray
    ## argument_processor_wordlist_memory_loader function use this
    declare -A WordlistArray
}   

ERROR(){
    echo -e "[X] \e[0;31mError...\e[0m"
    echo "[*] Function: $1"
    echo "[*] Reason:   $2"
    echo "[X] Returning errorcode 1"
    exit 1
}


#############################
##  INITIAL INSTRUCTIONS   ##
#############################

if [[ $(ps -ef | grep -c com.termux ) -gt 1 || $( echo "$SHELL" | grep "com.termux" ) ]];then
    echo "[X] Termux is not supported yet"
    read -p "[!] Do you want to continue? [Y/N]: " var
    if [[ $var != "Y" ]];then
	exit
    fi
fi
    
banner
argument_parser "$@"
source argument_checker.sh
source argument_processor.sh
exit 0

########
# Future implementations
# --> Proxy utility
# --> Loading bar utility
# --> Print Tries per second utility
# --> Do a HOST METHOD checking utility
# --> Fix content-length on post method, function argumentCheckerBody adds 1 more because
#     of the aspersand in argumentProcessorHttpRequest_POST
# --> Fix problem with content length, if we call --body more than once, it will fail content
#     by 1 number, Posible solution is to only allow user to introduce all data via one call.
#     Example:  Not[ --body "user=asd" --body "pass=dddd"]   Yes[ --body "user=asd&pass=ddd"]
# --> Do a wifi speed utility
# --> Do a invert filter utility 
# --> Do a extension search utility
# --> Do a finish time utility
# --> Add "don't print configuration flag"
# --> Add timeout utility
# --> Add speed conection time utility 
