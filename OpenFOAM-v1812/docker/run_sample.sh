#!/usr/bin/env bash

#set -e
#set -o pipefail
#set -x
echo "Starting!"
echo "Source intel64"

# set up openfoam env

echo "Source bashrc"

source $OPENFOAM_DIR/etc/bashrc

# copy sample into glusterfs shared area
GFS_DIR=$AZ_BATCH_NODE_SHARED_DIR/gfs
GFS_DIR=/mnt/resource/batch/tasks/mounts/auto_scratch/openfoamjob
echo "cd GFS"
cd $GFS_DIR
echo "cp"
cp -r $OPENFOAM_DIR/tutorials/incompressible/simpleFoam/pitzDaily .
cp $OPENFOAM_DIR/tutorials/incompressible/simpleFoam/pitzDailyExptInlet/system/decomposeParDict pitzDaily/system/

echo "cp done"
# get nodes and compute number of processors
IFS=',' read -ra HOSTS <<< "$AZ_BATCH_HOST_LIST"
nodes=${#HOSTS[@]}
ppn=`nproc`
np=$(($nodes * $ppn))

# substitute proper number of subdomains
sed -i -e "s/^numberOfSubdomains 4/numberOfSubdomains $np;/" pitzDaily/system/decomposeParDict
root=`python -c "import math; x=int(math.sqrt($np)); print x if x*x==$np else -1"`
if [ $root -eq -1 ]; then
    sed -i -e "s/\s*n\s*(2 2 1)/    n               ($ppn $nodes 1)/g" pitzDaily/system/decomposeParDict
else
    sed -i -e "s/\s*n\s*(2 2 1)/    n               ($root $root 1)/g" pitzDaily/system/decomposeParDict
fi

# decompose
cd pitzDaily
blockMesh
decomposePar -force

#set up mpi
source $INTELCOMPILERVARS intel64
echo "source mpivars"
source /opt/intel2/compilers_and_libraries_2018.5.274/linux/mpi/intel64/bin/mpivars.sh
export MPI_ROOT=$I_MPI_ROOT

# execute mpi job
echo "mpirun -np $np -ppn $ppn -hosts $AZ_BATCH_HOST_LIST simpleFoam -parallel"
sleep 1500

mpirun -np $np -ppn $ppn -hosts $AZ_BATCH_HOST_LIST simpleFoam #-parallel