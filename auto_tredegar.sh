#!/bin/bash

#----#----#----#----#----#----#----#----#----#----

USAGE="
This BASH script will run Tredegar as new BS Projects are populated on the DGS BaseSpace account.

USAGE = auto_tredegar.sh <mounted_BS_directory> <output_directory>

"

#----#----#----#----#----#----#----#----#----#----


bs_path=$1
output=$2
echo $USAGE

#ensure basemount directory is mounted
if [ -n "$(basemount-cmd --path ${bs_path}/Projects refresh | grep Error)" ]
then
  echo "Issue with basemount directory; attempting to remount ${bs_path}"
  yes | basemount --unmount ${path}
  basemount ${path} 
fi


ls ${bs_path}/Projects > ${output}/bs_projects.log

#capture current BS_projects
while [ -d "$bs_path" ]
do
  bs_projects="$(ls ${bs_path}/Projects)"
  for project in ${bs_projects}
  do 
    if ! grep "${project}" ${output}/bs_projects.log
    then
      echo "new project found: ${project}"
      staphb_toolkit_workflows tredegar ${bs_path}/Projects/${project} -o ${output}/${project}
      mkdir ${bs_path}/Projects/${project}/AppResults/Tredegar/
      cp ${output}/${project}/tredegar_output/*report.tsv ${bs_path}/Projects/${project}/AppResults/Tredegar/ && cd ${bs_path}/Projects/${project}/AppResults/Tredegar/ && basemount-cmd mark-as-complete
      cd $HOME
      echo "$project added "$(date +%F)"" >> ${output}/bs_projects.log
    fi
  done
  sleep 30s

  #ensure basemount directory is mounted
  if [ -n "$(basemount-cmd --path ${bs_path}/Projects refresh | grep Error)" ]
  then
    echo "Issue with basemount directory; attempting to remount ${bs_path}"
    yes | basemount --unmount ${path}
    basemount ${path}
  fi

done

echo "ERROR: Auto loop has ended "$(date +%F)"" >> ${output}/bs_projects.log


