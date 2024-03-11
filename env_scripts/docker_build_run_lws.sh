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
IMAGE=trl:dev
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
    echo "  RUN source /home/${MY_UNAME}/.bashrc" >> $FILE
    # START: install any additional package required for your image here
    # echo "  RUN pip install transformers deepspeed accelerate bitsandbytes peft" >> $FILE
    # END: install any additional package required for your image here
    echo "  WORKDIR $DIR/.." >> $FILE
    echo "  CMD /bin/bash" >> $FILE

    docker buildx build -f dev.dockerfile -t ${IMAGE} .
fi

EXTRA_MOUNTS=""
if [ -d "/home/${MY_UNAME}/scratch/" ]; then
# running on the cluster. 
    EXTRA_MOUNTS+=" --mount type=bind,source=/home/${MY_UNAME}/scratch,target=/home/${MY_UNAME}/scratch"
else
# local machine. assume it has the following folders in place:
    EXTRA_MOUNTS+=" --mount type=bind,source=/home/${MY_UNAME}/code,target=/home/${MY_UNAME}/code"
    EXTRA_MOUNTS+=" --mount type=bind,source=/home/${MY_UNAME}/data,target=/home/${MY_UNAME}/data"
    EXTRA_MOUNTS+=" --mount type=bind,source=/home/${MY_UNAME}/models,target=/home/${MY_UNAME}/models"
    # EXTRA_MOUNTS+=" --mount type=bind,source=/home/${MY_UNAME}/.cache/huggingface,target=/home/${MY_UNAME}/.cache/huggingface"
fi


docker run \
    --gpus \"device=all\" \
    --privileged \
    --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 -it --rm \
    --mount type=bind,source=${DIR}/..,target=${DIR}/.. \
    ${EXTRA_MOUNTS} \
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