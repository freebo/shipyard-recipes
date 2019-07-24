#!/usr/bin/env bash
#Put this in the input dir

#set -e
#set -o pipefail

# set up mpi and set up openfoam env

source $INTELCOMPILERVARS intel64   
source /opt/intel/compilers_and_libraries/linux/mpi/bin64/mpivars.sh
export MPI_ROOT=$I_MPI_ROOT

export INPUT_DIR=/mnt/resource/batch/tasks/shared/azfile/Input
export OUTPUT_DIR=/mnt/resource/batch/tasks/shared/azfile/Output
JOB=OFtest


source $OPENFOAM_DIR/etc/bashrc

# copy sample into BeeGFS shared area
BGFS_DIR=/mnt/resource/batch/tasks/mounts/auto_scratch/openfoamjob
cd $BGFS_DIR
cp -r $INPUT_DIR/$JOB .
#cp $OPENFOAM_DIR/tutorials/incompressible/simpleFoam/pitzDailyExptInlet/system/decomposeParDict $JOB_DIR/system/

# get nodes and compute number of processors
IFS=',' read -ra HOSTS <<< "$AZ_BATCH_HOST_LIST"
nodes=${#HOSTS[@]}
ppn=`nproc`
np=$(($nodes * $ppn))

echo "Sedding"
# substitute proper number of subdomains
sed -i -e "s/^numberOfSubdomains 4/numberOfSubdomains $np;/" $JOB/system/decomposeParDict
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
mpirun -np $np -ppn $ppn -hosts $AZ_BATCH_HOST_LIST pisoFoam

cd $BGFS_DIR
cp -r * $OUTPUT_DIR/$JOB 