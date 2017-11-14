#!/bin/bash
#TODO skipp tcpdump, select interface, select 

#First agument should be the interface to start the monitor on, by default wlp2s0 (deal with it)
iface=${1:-"wlp2s0"}
#Accept a req file with existing packet capture as an argument, TODO to skip tcpdump and go straight to processing 
reqset=${2:-""}
#Store temporary files in /tmp/ directory, output goes into output-uuid
tmpdir="/tmp/"
uuid=`uuidgen | cut -d "-" -f 3`
reqs="$tmpdir"reqs-"$uuid"
macs="$tmpdir"macs-"$uuid"
output=output-"$uuid"

#Remove old temp files
rm "$tmpdir"*reqs*  "$tmpdir"*macs*


echo "Files in $tmpdir*$uuid"

#echo "${iface}mon0"

#Use airmon to start wlp2s0 (this will depend on interface, should be a variable)
sudo airmon-ng start $iface &> /dev/null

# Obtain name of the monitoring interface (on Arch Linux)
moniface=`ip addr show | grep mon | cut -d: -f2 | cut -d' ' -f2`

#If a packet file was provided, we just set reqs equal to that.
if [ ! -z $reqset ]  
then
    reqs=$reqset
else
    #Run tcpdump using monitor 0, verbose mode, printing link layer(to get mac address), limit size to 256, capture packets of type management and subtype probe request, pipe to tee to save to file and also print to stdout
    # Note: ${iface} will return the contents of the $iface variable and allow for appending 'mon0' | Arch does not add the 0 to mon0
    #sudo tcpdump -i ${iface}mon -vv -e -s 256 type mgt subtype probe-req | tee "$reqs" &
    sudo tcpdump -i $moniface -vv -e -s 256 type mgt subtype probe-req | tee "$reqs" &

    #capture all the running jobs and store their pids in an array (This needs to be tested to see how it works with other running jobs)
    pids=(`jobs -l % | sed 's/^[^ ]* \+//' | cut -d\  -f1`)
    echo pid of tcpdump: ${pids[0]}
    echo pid of tee: ${pids[1]}

    #Run tcpdump until user inputs q
    read -p "press q to stop tcpdump:" -n1 input;
    while :; do
        if [ $input="q" ];
        then
            sudo kill ${pids[0]} ${pids[1]}
            break
        fi
        read -p "press q to stop tcpdump: " -n1 input;
    
    done;
fi


#Process mac adresses from reqs into macs file
cat "$reqs" | cut -d ":" -f 6-11 | cut -d " " -f 1 | sort | uniq | tail -n +2 > "$macs"

#Loop over each mac address, grep reqs for lines containing it, get a list of unique ips. Look for a vendor assosiated with first part of mac adress in /var/lib/iee-data/oui.txt
while read line; do
    net=$(grep "$line" "$reqs" | cut -d "(" -f 3 | cut -d ")" -f 1 | sort | uniq)
    [ -z "$net" ] && continue;
    oui=$(grep -i `echo "$line" | cut -d ":" -f 1-3 | tr : - ` /var/lib/ieee-data/oui.txt | cut -f 2,3)
    [ -z "$oui" ] && oui="Unknown";
    echo "[*] $line: $oui"
    echo "$net" | sed '/^$/d' |  sed 's/^/   [+] /' 
    echo " "
done <  "$macs" | tee "$output"
echo "Stopping monitoring mode..."
sudo airmon-ng stop $moniface &> /dev/null
echo "Stopped the monitoring interface: $moniface"

echo "Output is in $output"
exit
