#!/bin/sh

get_ip_addresses()
{
    ext_ip=`external-ip`
    int_ip=`hostname -I | sed 's/ //g'`
}

get_port_mappings()
{
    IFS=$'\n'
    port_mappings=($(upnpc -l | grep -e "->"))
    unset IFS
}

success_alert()
{
   `sendAlert.sh 2050 $ext_ip $portA`
}

failure_alert()
{
   `sendAlert.sh 2051`
}

port_name_to_number()
{
    if   [[ $2 == ssh  ]]; then eval $1=22;
    elif [[ $2 == http ]]; then eval $1=80;
    elif [[ $2 == ssl  ]]; then eval $1=443;
    fi
}

list_port_mappings()
{
    get_port_mappings

    mappings=${#port_mappings[@]}
    matches=0
    local entries=0

    echo
    echo "Listing Router Port Mappings:"
    echo "============================="
    if [[ $filter_type ]];     then echo " Filtering by type:            " $filter_type; fi
    if [[ $filter_ip ]];       then echo " Filtering by IP:              " $filter_ip; fi
    if [[ $filter_src_port ]]; then echo " Filtering by Source Port:     " $filter_src_port; fi
    if [[ $filter_dst_port ]]; then echo " Filtering by Destination Port:" $filter_dst_port; fi
    if [[ $filter_name ]];     then echo " Filtering by Name:            " $filter_name; fi 
    echo "------------------------------------------------------"

    port_name_to_number filter_src_port $filter_src_port
    port_name_to_number filter_dst_port $filter_dst_port

    for (( i=0; i<${mappings}; i++));
    do
        ((entries++))
        mapping=${port_mappings[$i]}
        local mapping_re="([0-9.]+) +([UDTCP.]+) +([0-9.]+)->([0-9.\.]+):([0-9.]+) +'(.+)?' '(.*)'"
        if [[ $mapping =~ $mapping_re ]]; then
            local show=true
            id=${BASH_REMATCH[1]}
            type=${BASH_REMATCH[2]}
            portA=${BASH_REMATCH[3]}
            ip=${BASH_REMATCH[4]}
            portB=${BASH_REMATCH[5]}
            name=${BASH_REMATCH[6]}

            if [[ $filter_type && $filter_type != $type ]]; then unset show; fi
            if [[ $filter_ip && $filter_ip != $ip ]]; then unset show; fi
            if [[ $filter_src_port && $portA != $filter_src_port ]]; then unset show; fi
            if [[ $filter_dst_port && $portB != $filter_dst_port ]]; then unset show; fi
            if [[ $filter_name && ! `echo $name | grep $filter_name` ]]; then unset show; fi

            if [[ $show ]]; then
                printf "%2d %s %5d %15s %5d %s\n" "$id" "$type" "$portA" "$ip" "$portB" "$name"
                ((matches++))
            fi
        fi
    done
    echo "------------------------------------------------------"
    echo Found $matches/$entries matching entries
    echo

    unset filter_type
    unset filter_ip
    unset filter_src_port
    unset filter_dst_port
    unset filter_name
}

generate_random_port_number()
{
    random_port_num=$((RANDOM%10000+50000))
}

filter_ssh_mappings()
{
   filter_type=TCP
   filter_ip=$int_ip
   filter_dst_port=ssh
   #filter_name=libminiupnpc
   list_port_mappings
}

save_alert_new_mapping()
{
    echo "New mapping"
    echo $mapping > /var/local/nas/ssh_forward
    success_alert
}

add_ssh_route()
{
   for i in `seq 1 10`;
   do
       generate_random_port_number

       echo "Checking for mapping against random port number:" $random_port_num
       filter_type=TCP
       filter_src_port=$random_port_num
       list_port_mappings
       if [[ $matches -eq 0 ]]; then
           res=`upnpc -a $int_ip 22 $random_port_num TCP`

           echo "Confirming mapping:"
           filter_type=TCP
           filter_src_port=$random_port_num
           filter_ip=$int_ip
           filter_dst_port=ssh
           list_port_mappings
           if [[ $matches -eq 1 ]]; then
               mapping=`echo $ext_ip":"$portA"->"$int_ip":"$portB`
               if [ -e /var/local/nas/ssh_forward ]; then
                   last_mapping=`cat /var/local/nas/ssh_forward`
                   if [[ $mapping == $last_mapping ]]; then
                       echo "Matches previous mapping"
                   else
                       save_alert_new_mapping
                       try_del_last_mapping
                   fi
               else
                   save_alert_new_mapping
               fi
               break
           fi
       fi
   done
}

del_ssh_route()
{
   get_ip_addresses

   echo "External IP address:" $ext_ip
   echo "Local IP address:   " $int_ip

   echo "Looking for existing mapping..."
   filter_ssh_mappings

   counter=0
   while [[ $matches -ne 0 && $counter -lt 10 ]]; do
       ((counter++))

       echo "Deleting" $portA"->"$ip":"$portB "mapping..."
       res=`upnpc -d $portA TCP`

       echo "Confiming Deletion"
       filter_ssh_mappings
   done
}

try_del_last_mapping()
{
   echo "Trying to remove mapping:" $last_mapping
}

check_add_ssh_route()
{
   get_ip_addresses

   echo "External IP address:" $ext_ip
   echo "Local IP address:   " $int_ip

   echo "Looking for existing mapping..."
   filter_ssh_mappings

   if [[ $matches -eq 0 ]]; then
      add_ssh_route
   else
      printf "Found prexisting mapping %d->%s:%d\n" "$portA" "$ip" "$portB"
      mapping=`echo $ext_ip":"$portA"->"$int_ip":"$portB`
      if [ -e /var/local/nas/ssh_forward ]; then
          last_mapping=`cat /var/local/nas/ssh_forward`
          if [[ $mapping == $last_mapping ]]; then
             echo "Matches previous mapping"
          else
             save_alert_new_mapping
             try_del_last_mapping
          fi
      else
          save_alert_new_mapping
      fi
   fi
}

if [[ $1 == remove ]]; then
    del_ssh_route
else
    check_add_ssh_route
fi

list_port_mappings
