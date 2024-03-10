#!/bin/bash
# DIR is the directory where the script is saved (should be <project_root/scripts)
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd $DIR

MY_UID=$(id -u)
MY_GID=$(id -g)
MY_UNAME=$(id -un)
BASE_IMAGE=nvcr.io/nvidia/pytorch:23.10-py3
mkdir -p ${DIR}/.vscode-server
LINK=$(realpath --relative-to="/home/${MY_UNAME}" "$DIR" -s)
IMAGE=trl
if [ -z "$(docker images -q ${IMAGE})" ]; then
    # Create dev.dockerfile
    FILE=dev.dockerfile

    ### Pick Tensorflow / Torch based base image below
    # echo "FROM nvcr.io/nvidia/tensorflow:23.01-tf2-py3" > $FILE
    echo "FROM $BASE_IMAGE" > $FILE

    echo "  RUN apt-get update" >> $FILE
    echo "  RUN apt-get -y install nano gdb time" >> $FILE
    # echo "  RUN apt-get -y install nvidia-cuda-gdb" >> $FILE
    echo "  RUN apt-get -y install sudo" >> $FILE
    echo "  RUN (groupadd -g $MY_GID $MY_UNAME || true) && useradd --uid $MY_UID -g $MY_GID --no-log-init --create-home $MY_UNAME && (echo \"${MY_UNAME}:password\" | chpasswd) && (echo \"${MY_UNAME} ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers)" >> $FILE

    echo "  RUN mkdir -p $DIR" >> $FILE
    echo "  RUN ln -s ${LINK}/.vscode-server /home/${MY_UNAME}/.vscode-server" >> $FILE
    echo "  RUN echo \"fs.inotify.max_user_watches=524288\" >> /etc/sysctl.conf" >> $FILE
    echo "  RUN sysctl -p" >> $FILE
    echo "  USER $MY_UNAME" >> $FILE
    

    echo "  COPY docker.bashrc /home/${MY_UNAME}/.bashrc" >> $FILE 
    
    # START: install any additional package required for your image here
    echo "  RUN pip install transformers trl deepspeed accelerate bitsandbytes peft" >> $FILE
    # END: install any additional package required for your image here
    echo "  RUN source /home/${MY_UNAME}/.bashrc" >> $FILE
    echo "  WORKDIR $DIR/.." >> $FILE
    echo "  CMD /bin/bash" >> $FILE

    docker buildx build -f dev.dockerfile -t ${IMAGE} .
fi

EXTRA_MOUNTS=""
if [ -d "/home/${MY_UNAME}/.cache/" ]; then
    EXTRA_MOUNTS+=" --mount type=bind,source=/home/${MY_UNAME}/scratch,target=/home/${MY_UNAME}/scratch"
fi
MOUNT_TRANSFORMERS=""
primary_git_folder=$(dirname $(dirname $(dirname ${DIR})))
echo $primary_git_folder
echo $DIR

if [ -d "${primary_git_folder}/clones/transformers" ]; then
  # Folder exists, perform actions and print value
#   MOUNT_TRANSFORMERS="--mount type=bind,source=${primary_git_folder}/clones/transformers,target=${primary_git_folder}/clones/transformers"
    MOUNT_TRANSFORMERS="--mount type=bind,source=${primary_git_folder}/clones/transformers,target=/home/${MY_UNAME}/.local/lib/python3.10/site-packages/transformers"
  # You can add commands to interact with the folder here
else
  # Folder not found, print a message and abort
  echo "Error: please git clone transformers to ${primary_git_folder}/clones/transformers"
fi

# MOUNT_TRL=""
# if [ -d "${primary_git_folder}/clones/trl" ]; then
#   # Folder exists, perform actions and print value
#   MOUNT_TRL="--mount type=bind,source=${primary_git_folder}/clones/trl,target=${primary_git_folder}/clones/trl"
#   # You can add commands to interact with the folder here
# else
#   # Folder not found, print a message and abort
#   echo "Error: please git clone trl to ${primary_git_folder}/clones/tr"
# fi

MOUNT_TRL="--mount type=bind,source=${DIR}/..,target=/home/${MY_UNAME}/.local/lib/python3.10/site-packages/trl"
CACHE_FOLDER=/home/${MY_UNAME}/.cache


docker run \
    --gpus \"device=all\" \
    --privileged \
    --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 -it --rm \
    --mount type=bind,source=${DIR}/..,target=${DIR}/.. \
    --mount type=bind,source=${CACHE_FOLDER},target=${CACHE_FOLDER} \
    ${MOUNT_TRANSFORMERS} \
    ${MOUNT_TRL} \
    --shm-size=8g \
    --name trl_new  \
    ${IMAGE}

    # --mount type=bind,source=/home/scratch.svc_compute_arch,target=/home/scratch.svc_compute_arch \
    # --mount type=bind,source=/home/utils,target=/home/utils \
    # --mount type=bind,source=/home/scratch.computelab,target=/home/scratch.computelab \
    # --name nemo \
    # -p 8888:8888 -p 6006:6006 
    # ${EXTRA_MOUNTS} \
cd -