#!/bin/bash

################################################################################
# TODO: Add description here!                                                  #
################################################################################

declare -rx SCRIPT=${0##*/}
SCRIPT_PATH="$PWD"


# Global variables
exit_msg=""
err_msg=""
error=0
configs=""
active="zero"

patches_slink="/etc/patches"
configs_dir="/etc/configs"

# Completion flag, is set by initial_update_handler and checked 
# by after_reboot_handler. If the flag is not set then the initial update has
# failed and the problem must be reported back
# Values:
#    0              Successful update
#    non-zero        Fail exit causes 
result_flag=0

#EXITs
EXIT_SUCCESS=0
EXIT_FAIL_INVALID_PARAMETERS=192 
EXIT_FAIL_INVALID_OPTIONS=193
EXIT_FAIL_NO_DESCRIPTION=194

# Command options array
#declare -a options=""

#  Command parameters array
#declare -a params=""

# This function takes one parameter - command to execute
# Run it with disabled output and return the result. 
#  
function execute ()
{
    #Execute the command
    $*  &> /dev/null 
    
    return $?
}
export -f execute

# This function takes one parameter - command to execute
# Run it with disabled output and check the result. In case of fault it will
# leave that is denoted by capital L.
function executeL ()
{
	#Store command
	local cmd=$*
	
	#Execute the command
    err_msg=`$* 2>&1`
    
    #Store exit code 
	error=$?
	
    #Check the return result, if it fails exit
    if [ ${error} -ne 0 ]; then
        exit_msg="Executing \"${cmd}\" has failed returning ${error} and error message:"
        exit $EXIT_FAIL_EXECUTEL
    fi
    
    return ${error}
}
export -f executeL

# This function takes two parameters:
# 1: number of attempts to execute
# 2: command to execute
# The command is ran with disabled output. The number attempts defined by first  
# parameter will be performed. It does not exit and just return the error code. 
function executeR ()
{
	_max=$1
	_cmd=$2
	_r=0
	
	#Redirect standard error stream to standard output
	2>&1

	for (( a=0; a<${_max} ; a++ )) ; do  	
    	${_cmd} > /dev/null
    	_r=$?
    	if [ ${_r} -eq "0" ] ; then
    		break;
    	fi
	done
	
   	return ${_r}
}
export -f executeR


# cleanup_handler() gets called either from exit_handler() indicating that the 
# further execution is not possible due to the error or it's completed. It also
# can be called from the signal handler.
# This handler is responsible for deallocating all resources and removing 
# temporary files.
function cleanup_handler ()
{
 	printf "%s\n" "Cleaning up ..."	
}
export -f cleanup_handler


# signal_handler() gets called when SIGINT  
function signal_handler ()
{
	local signal=$1
	printf "%s\n" "Script has interrupted by $signal!"
	
	cleanup_handler	
}
export -f signal_handler



# The exit_handler() gets called every time when exit is invoked, it can either
# be error situation or successful complete.
# 
# No input parameters
# return: 
#      0		- Success
# non-zero		- Indicating an error
function exit_handler ()
{
	if [ ${error} -ne 0 ] ; then
		printf "%s\n"   "$exit_msg"	
		printf "\t%s\n" "$err_msg"	
	fi
	
  	return ${EXIT_SUCCESS}   	
}
export -f exit_handler



# get_configs() returns list of configuration in configs variable 
# 
# No input parameters
# return: 
#      0		- Success
# non-zero		- Indicating an error
function get_configs ()
{
	configs=$( (ls -1 ${configs_dir}) )
	return ${EXIT_SUCCESS}
}


# get_active() saves active configuration name in the global variable "active" 
# 
# No input parameters
# return: 
#      0		- Success
# non-zero		- Indicating an error
function get_active ()
{
	if [ -L ${patches_slink} ] ; then
		active=`readlink ${patches_slink}`
		active=${active#"configs/"}
	else
		active="zero"	
	fi
	
	return ${EXIT_SUCCESS}
}

# init() initialises global variables 
# 
# No input parameters
# return: 
#      0		- Success
# non-zero		- Indicating an error
function init ()
{
	get_configs
	get_active
}




# The list_handler() lists all available configurations and marks the active
# configuration by putting '*' at the beginning of the line
# 
# No input parameters
# return: 
#      0		- Success
# non-zero		- Indicating an error
function list_handler ()
{
	local config
	local description
	local offset
	
	printf "\n%s\n" "Here are the available configurations:"	
	if [ "$active" = "zero" ] ; then
		(( offset=16 ))
		printf "%s" "(*) "; printf "%s" "zero"; eval printf %.0s.  '{1..'"${offset}"\}; printf "%s\n" "Zero, package-default configuration"  
	else
		(( offset=16 ))
		printf "%.0s " {1..4}; printf "%s" "zero"; eval printf %.0s.  '{1..'"${offset}"\}; printf "%s\n" "Zero, package-default configuration"  
	fi

	for config in ${configs[*]} 
	do
		description=$( (head -n 1 ${configs_dir}/${config}/description.txt) )
		if [ "$active" = "$config" ] ; then
			(( offset=20 - ${#config} ))
			printf "%s" "(*) "; printf "%s" "${config}"; eval printf %.0s.  '{1..'"${offset}"\}; printf "%s\n" "${description[*]}"  
		else
			(( offset=20 - ${#config} ))
			printf "%.0s " {1..4}; printf "%s" "${config}"; eval printf %.0s.  '{1..'"${offset}"\}; printf "%s\n" "${description[*]}"  
		fi
	done	
	
	printf "%s\n"	
	
  	return ${EXIT_SUCCESS}   	
}


# The reset_handler(), resets the configuration to the zero, package-deault state
#
# No input parameters
# return: 
#      0		- Success
# non-zero		- Indicating an error
function reset_handler () 
{

	# Remove all the patches	
	execute quilt pop -a

	if [ -L  ${patches_slink} ] ; then	
		# Remove /etc/patches symlink, to indicate this is reset to zero, 
    	# package-default state
		execute rm ${patches_slink} 
	fi

		
	active="zero"
	
  	return ${EXIT_SUCCESS}   	
}


# The infor_handler() expects a single parameter - configuration name. It prints
# the full description of this configuration
# 
# param1	config      - Requested configuration name
# return: 
#      0		- Success
# non-zero		- Indicating an error
function info_handler () 
{
	local config=$1
	
	if [ "$config" = "zero" ] ; then
		printf "%s\n" "Zero, package default configuration"		
		printf "%s\n"	
		printf "%s\n" "All configuration files are package default,"		
		printf "%s\n" "no any product modification have applied."		
		
		return ${EXIT_SUCCESS}
	fi
	
  	
  	for cfg in ${configs[*]}
  	do
  		if [ "$cfg" = "$config" ] ; then
  			
  			if [ -f ${configs_dir}/${config}/description.txt ] ; then
  			
  				cat ${configs_dir}/${config}/description.txt
  				return ${EXIT_SUCCESS}
  			fi
  		fi
  		
	done
	
	printf "%s\n" "No configuration \"${config}\" is found"
  	
	return ${EXIT_FAIL_NO_DESCRIPTION};
}


# The help_handler() prints out help information 
#
# No input parameters
# return: 
#      0		- Success
# non-zero		- Indicating an error
function help_handler () 
{
	printf "%s\n"             
    printf "%s\n" "Managing Linux system configurations."
	printf "%s\n"
	printf "%s\n" "Usage: $SCRIPT [options] configuration"
	printf "%s\n"
	printf "%s\n" "Options:"
	printf "%s\n"
	printf "%s\t%s\n" "-l, --list"        "List available configurations. The active configuration will be marked by '*'" 
	printf "%s\n"
	printf "%s\t%s\n" "-i, --info"        "Print full information about selected configuration" 
	printf "%s\n"
	printf "%s\t%s\n" "-h, --help"        "This help"
	printf "%s\n"
	printf "%s\n" "Examples:"
	printf "%s\n" "To list all available configurations " 
	printf "\t%s\n" "$SCRIPT -l"
	printf "%s\n"
	printf "%s\n" "To get full configuration description " 
	printf "\t%s\n" "$SCRIPT -i dhcp.router"
	printf "%s\n"
	printf "%s\n" "To switch to another configuration "
	printf "\t%s\n" "$SCRIPT dhcp.router "
	printf "%s\n"
	
	return ${EXIT_SUCCESS}
}

# The switch_config() expects a single parameter - configuration name. It  
# the full description of this configuration
# 
# param1	config      - Requested configuration name
# return: 
#      0		- Success
# non-zero		- Indicating an error
function switch_config () 
{
	local config=$1
	
	
	if [ $config = "zero" ] ; then
		printf "%s\n" "Reseting to Zero, package-default configuration"
		reset_handler
		active="zero"
		printf "%s\n" "All done!" 
		return ${EXIT_SUCCESS}
	fi
  	
  	for cfg in ${configs[*]}
  	do
  		if [ "$cfg" = "$config" ] ; then
  			
  			if [ -d ${configs_dir}/${config} ] ; then
  				
				#Reseting configuration to Zero state"		
  				reset_handler	
  				
  				#Set symlink to the requested configuration
				execute ln -sf "configs/${config}" patches	
				
				# Now let's aplly all the patches
				execute quilt push -a 		
				
				# Set active configuration
				active="$config"
				
				printf "%s\n" "The configuration is set to \"$config\""
				
				return ${EXIT_SUCCESS}	
  			fi
  		fi
	done
	
	printf "%s\n" "No configuration ${config} is found"
  	
	return ${EXIT_FAIL_NO_DESCRIPTION};
}


################################################################################
#                        THE SCRIPT ENTRY POINT                                #
################################################################################

# Declare exit handler
trap exit_handler EXIT

# Declare signal handler
trap signal_handler SIGINT SIGTERM

while [ $# -gt 0 ]; do
  case $1 in
    --help | -h) shift;
    	options+=("help")
    	continue
    ;;
    
    --list| -l)  shift;
    	options+=("list")
    	continue
     ;;
    
    --info| -i)  shift;
    	options+=("info")
    	continue
    ;;
   
	-*)  exit_msg="Switch not supported" 
		printf "%s\n" $exit_msg >&2 
		exit $EXIT_FAIL_INVALID_PARAMETERS 
		;;
	
	*)  params+=("$*")
		break		
		;;  
 esac
done


# Start initialisation
init

if [ ${#options[*]} -gt 1 ] ; then
	exit_msg="ERROR: Invalid sequence of options, only one option is accepted!"
	exit $EXIT_FAIL_INVALID_OPTIONS
fi


if [ ${#params[*]} -gt 1 ] ; then
	exit_msg="ERROR: More than single configuration was given!"
	exit $EXIT_FAIL_INVALID_PARAMETERS
fi

result=0
case ${options[0]} in
	
	"help")
		help_handler	
		result=$? 	
		;;
		
	"list")
		list_handler
		result=$?		
		;;
		
	"reset")
		printf "\n%s\n" "Reseting to Zero, package-default configuration"		
		reset_handler	
		result=$?	
		printf "%s\n" "All done!"
		;;	
		
	"info")
		info_handler ${params[0]}	
		result=$?	
		;;
		
		*)
		if [ ${#options[*]} -gt 0 ] ; then
			exit_msg="ERROR: No any options are acceptable for switching command!"
			exit $EXIT_FAIL_INVALID_OPTIONS
		fi
		
		switch_config ${params[0]}
		result=$?
		;;		
esac	


exit $result