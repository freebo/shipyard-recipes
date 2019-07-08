#!/usr/bin/env bash

set -e
set -o pipefail
set -x
echo "Starting!"
echo "Source intel64"

# set up mpi and set up openfoam env

source $INTELCOMPILERVARS intel64
echo "source mpivars"
source /opt/intel/compilers_and_libraries/linux/mpi/bin64/mpivars.sh
export MPI_ROOT=$I_MPI_ROOT
OPENFOAM_DIR=/opt/OpenFOAM/OpenFOAM-v1812
echo "Source bashrc"

cat $OPENFOAM_DIR/etc/bashrc
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

# execute mpi job
mpirun -np $np -ppn $ppn -hosts $AZ_BATCH_HOST_LIST simpleFoam -parallel