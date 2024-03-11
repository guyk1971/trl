# Environment scripts

this folder includes bash scripts that can be used to set up the environment for the project. The scripts are used to install the required packages and set up the environment variables.  

## Docker
first, from the project root folder run:
```bash
./env_scripts/docker_build_run_lws.sh
```  

this will build the docker image and run the container. 
it basically takes a base image, install the username + some additional tools + environment setup and then launch a container with folder and port mapping. see `docker_build_run_lws.sh` for more details.

Once the container is up and running, you'll have to perform a 'post-build' installations from within the container:

1. install TRL library from source:
   from this project's root folder, run the following command:
   ```bash
    pip install -e .
    ```
    this will also install the corresponding transformers package
1. Install additional required optimization packages:
   ```bash
    pip install deepspeed bitsandbytes peft 
    ```
1. run vs code and attach to the container. This will install the vs-code server inside the container.
1. install any necessary extensions in vs-code:
    - python


1. temporarily detach from the container (ctrl-p ctrl-q)
2. commit the container to an image:
    ```bash
    docker commit <container_id> trl:dev
    ```   
    where `<container_id>` is the id of the running container. you can get it by running `docker ps` and looking at the `CONTAINER ID` column. or just use the container name
3. re-attch to the container:
    ```bash
    docker attach <container_id>
    ```   
    or just use the container name

from now on, you can also use the `docker_run_lws.sh` script to run the container with secondary name and port mapping
