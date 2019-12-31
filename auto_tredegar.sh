#!/bin/bash

#----#----#----#----#----#----#----#----#----#----

HELP="
This BASH script will run Tredegar as new BS Projects are populated on the DGS BaseSpace account.

USAGE = auto_tredegar.sh <mounted_BS_directory> <output_directory> 

Option: list of basespace projects 
If you wish to run Tredegar on extant BaseSpace projects,  provide the names of these projects as an optional third positional argument in a comma-sepparated list without spaces, e.g. project1,project2,project3

"

#----#----#----#----#----#----#----#----#----#----

# If the user invokes the script with -h or any command line arguments, print some help.
if [ "$#" -eq 0 ] || [ "$1" == "-h" ] ; then
  echo "HELP"
  exit 0
fi

# set variables from user input
bs_path=$1
if [ -z "$2" ]; then
  echo "Output directory required"
  echo $HELP
  exit 0
else
  output=$2
fi
project_list=$3

#ensure basemount directory is mounted
if [ -n "$(basemount-cmd --path ${bs_path}/Projects refresh | grep Error)" ]
then
  echo "Issue with basemount directory; attempting to remount ${bs_path}"
  yes | basemount --unmount ${path}
  basemount ${path} 
fi

#capture list of bs_projects
ls ${bs_path}/Projects > ${output}/bs_projects.log

# check to see if a speific list of projects have been provided
if [ ! -z "$project_list" -a "$project_list" != " " ]; then
  for project in $(echo $project_list | sed "s/,/ /g")
  do
   # if so, remove project from bs_project.log so that tredegar reports will be generated for those projects
   sed -e s/${project}//g -i ${output}/bs_projects.log
  done
fi

#run tredegar for newly added BS projects
while [ -d "$bs_path" ]
do
  bs_projects="$(ls ${bs_path}/Projects)"
  for project in ${bs_projects}
  do 
    # if a project in the mounted directory isn't in the bs_projects.log file, run tredegar
    if ! grep "${project}" ${output}/bs_projects.log
    then
      echo "new project found: ${project}"
      # check to make sure read files are availalbe, first
      if [ "$(ls ${bs_path}/Projects/${project}/Samples/)" ]
      then 
        staphb_toolkit_workflows tredegar ${bs_path}/Projects/${project} -o ${output}/${project}
        mkdir ${bs_path}/Projects/${project}/AppResults/Tredegar_"$(date +%F)"_"$(date +%H:%M)"/
	# copy file to a Tredegar AppResults and mark session complete
        cp ${output}/${project}/tredegar_output/*report.tsv ${bs_path}/Projects/${project}/AppResults/Tredegar_"$(date +%F)"_"$(date +%H:%M)"/  && cd ${bs_path}/Projects/${project}/AppResults/Tredegar_"$(date +%F)"_"$(date +%H:%M)"/ && basemount-cmd mark-as-complete
        cd $HOME
        echo "$project added "$(date +%F)"_"$(date +%H:%M)"" >> ${output}/bs_projects.log
      else
        echo "Read files not yet available for ${project}"
      fi
    fi
  done
  sleep 30s

  # refresh  basemounted directory 
  if [ -n "$(basemount-cmd --path ${bs_path}/Projects refresh | grep Error)" ]
  then
    echo "Issue with basemount directory; attempting to remount ${bs_path}"
    yes | basemount --unmount ${path}
    basemount ${path}
  fi

done

echo "ERROR: Auto loop has ended "$(date +%F)"" >> ${output}/bs_projects.log


