#!/usr/bin/env bash
#Put this in the input dir

#set -e
#set -o pipefail

export INPUT_DIR=/mnt/resource/batch/tasks/shared/azfile/Input
export OUTPUT_DIR=/mnt/resource/batch/tasks/shared/azfile/Output
JOB=OFtest

# set up intel and openfoam env


source $INTELCOMPILERVARS intel64   
source /opt/intel/compilers_and_libraries/linux/mpi/bin64/mpivars.sh
export MPI_ROOT=$I_MPI_ROOT

source $OPENFOAM_DIR/etc/bashrc

# copy sample into BeeGFS shared area
BGFS_DIR=/mnt/resource/batch/tasks/mounts/auto_scratch/openfoamjob
cd $BGFS_DIR
cp -r $INPUT_DIR/$JOB .
#cp $OPENFOAM_DIR/tutorials/incompressible/simpleFoam/pitzDailyExptInlet/system/decomposeParDict $JOB_DIR/system/

# get nodes and compute number of processors
echo "nodes $AZ_BATCH_HOST_LIST"
IFS=',' read -ra HOSTS <<< "$AZ_BATCH_HOST_LIST"
nodes=${#HOSTS[@]}
ppn=`nproc`
np=$(($nodes * $ppn))

echo "Sedding"
# substitute proper number of subdomains
sed -i -e "s/^numberOfSubdomains 12/numberOfSubdomains $np;/" $JOB/system/decomposeParDict
root=`python -c "import math; x=int(math.sqrt($np)); print x if x*x==$np else -1"`
if [ $root -eq -1 ]; then
    sed -i -e "s/\s*n\s*(2 2 1)/    n               ($ppn $nodes 1)/g" $JOB/system/decomposeParDict
else
    sed -i -e "s/\s*n\s*(2 2 1)/    n               ($root $root 1)/g" $JOB/system/decomposeParDict
fi

# decompose

cd $JOB
#blockMesh
decomposePar -force


# execute mpi job
#mpirun -np $np -ppn $ppn -hosts $AZ_BATCH_HOST_LIST simpleFoam -parallel

echo "pisoFoam"
/opt/intel2/compilers_and_libraries_2018.5.274/linux/mpi/intel64/bin/mpirun -np $np -ppn $ppn -hosts $AZ_BATCH_HOST_LIST pisoFoam

echo "copy output"
cd $BGFS_DIR
rm -r $OUTPUT_DIR/$JOB
mkdir $OUTPUT_DIR/$JOB
cp -r * $OUTPUT_DIR/$JOB 