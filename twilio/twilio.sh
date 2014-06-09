#!/bin/bash

###	twilio script .
###	written by Ofir Elhayani
###	20-4-2014, finished with all fixes at 27-4-2014
###	purpose: issuing a test (ping or wget) to ip's entered, and then 
###	generating sms messages upon the twilio API. also, has a char cap, which when the message is longer than that
###	it splits it to more messages.
###	all rights reserved, but feel free to learn from it.
###	HAVE FUN



	function usage()	# generates the usage of the script
{
	if [ -n "$1" ]; then echo $1; fi
	echo 'Usage: twilio.sh <command> <"ip address1,ip address2,..."> group_name'
	echo 'where command is ping or wget'	
	exit 1
}

	function ping_check()  	# function to perform ping check and compile 
							# the ping message
{
	ip_count=${#ip_addresses[@]}	# sets the ip's in an array for checking
	ping_err=0		#ping error counter
	ping_ok=0		#ok pings counter
	
			for (( i=0; i < ${ip_count}; i++ ))		# the checking loop
													# during the loop the results will be
													# "thrown" into 2 arrays the pingerr 
													# for errors and the pingok for ok pings
			do
			ping -c1 ${ip_addresses[i]} 1>/dev/null 2>&1		#performing silent ping
																# of course duration can be changed
			ret=$?
				if [[ $ret -ne 0 ]]		# if returns error code - assigned to pingerr
				then 
				pingerr[ping_err]=${ip_addresses[i]}
				else
				pingok[ping_ok]=${ip_addresses[i]}
				fi
			ping_err=$((ping_err+1))
			ping_ok=$((ping_ok+1))
			done
		log_succeed=`echo -e "pings succeeded:"; echo ${pingok[@]} | xargs printf -- '%s\n' `	# creates the log for successed pings

		log_failed=`echo -e "pings failed:"; echo ${pingerr[@]} | xargs printf -- '%s\n'`	# creates the log for failed pings

	if [[ "${#pingerr[@]}" -eq 0 ]] 			# if there are not successed pings 
	then							# issues only the failed pings log
	log=`echo $log_succeed`				# & message, and vice versa.
	elif [[ "${#pingok[@]}" -eq 0 ]]			# otherwise issues a full message (failes+succeed)
	then							# 
	log=`echo $log_failed`
	else
	log=`echo -e "$log_succeed\n$log_failed"`
	fi 
	# creating log file for the operation, including date etc..
	echo -e "\n\nping log made at `date +%H:%M` on `date +%a,%d-%m-%y`:\n$log" >> logfile 	

					# compiling the message to be sent
	message=$( echo -e "\n$log" )

	}




	function wget_check()	# function to perform check and compile the
							# wget message.
{
	
	ip_count=${#ip_addresses[@]}	# sets the ip's in an array for checking
	wget_ok=0
	wget_err=0			
			for (( f=0; f < ${ip_count[@]}; f++ ))						# performing silent wget to the addresses issuing the output to 2 arrays
													# an error and an ok arrays.
			do
			wget -nv --tries=1 ${ip_addresses[f]} 1>/dev/null 2>&1	
		                stat=$?
				if [[ $stat -ne 0 ]]
				then		# error log - anything that does not return 0
				wgeterr[wget_err]=${ip_addresses[f]}
				else
				wgetok[wget_ok]=${ip_addresses[f]}
				fi		
			wget_ok=$((wget_ok+1))
			wget_err=$((wget_err+1))
			done
		log_succeed=`echo -e "wgets succeeded:"; echo ${wgetok[@]} | xargs printf -- '%s\n'`	#like in the pingcheck function - issuing the right log & message

		log_failed=`echo -e "wgets failed:"; echo ${wgeterr[@]} | xargs printf -- '%s\n'`

	if [[ "${#wgeterr[@]}" -eq 0 ]] 
	then
	log=`echo $log_succeed`
	elif [[ "${#wgetok[@]}" -eq 0 ]]
	then
	log=`echo $log_failed`
	else
	log=`echo -e "$log_succeed\n$log_failed"`
	fi 
	# creating log file for the operation, including date etc..
	echo -e "\n\nwget log made at `date +%H:%M` on `date +%a,%d-%m-%y`:\n$log" >> logfile 	

					# compiling the message to be sent
	message=$( echo -e "\n$log" )
	
		
}	                
		function send_msg()	## function to compile the final message to be sent
{
		num=1		# final_message index counter
		start=0		# message start point and stop point (below)
		stop=145		
		final_message[0]=`echo -e "${message:0:145}"`	# the first message - if exceed 145 chars then the loop goes in action and generates sms for the rest of the message
		name_count=0
		phone_count=${#phones[@]} # drops the number of phones in the phone list into array
		if [ $( echo $message | wc -m ) -gt 145 ]			# if the message exceeds 145 chars then generates more messages as required
			then
			start=$((stop))
			stop=$((start+140))			
			final_message[num]=${message:start:stop}
			num=$((num+1))
			fi		
		for (( call=0 ; call < "${phone_count}" ; call++ ))   		# the loop exists until the last phone in the list (the phone_count variable)
		do
	
			# informs each time to whom the sms is about to be sent
               		
               		echo -e "\nsending $command_parameter msg to ${names[name_count]} in ${phones[$call]} from me\n"			
			
			for (( i=0; i < ${#final_message[@]}; i++ ))									# posts the sms 
			do
	curl -X POST https://api.twilio.com/2010-04-01/Accounts/AC2f8a82db075ce9ba17a3e814dc2a427c/SMS/Messages\	
 	-d "From=%2b15005550006"\
 	-d "Body=`echo -e "HELLO ${names[name_count]}\n ${final_message[i]}"`"\
 	-u 'AC2f8a82db075ce9ba17a3e814dc2a427c:6d96e790a558c55be644235621d82c53' 2>&1
 	sleep 2		 # delay interval just to be able to track on screen, can be commented
			done
		name_count=$((name_count+1))
		done
		echo -e "\nsending $command_parameter msg to $group_name done"
		echo -e "$command_parameter check has been completed and sent to $group_name" | mail -s "$command_parameter check report" $USER

exit 1		
  }

	
# assigning stdin to variables.

ip_addresses=($( echo "$2" | tr "," " " | xargs printf -- '%s\n'))	# ip_addresses = ip addresses
command_parameter="$1"	# command_parameter = command
group_name="$3"	# group_name = group name


# issuing error messages if a parameters are missing

	if [ "$command_parameter" != "ping" -a "$command_parameter" != "wget" ] || [ -z "$command_parameter" ]; then usage "no command issued or invalid command"; else	#test valid command 
																							#input
		if [ -z "$ip_addresses" ]; then usage "no destination ip entered"; else	# test an input of an ip address\es
			if [ -z "$group_name" ]; then usage "no group name entered"; else	# test an input of a group file
				if [ ! -e "$group_name" ]; then usage "no group file by this name";	# test if the group's text file exists'
			fi
		fi
	fi
fi
phones=($( sed -n '1,$p' $group_name | cut -d " " -f 2 ))	# phones = phone numbers to send to

names=($( sed -n '1,$p' $group_name | cut -d " " -f 1 ))  # names = names of the group members.
	
	# retreiving the command and performing ping or wget
		case "$command_parameter" in
		"ping") ping_check;
				send_msg;;
	
		"wget") wget_check;
				send_msg;;
		esac

