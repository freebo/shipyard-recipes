#!/usr/bin/env bash
#Put this in the input dir

echo "Sleeping 20"
sleep 20
echo "Starting...."
set -e
set -o pipefail

# set up mpi and set up openfoam env
source $INTELCOMPILERVARS intel64
source /opt/intel/compilers_and_libraries/linux/mpi/bin64/mpivars.sh
export MPI_ROOT=$I_MPI_ROOT
OPENFOAM_DIR=/opt/OpenFOAM/OpenFOAM-4.0
INPUT_DIR=$AZ_BATCH_NODE_SHARED_DIR/azblob/input
OUTPUT_DIR=$AZ_BATCH_NODE_SHARED_DIR/azblob/output
JOB=OFtest
source $OPENFOAM_DIR/etc/bashrc

# copy sample into BeeGFS shared area
BGFS_DIR=/mnt/resource/batch/tasks/mounts/auto_scratch/openfoamjob
cd $BGFS_DIR
cp -r $INPUT_DIR/$JOB .
#cp $OPENFOAM_DIR/tutorials/incompressible/simpleFoam/pitzDailyExptInlet/system/decomposeParDict $JOB_DIR/system/

echo "Copy done"
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
echo "Decompose"
cd $JOB
blockMesh
decomposePar -force

# execute mpi job
mpirun -np $np -ppn $ppn -hosts $AZ_BATCH_HOST_LIST simpleFoam -parallel