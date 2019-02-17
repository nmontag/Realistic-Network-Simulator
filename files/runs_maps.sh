#!/bin/bash
HOME=$(readlink -f ~)
export LD_LIBRARY_PATH="${HOME}/ns-allinone-3.24.1/ns-3.24.1/build/"

bm_run_location=$1
B=$2
map_files_location=$3
pbf_file_name=$4
ns_location=$5
ns_code_name=$6
N=0
ATTACKLOC=0 # Attacker location, 1 - Map based. 2 - Start next to target. 3 - Radius at angle from target. 4 - Between receiver and sender
ATTACKTYPE=0 # 0 - No Attack, 1 - Loud blackhole, 2 - Silent blackhole
DEFENCE=0 # 0 - No defence, 1 - DCFM, 2 - DCFM + Route
BLDGFILE="${map_files_location}/${pbf_file_name}-${B}.buildings.xml"

function runOnce() {
	OFFSET=$1

	local NS_NAME="${bm_run_location}/${pbf_file_name}-${B}-${N}-${OFFSET}"
	local NS_PARAMS="${NS_NAME}.ns_params"
	local NS_MOVEMENTS="${NS_NAME}-5.ns_movements"
	
	if [ $ATTACKTYPE -eq 1 ]; then
		local IsolationAttack="true"
	else
		local IsolationAttack="false"
	fi

	if [ $DEFENCE -eq 1 ]; then
                local EnableFictive="true"
        else
                local EnableFictive="false"
        fi
    	
	NS_GLOBAL_VALUE="RngRun=$((OFFSET+2000))" ${ns_location}/build/scratch/${ns_code_name} --bldgFile=$BLDGFILE --paramsFile=$NS_PARAMS --traceFile=$NS_MOVEMENTS --bIsolationAttackBug=$IsolationAttack --bEnableFictive=$EnableFictive --bMobility=true --bHighRange=true --bUdpServer=true
	
	if [ $? -ne 0 ]; then
		echo "ERROR"
		exit 1
	fi
}

function runMultiple() {
	R=$1

	local MYTEMPDIR=$(mktemp -dp .)
	local FILE="../Blackhole_n${N}_AttackType-${ATTACKTYPE}_AttackLoc-${ATTACKLOC}_Defence-${DEFENCE}_"
	local LOGFILE="${FILE}log-r${R}.txt"
	local LOGFILETOTAL="${FILE}log.txt"
	
	cd $MYTEMPDIR

	for ((i=$2;i<$3;i+=1)); do
		echo "This is run $i" >> $LOGFILE
		runOnce $i >> $LOGFILE
		local d=`date`
		echo Finished run $i on process $R at $d
	done
	
	flock -e $LOGFILETOTAL cat $LOGFILE >> $LOGFILETOTAL
	mkdir -p ../tmpdel
	mv $LOGFILE ../tmpdel
	cd ..
	rm -R $MYTEMPDIR
}

# Call function to run on cores
function runOnCores(){
	for ((i=0;i<$CORES;i+=1)); do
	  FROM=$(( $FIRSTI + $PERCORE * $i ))
	  TO=$(( $FROM + $PERCORE ))
	  runMultiple $i $FROM $TO &
	done

	# Leftovers
	FROM=$(($FIRSTI + $PERCORE*$CORES)) 
	if [ $TOTALRUNS -gt $FROM ]; then
	  runMultiple $CORES $FROM $TOTALRUNS
	fi
	wait
}

TOTALRUNS=$7 #500
CORES=$8 #10
FIRSTI=$9 #0
PERCORE=$(($TOTALRUNS/$CORES))

#for ((N=30; N<= 30; N+=100)); do
#	for ((ATTACKTYPE=0; ATTACKTYPE <= 1; ATTACKTYPE+=1)); do
#		for ((ATTACKLOC=1; ATTACKLOC <= 6; ATTACKLOC+=1)); do
#			for ((DEFENCE=0; DEFENCE <= 1; DEFENCE+=1)); do
#				runOnCores&
#				wait
#			done
#		done
#	done
#done

for i in ${10}; do
	N=$i
	for j in ${11}; do
		ATTACKTYPE=$j
		for k in ${12}; do
			ATTACKLOC=$k
			for l in ${13}; do
				DEFENCE=$l
				runOnCores&
				wait
			done
		done
	done
done
