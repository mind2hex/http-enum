argument_processor(){
    ## just print user configuration
    argument_processor_print_configuration "$THREAD" "$IFACE" "$WORDLIST" "$URL" "$METHOD" "$FILTERSC" "$FILTERCL"

    ## trap initialized in case the user press CTRL + C to finish
    trap " thread_killer; argument_processor_timestamp 'Finished'" EXIT

    ## load wordlist in memory
    argument_processor_wordlist_memory_loader "$WORDLIST" "$THREAD"

    ## start timestamp
    argument_processor_timestamp "Initialized"
    
    argument_processor_print_header

    
    for i in `seq $THREAD`;do
        argument_processor_HTTPRequest_${METHOD} "$i" "$HOST" "$PORT" "$URL" "$MAGICWORD" &
    done
    wait

    ## finish timestamp
    argument_processor_timestamp "Finished"
}

argument_processor_print_configuration(){
    # $1 = THREAD
    # $2 = IFACE
    # $3 = WORDLIST
    # $4 = URL
    # $5 = METHOD
    # $6 = STATUSCODE
    # $7 = CONTENTLENGTH
    ## Fix using of global variables
    ## find another way
    
    printf " PRESS CTRL + C to finish\n"
    printf "=============== \e[0;31mConfiguration\e[0m =================================\n"
    printf "[1]    Threads: %-20s \n" "$1"
    printf "[2]  Interface: %-20s \n" "$2"    
    printf "[3]   Wordlist: %-20s \n" "$3"    
    printf "[4]        Url: %-50s \n" "$4"
    printf "[5]     Method: %-20s \n" "$5"
    printf "[6]    Headers: \n"

    ## for loop to iterate HEADER array and show to user
    for i in `seq 0 $((${#HEADER[@]} - 1))`;do
        printf "         --->  %-20s\n" "`echo ${HEADER[$i]:0:60} | tr "#" " "`"
    done

    ## body is just used for POST request
    if [[ $BODY != "NONE" ]];then
        printf "[7]  Post-data: \n"

	## for loop to iterate BODY array 
        for i in `echo "${BODY}" |  tr "&" " "`;do
            printf "         --->  %-20s\n" "`echo ${i:0:60} | tr "#" " "`"
        done
    fi
    
    printf "=============== \e[0;31m Filters     \e[0m =================================\n"
    printf "[8] StatusCode: %-20s \n" "$6"
    printf "[9] ContentLen: %-20s \n" "${7/NONE/ANY}"
    printf "===============================================================\n"
    sleep 2s
}

argument_processor_wordlist_memory_loader(){
    # $1 = WORDLIST
    # $2 = THREAD
    
    # to fix:
    # Sometimes there are 2 or 3 words missing from the original wordlist
    
    ## number of lines per thread
    local numberOfLines=`expr $(wc -l < $1) / $2`

    ## counting variables
    local var_x=1
    local var_y=$numberOfLines

    ## for loop to assign to every thread a same length wordlist
    for i in `seq $2`;do
	WordlistArray[$i]=$(sed -n -e "$var_x,$var_y p" $1)
	var_x=$var_y
	var_y=$(expr $var_y + $numberOfLines)
    done
}

argument_processor_print_header(){
    printf "===============================================================\n"
    printf "\e[0;91m %-10s %-7s %-7s %-30s\e[0m\n" "SERVER" "SC" "CL" "URL"
}

argument_processor_HTTPRequest_HEAD(){
    # $1 = array index
    # $2 = HOST
    # $3 = PORT
    # $4 = URL
    # $5 = MAGICWORD
    
    ## generating Base Payload
    declare -A requestString
    for i in "${HEADER[@]}";do  ## Appending Header to the request
        requestString[HEADER]="${requestString[HEADER]}`echo $i | tr "#" " "`\r\n"
    done

    ## adding final \r\n at the end to validate the request
    requestString[HEADER]="${requestString[HEADER]}\r\n"


    for i in `echo ${WordlistArray[$1]}`;do
	## HEAD /XXX --> Here we use magic word for the replacement
        requestString[REQUEST]="HEAD /$5 HTTP/1.1\r\n"
	
        ## here whe replace magicword for the dir we are looking for
        local urlTarget=$(echo "$4" | sed "s/$5/$i/g" 2>/dev/null | tr " " "#")
        requestString[REQUEST]=$(echo ${requestString[REQUEST]} | sed "s/$5/$i/g" 2>/dev/null)

        ## sending HTTP request through netcat socket
        info=$(echo -e -n "${requestString[REQUEST]}${requestString[HEADER]}" | nc $2 $3 2>/dev/null)

        ## Parsing info
        declare -A infoArr
        infoArr[SERVER]=`echo "$info" | grep -o "^Server:.*" | grep -o " [a-zA-Z0-9]*" | grep -o "[0-9A-Za-z]*"`
        infoArr[SC]=`echo "$info" | head -n 1 | grep -o -E "[0-9]{3}"`
        infoArr[CL]=`echo "$info" | grep "Content-Length" | grep -o -E "[0-9]{1,}"`
        if [[ -n `echo $FILTERSC | grep -o "${infoArr[SC]}"` ]];then ## Checking Status Code
            if [[ $FILTERCL != "NONE" ]];then
                if [[ -n `echo $FILTERCL | grep -o "${infoArr[CL]:=0}"` ]];then
                    printf "\r %-10s %-7s %-7s %-50s\n" "${infoArr[SERVER]:=UNKOWN}" "${infoArr[SC]:=404}" "${infoArr[CL]:=0}" "$urlTarget" && continue
                fi
                printf "\r %-10s %-7s %-7s %-50s" "${infoArr[SERVER]:=UNKOWN}" "${infoArr[SC]:=404}" "${infoArr[CL]:=0}" "$urlTarget" && continue
            fi
            printf "\r %-10s %-7s %-7s %-50s\n" "${infoArr[SERVER]:=UNKOWN}" "${infoArr[SC]:=404}" "${infoArr[CL]:=0}" "$urlTarget" && continue
        fi
        printf "\r %-10s %-7s %-7s %-50s" "${infoArr[SERVER]:=UNKOWN}" "${infoArr[SC]:=404}" "${infoArr[CL]:=0}" "$urlTarget" && continue
    done    
}
argumentProcessorHttpRequest_GET(){
    # $1 = array index
    # $2 = HOST
    # $3 = PORT
    # $4 = URL
    # $5 = MAGICWORD
    for i in `echo ${WordListArray[$1]}`;do
        ## Replacing MAGICWORD with Next iteration
        local urlTarget=`echo "$4" | sed "s/$5/$i/g" 2>/dev/null | tr " " "#"`
    done
}


argument_processor_HTTP_request_POST(){
    # $1 = array index
    # $2 = HOST
    # $3 = PORT
    # $4 = URL
    # $5 = MAGICWORD
    ### Generating Base Payload
    declare -A requestString
    for i in "${HEADER[@]}";do requestString[HEADER]="${requestString[HEADER]}`echo $i | tr "#" " "`\r\n";done ## Appending HEADERS
    requestString[HEADER]="${requestString[HEADER]}\r\n"
    requestString[BODY]="${requestString[BODY]}${BODY}" # Appending Body
    for i in `echo ${WordListArray[$1]}`;do
        requestString[REQUEST]="POST /$5 HTTP/1.1\r\n"
        ### Replacing MAGICWORD with Next iteration
        local urlTarget=`echo "$4" | sed "s/$5/$i/g" 2>/dev/null | tr " " "#"`
        requestString[REQUEST]=`echo ${requestString[REQUEST]} | sed "s/$5/$i/g" 2>/dev/null `
        ### Generating File Descriptor
        local FDNumber=`shuf -i 666-777 -n 1`
        exec {FDNumber}<>"/dev/tcp/$2/$3"
        ### Sending Payload
        echo -e -n "${requestString[REQUEST]}${requestString[HEADER]}${requestString[BODY]}" >&${FDNumber}
        wait
        info=`cat <&${FDNumber}`
        wait
        exec {FDNumber}<&-
        ### Parsing info
        declare -A infoArr
        infoArr[SERVER]=`echo "$info" | grep -o "^Server:.*" | grep -o " [a-zA-Z0-9]*" | grep -o "[0-9A-Za-z]*"`
        infoArr[SC]=`echo "$info" | head -n 1 | grep -o -E "[0-9]{3}"`
        infoArr[CL]=`echo "$info" | grep "Content-Length" | grep -o -E "[0-9]{1,}"`
        if [[ -n `echo $FILTERSC | grep -o "${infoArr[SC]}"` ]];then ## Checking Status Code
            if [[ $FILTERCL != "NONE" ]];then
                if [[ -n `echo $FILTERCL | grep -o "${infoArr[CL]}"` ]];then
                    printf "\r %-10s %-7s %-7s %-50s\n" "${infoArr[SERVER]:=UNKOWN}" "${infoArr[SC]:=404}" "${infoArr[CL]:=0}" "$urlTarget" && continue
                fi
                printf "\r %-10s %-7s %-7s %-50s" "${infoArr[SERVER]:=UNKOWN}" "${infoArr[SC]:=404}" "${infoArr[CL]:=0}" "$urlTarget" && continue
            fi
            printf "\r %-10s %-7s %-7s %-50s\n" "${infoArr[SERVER]:=UNKOWN}" "${infoArr[SC]:=404}" "${infoArr[CL]:=0}" "$urlTarget" && continue
        fi
        printf "\r %-10s %-7s %-7s %-50s" "${infoArr[SERVER]:=UNKOWN}" "${infoArr[SC]:=404}" "${infoArr[CL]:=0}" "$urlTarget" && continue

    done
}

thread_killer(){
    local pidList=`jobs -p | tr "\n" " "`
    kill -9 $pidList 2>/dev/null
}

argument_processor_timestamp(){
    echo -e "\n==============================================================="
    echo "`date "+%d/%m/%Y %T"` $1"
    echo "==============================================================="
}

print_finish(){
    echo  -e "\n\r====================================================="
    echo  -e "[X] Process Finished "
    echo  -e "====================================================="
}


#############################
##  MAIN FUNCTION CALL     ##
#############################

argument_processor 
