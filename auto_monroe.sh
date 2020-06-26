#!/bin/bash

#----#----#----#----#----#----#----#----#----#----

HELP="
This BASH script will run Monroe as new BS Projects are populated on the DGS BaseSpace account.

USAGE = auto_monroe.sh <mounted_BS_directory> <output_directory> 

Option: list of basespace projects 
If you wish to run Monroe on extant BaseSpace projects,  provide the names of these projects as an optional third positional argument in a comma-sepparated list without spaces, e.g. project1,project2,project3

"

#----#----#----#----#----#----#----#----#----#----

# If the user invokes the script with -h or any command line arguments, print some help.
if [ "$#" -eq 0 ] || [ "$1" == "-h" ] ; then
  echo "$HELP"
  exit 0
fi

# set variables from user input
bs_path=$1
if [ -z "$2" ]; then
  echo "Output directory is required. 
  $HELP"
  exit 0
else
  output=$2
fi
project_list=$3

#ensure basemount directory is mounted
if [ -n "$(basemount-cmd --path ${bs_path}/Projects refresh | grep Error)" ]
then
  echo "Issue with basemount directory; attempting to remount ${bs_path}"
  yes | basemount --unmount ${bs_path}
  basemount ${bs_path} 
fi

#capture list of bs_projects
mkdir ${output}/logs
ls -d1 ${bs_path}/Projects/nCOV* | awk -F "/" '{print $NF}' > ${output}/logs/ncov_bs_projects.log

# set error log file
echo "$(date) Auto Monroe started: auto_monroe.sh $1 $2 $3" >>  ${output}/logs/auto_monroe.log

# check to see if a speific list of projects have been provided
if [ ! -z "$project_list" -a "$project_list" != " " ]; then
  for project in $(echo $project_list | sed "s/,/ /g")
  do
   # if so, remove project from bs_project.log so that monroe reports will be generated for those projects
   echo ${project}
   sed -e s/${project}//g -i ${output}/logs/ncov_bs_projects.log
  done
fi

#run monroe for newly added BS projects
while [ -d "$bs_path" ]
do
  bs_projects="$(ls -d1 ${bs_path}/Projects/nCOV* | awk -F "/" '{print $NF}' )"
  # makew newlines only separator 
  IFS=$'\n'
  cd ${output}
  for project in ${bs_projects}
  do 
    # if a project in the mounted directory isn't in the bs_projects.log file, run tredegar
    if ! grep "${project}" ${output}/logs/ncov_bs_projects.log
    then
      echo "Project identified for Monroe analysis: ${project}"
      # check to make sure read files in addition to the positive controls are availalbe before running tredegar
      number_of_samples="$(ls ${bs_path}/Projects/${project}/Samples/ | wc -l)"
      if (( ${number_of_samples} > 2 ))
      then
	# allow time for all read data to be transferred to BaseSpace project
	sleep 15m
        # Check to see if primers are properly set
        primers=$( echo "${project}" | awk -F "_" '{print $NF}')
        echo "ARTIC Primers: ${primers}"
        if [[ ! "${primers}" == "V"? ]]; then 
	  echo -e "$(date) Error: primer set not identified for project ${project}" >> ${output}/logs/auto_monroe.log  &&\
	  echo "$project" >> ${output}/logs/ncov_bs_projects.log
          break
        fi
	echo "grabbing read data from ${bs_path}/Projects/${project}"
	mkdir -p ${output}/${project}/reads/
	cp ${bs_path}/Projects/${project}/Samples/*/Files/*.gz ${output}/${project}/reads/ 
	echo -e "$(date) Monroe initiated: \n\tProject: ${project}, primers: ${primers}" >>  ${output}/logs/auto_monroe.log
	start_time="$(date +%s)"
	staphb-wf monroe pe_assembly ${output}/${project}/reads/ --primers ${primers} -o ${output}/${project} 
	chmod 666 .nextflow/history 
        end_time="$(date +%s)"
	runtime=$((${end_time}-${start_time}))
	runtime_min=$(echo "scale=2; $runtime / 60" | bc)
        if [ ! -f ${output}/${project}/assemblies/*assembly_metrics.csv ]; then
	  echo -e "\tError: assembly_meterics.csv file not found for project ${project}. Runtime: ${runtime_min}M" >> ${output}/logs/auto_monroe.log
          echo $project >> ${output}/logs/ncov_bs_projects.log
	  break
        fi
	echo -e "\tMonroe completed succesffully. Runtime: ${runtime_min}M" >> ${output}/logs/auto_monroe.log 
	mkdir ${bs_path}/Projects/${project}/AppResults/Monroe_"$(date +%F)"_"$(date +%H:%M)"/
	# copy file to a Monroe AppResults and mark session complete
        cp ${output}/${project}/assemblies/*_assembly_metrics.csv  ${bs_path}/Projects/${project}/AppResults/Monroe_"$(date +%F)"_"$(date +%H:%M)"/  && cd ${bs_path}/Projects/${project}/AppResults/Monroe_"$(date +%F)"_"$(date +%H:%M)"/ && basemount-cmd mark-as-complete
        cd $output  
	echo "$project" >> ${output}/logs/ncov_bs_projects.log
      else
        echo "Read files not yet available for ${project}"
      fi
    fi
  done
  sleep 30m

  # refresh  basemounted directory 
  if [ -n "$(basemount-cmd --path ${bs_path}/Projects refresh | grep Error)" ]
  then
    echo "Issue with basemount directory; attempting to remount ${bs_path}"
    yes | basemount --unmount ${bs_path}
    basemount ${bs_path}
  fi

done

echo "ERROR: Auto loop has ended "$(date +%F)"" >> ${output}/logs/auto_monroe.log


