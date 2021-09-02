#!/bin/bash

#----#----#----#----#----#----#----#----#----#----

HELP="
This BASH script will run a series of in house developed scripts as new BS Projects are populated on the DGS BaseSpace account.

USAGE = auto_SC2_lineage_reporting.sh <mounted_BS_directory> <output_directory>

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
  echo "Output directory is required. (Something like /wgs_analysis/sars-cov-2/auto_lin_report/)
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
mkdir ${output}/lin_logs
ls -d1 ${bs_path}/Projects/nCOV* | awk -F "/" '{print $NF}' > ${output}/lin_logs/ncov_bs_projects.log

# set error log file
echo "$(date) Auto Lineage Reporting started: auto_SC2_lineage_reporting.sh $1 $2 $3" >>  ${output}/lin_logs/auto_lineage_report.log

# check to see if a specific list of projects have been provided
if [ ! -z "$project_list" -a "$project_list" != " " ]; then
  for project in $(echo $project_list | sed "s/,/ /g")
  do
   # if so, remove project from bs_project.log so that monroe reports will be generated for those projects
   echo ${project}
   sed -e s/${project}//g -i ${output}/lin_logs/ncov_bs_projects.log
  done
fi

#run lineage report for newly added BS projects
while [ -d "$bs_path" ]
do
  bs_projects="$(ls -d1 ${bs_path}/Projects/nCOV* | awk -F "/" '{print $NF}' )"
  # makew newlines only separator
  IFS=$'\n'
  cd ${output}
  for project in ${bs_projects}
  do
    # if a project in the mounted directory isn't in the bs_projects.log file, run lineage report
    echo "Now checking if ${project} is in the bs projects log"
    if ! grep "${project}" ${output}/lin_logs/ncov_bs_projects.log
    then
      echo "Project identified for SC2 lineage analysis: ${project}"
      # check to make sure the monroe_summary file is present and not zero size before running
      comparator=0
      touch monroe_summary_file
      rm monroe_summary_file
      touch monroe_date_file
      rm monroe_date_file
      #Pick the most recent monroe summary to use for the analysis of the Basespace project
      for f in ${bs_path}/Projects/${project}/AppResults/Monroe_*/Files/monroe_summary*; do
        echo $f
        monroe_date=$(echo $f|cut -d"/" -f8)
        echo $monroe_date >> monroe_date_file
      done
      monroe_date_path=$(sort monroe_date_file | tail -1)
      echo $monroe_date_path
      for g in ${bs_path}/Projects/${project}/AppResults/$monroe_date_path/Files/monroe_summary*; do
        monroe_summary=$(echo $f|cut -d"/" -f10)
        echo $monroe_summary >> monroe_summary_file
      done
      monroe_summary_path=$(sort monroe_summary_file | tail -1)
      rm -rf monroe_date_file
      rm -rf monroe_summary_file
      echo "Checking if ${bs_path}/Projects/${project}/AppResults/$monroe_date_path/Files/$monroe_summary_path exists"
      if [ -s ${bs_path}/Projects/${project}/AppResults/$monroe_date_path/Files/$monroe_summary_path ]; then
        echo "We are running the script now"
        #Sleep for five minutes to ensure that the files have been generated before proceeding
        sleep 5m
        ##run transfer files script to pull out the VOCs/VOIs and get them to file, verify mutations
        mkdir ${output}/${project}
        #The line below, is the old line, keeping it in case we still need it
        #bash /home/ubuntu/Applications/lineage_reporting_tools/pangoroe.sh -n ${output} -s /wgs_analysis/sars-cov-2/auto_monroe/${project}/monroe_summary* -p ${project}
        bash /home/ubuntu/Applications/lineage_reporting_tools/pangoroe.sh -n ${output} -s ${bs_path}/Projects/${project}/AppResults/$monroe_date_path/Files/$monroe_summary_path -p ${project}
	echo -e "\tMonroe lineage report completed succesfully. Runtime: ${runtime_min}M" >> ${output}/lin_logs/auto_lineage_report.log
	mkdir ${bs_path}/Projects/${project}/AppResults/Pangoroe_report_"$(date +%F)"_"$(date +%H:%M)"
	# copy file to a Monroe AppResults and mark session complete
        cp ${output}/${project}/VOC_VOI_characteristics_*.csv  ${bs_path}/Projects/${project}/AppResults/Pangoroe_report_"$(date +%F)"_"$(date +%H:%M)"/Files/ && cd ${bs_path}/Projects/${project}/AppResults/Pangoroe_report_"$(date +%F)"_"$(date +%H:%M)"/ && basemount-cmd mark-as-complete
        cd $output
	echo "$project" >> ${output}/lin_logs/ncov_bs_projects.log
      else
        echo -e "\tError: Monroe summary file not found for project ${project}. Runtime: ${runtime_min}M" >> ${output}/lin_logs/auto_lineage_report.log
        break
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

echo "ERROR: Auto loop has ended "$(date +%F)"" >> ${output}/lin_logs/auto_lineage_report.log


