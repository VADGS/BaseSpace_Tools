#!/bin/bash

#----#----#----#----#----#----#----#----#----#----

USAGE="
This BASH script will run Tredegar as new BS Projects are populated on the DGS BaseSpace account.

USAGE = auto_tredegar.sh <mounted_BS_directory> <output_directory>

"

#----#----#----#----#----#----#----#----#----#----


bs_path=$1
output=$2
project_list=$3
echo $USAGE

#ensure basemount directory is mounted
if [ -n "$(basemount-cmd --path ${bs_path}/Projects refresh | grep Error)" ]
then
  echo "Issue with basemount directory; attempting to remount ${bs_path}"
  yes | basemount --unmount ${path}
  basemount ${path} 
fi

#capture list of bs_projects
ls ${bs_path}/Projects > ${output}/bs_projects.log

# run Tredegar on the given list of projects
if [ ! -z "$project_list" -a "$project_list" != " " ]; then
  for project in $(echo $project_list | sed "s/,/ /g")
  do
    staphb_toolkit_workflows tredegar ${bs_path}/Projects/${project} -o ${output}/${project}
    mkdir ${bs_path}/Projects/${project}/AppResults/Tredegar_"$(date +%F)"_"$(date +%H:%M)"/
    cp ${output}/${project}/tredegar_output/*report.tsv ${bs_path}/Projects/${project}/AppResults/Tredegar_"$(date +%F)"_"$(date +%H:%M)"/  && cd ${bs_path}/Projects/${project}/AppResults/Tredegar_"$(date +%F)"_"$(date +%H:%M)"/ && basemount-cmd mark-as-complete
    cd $HOME
    echo $project
    echo "$project added "$(date +%F)"_"$(date +%H:%M)"" >> ${output}/bs_projects.log
  done
fi

#run tredegar for newly added BS projects
while [ -d "$bs_path" ]
do
  bs_projects="$(ls ${bs_path}/Projects)"
  for project in ${bs_projects}
  do 
    if ! grep "${project}" ${output}/bs_projects.log
    then
      echo "new project found: ${project}"
      staphb_toolkit_workflows tredegar ${bs_path}/Projects/${project} -o ${output}/${project}
      mkdir ${bs_path}/Projects/${project}/AppResults/Tredegar_"$(date +%F)"_"$(date +%H:%M)"/
      cp ${output}/${project}/tredegar_output/*report.tsv ${bs_path}/Projects/${project}/AppResults/Tredegar_"$(date +%F)"_"$(date +%H:%M)"/  && cd ${bs_path}/Projects/${project}/AppResults/Tredegar_"$(date +%F)"_"$(date +%H:%M)"/ && basemount-cmd mark-as-complete
      cd $HOME
      echo "$project added "$(date +%F)"_"$(date +%H:%M)"" >> ${output}/bs_projects.log
    fi
  done
  sleep 2m

  #ensure basemount directory is mounted
  if [ -n "$(basemount-cmd --path ${bs_path}/Projects refresh | grep Error)" ]
  then
    echo "Issue with basemount directory; attempting to remount ${bs_path}"
    yes | basemount --unmount ${path}
    basemount ${path}
  fi

done

echo "ERROR: Auto loop has ended "$(date +%F)"" >> ${output}/bs_projects.log


