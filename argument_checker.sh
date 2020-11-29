argumentChecker(){
    local urlValidChar="A-Za-z0-9\-\.\_\~\:\/\?\#\[\]\@\!\$\&\'\(\)\*\+\,\;\%\="
    
    ## Interface checks
    argument_checker_interface "$IFACE"
    
    ## Thread checks
    argument_checker_threads "$THREAD"
    
    ## PortNumber checks
    argument_checker_port_number "$PORT"
    
    ## URL checks
    argument_checker_url "$URL" "$MAGICWORD" "$urlValidChar"
    
    ## HostAlive checks
    argument_checker_host_alive "$HOST" "$PORT"
    
    ## Wordlist checks
    argument_checker_wordlist "$WORDLIST"
    
    ## Method checks
    argument_checker_method "$METHOD"
    
    ## Header checks
    argument_checker_header "${HEADER[@]}"
    
    ## Checking Body
    argument_checker_body "${BODY}" "$urlValidChar" "$METHOD"  # Uses variable ${BODY}
    
    ## Checking Status Code
    argument_checker_filter "$FILTERSC" "$FILTERCL"
}

argument_checker_interface(){
    ## Interface name check
    $(test $1 == "NONE")&& ERROR "argument_checker_interface" "No interface provided"
    
    ## Interface existence check using /sys/class/net/<interface-name>
    $(test -e "/sys/class/net/$1")|| ERROR "argument_checker_interface" "There is no $1 interface in /sys/class/net/##"


    ## Interface /sys/class/net/$1/carrier file existence check
    $(test -e "/sys/class/net/$1/carrier")|| ERROR "argument_checkr_interface" "There is no carrier file in /sys/class/net/$1/##"

    ## Interface network connection check using /sys/class/net/<interface-name>/carrier
    ## carrier = 1 --> Link is up
    ## carrier = 0 --> link is down
    $(test `cat /sys/class/net/$1/carrier` -eq 1)|| ERROR "argument_checker_interface" "Interface $1 it's not connected to a network"
}

argument_checker_threads(){
    local MIN_THREADS=1    ## Minimum allowed threads, this is by default 1
    local MAX_THREADS=50   ## Maximum allowed threads

    ## Thread number validation
    $(test $1 -lt $MIN_THREADS)&& ERROR "argument_checker_threads" "there are fewer threads than allowed: [$MIN_THREADS]"
    $(test $1 -gt $MAX_THREADS)&& ERROR "argument_checker_threads" "there are more threads than allowed: [$MAX_THREADS]"
}

argument_checker_port_number(){
    ## Port number validation
    $(test $1 -gt 65536)&& ERROR "argument_checker_port_number" "Port $1 is out of range"
}

argument_checker_url(){
    local urlRegEx='(http|https)://.+/' # basic url regular expression
    local baseURL=`echo "$1" | grep -o -E "$urlRegEx"`
    local result=0    
    
    ## Url basic check
    $(test $1 == "NONE" )&& ERROR "argument_checker_url" "No url provided"

    ## Url validation
    if [[ -n `which curl` ]];then       ## using curl to check url if it does exist
	curl --connect-timeout 1 $baseURL &>/dev/null
	result=$?
	if [[ $result -ne 0 ]];then
	    ERROR "argument_checker_url" "Invalid url: $1"
	fi
    else
	## Basic url validation
	$(test -z `echo "$baseURL"` )&& ERROR "argument_checker_url" "Invalid url: $1"	
    fi

    ## MagicWord check
    $(test `echo "$1" | grep -o "$2" | wc -l` -eq 0)&& ERROR "argument_checker_url" "No MAGICWORD:[$2] in URL:[$1]"
    $(test `echo "$1" | grep -o "$2" | wc -l` -gt 1)&& ERROR "argument_checker_url" "MAGICWORD repeated more than once: $1"
    if [[ -n `echo "$1" | cut -d "/" -f3 | grep $2` ]];then
	ERROR "argument_checker_url" "MAGICWORD should not be in the domain"
    fi
    
    ## URL invalid characters check
    $(test -z `echo "$1" | grep --invert-match -o "[$3]"`)|| ERROR "argument_checker_url" "Invalid Chars in url: $1"
}

argument_checker_host_alive(){
    ## ping to host 
    $(test `ping -c 1 $1 &>/dev/null ; echo $?` -ne 0)&& ERROR "argument_checker_host_alive" "Host $1 seems down"
    
    ## target port connection check
    echo "testing" > /dev/tcp/$1/$2  ## Establishing a tcp connection to host:$1 on port:$2 using /dev/tcp
    $(test $? -ne 0)&& ERROR "argument_checker_host_alive" "Host is not accepting connections on port $2"
}

argument_checker_wordlist(){
    ## Wordlist check
    $(test $1 == "NONE")&& ERROR "argument_checker_wordlist" "No wordlist provided"

    ## Wordlist existence check
    $(test -e "$1" )|| ERROR "argument_checker_wordlist" "Wordlist $1 doesn't exist"

    ## Wordlist empty check
    $(test `head -n 1 $1 | wc -l` -eq 0)&& ERROR "argument_checker_wordlist" "Wordlist $1 is empty"
}

argument_checker_method(){
    ## Method validation
    $(test -z `echo $1 | grep -E -o "(GET|HEAD|POST)"`)&& ERROR "argument_checker_method" "Invalid method: $1"
}

argument_checker_header(){
    local validHeaders=('Accept' 'Accept-Charset' 'Accept-Encoding' 'Accept-Language'\
				 'Cache-Control' 'Connection' 'Content-Type'\
				 'Cookie' 'From' 'Host' 'Origin' 'Referer' 'DNT' 'User-Agent')

    ## Checking for invalid headers
    local aux=""
    for i in `echo $@`;do
	aux=`echo $i | cut -d ":" -f 1`
        $(test -z `echo ${validHeaders[@]} | grep -o $aux`)&& ERROR "argument_checker_header" "Header [$aux] is invalid or is not supported by this program yet"
    done

}

argument_checker_body(){
    ## BodyData and Post check
    if [[ $3 != "POST" && $1 != "NONE" ]];then
        ERROR "argument_checker_body" "Method: $3 doesn't allow data via body"
	
    elif [[ $3 != "POST" ]];then
	return 0 
    fi
    
    ## Body length check
    $(test $1 == "NONE")&& ERROR "argument_checker_body" "POST method need Body data"
    
    ## Body invalid characters check
    $(test -z `echo $1 | grep --invert-match -o "[$2]"`)|| ERROR "argumentCheckerBody" "Invalid character in $i"    
}

argument_checker_filter(){
    ## Status Code check
    for i in `echo $1 | tr "," " "`;do
        $(test -z `echo ${validStatusCodes[@]} | grep -o "$i"`)&& ERROR "argument_checker_filter" "Invalid Status Code [$i]"
    done
    
    $(test $2 == "NONE")&& return 0
    
    ## Content Length valid char check
    if [[ -n `echo "$2" | gre[ "[a-z\ ]"` ]];then
	ERROR "argument_checker_filter" "Invalid character ' ' in --fc filter"
    fi
    ## Content Length
    for i in `echo $2 | tr "," " "`;do
        $(test -z `echo "$i" | grep -o -E "[0-9]{1,}"`)&& ERROR "argument_checker_filter" "Invalid Character $i in --fc filter"
    done
}


#############################
##  MAIN FUNCTION CALL     ##
#############################

argumentChecker "$@"
