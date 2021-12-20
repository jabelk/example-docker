# Learn by Doing: Run NSO inside a Docker container

In recent years, Docker and other container engines have become a standard way of packaging and deploying applications.
Deploying applications as containers brings several benefits, including being more light-weight as opposed to VMs, better portability, quicker development cycles and more.   
While NSO does not come with an official Docker image, it does not mean that it can not be done. In fact, creating a simple Docker image for NSO is quite easy. 

In this example, you will learn how to package and run NSO inside a Docker container and review the already existing options for doing so.

## Preparing the environment

First things first, you need a local Docker installation. While this can be done on Windows, Linux distributions are more commonly used for this.  

If you do not have access to a Linux machine, you can use the Sandbox from Cisco DevNet to get access to one. 
You can reserve your [Cisco DevNet Sandbox here](https://devnetsandbox.cisco.com/RM/Diagram/Index/43964e62-a13c-4929-bde7-a2f68ad6b27c?diagramType=Topology).

Docker's installation may differ from one distribution to another, so install it according to the distribution you are using as per instructions on [Docker's official site](https://docs.docker.com/engine/install/). Docker is already installed on the `DevBox` `(10.10.20.50)` machine in the Sandbox.  
To make sure Docker is installed, run the `docker -v` command to display Docker version.

```
developer@devbox:~$ docker -v
Docker version 20.10.2, build 2291f61
```

You also need an NSO installer file. You can get the latest version of NSO [here](https://developer.cisco.com/docs/nso/#!getting-nso/getting-nso), if you are not using the sandbox, though an NSO installer is already present in the `~/Downloads` folder on the `DevBox` machine.

```
(py3venv) [developer@devbox ~]$ ls Downloads/
cisco_x509_verify_release.py3        ncs-5.4.1-resource-manager-3.5.3.tar.gz
install-local-nso.sh                 ncs-5.4.1-resource-manager-project-3.5.3
ncs-5.4.1-cisco-asa-6.12.4.tar.gz    nso-5.4.1.linux.x86_64.installer.bin
ncs-5.4.1-cisco-ios-6.67.9.tar.gz    requirements.txt
ncs-5.4.1-cisco-iosxr-7.32.1.tar.gz  setup-py3venv.sh
ncs-5.4.1-cisco-nx-5.20.6.tar.gz
(py3venv) [developer@devbox ~]$
```

If you are not on the devbox, note that the installer comes as a signed file (`.signed.bin`). Extract it with `sh` command to get the installer file named `nso-<version>.linux.x86_64.installer.bin`. It is already extracted in the Downloads folder on the devbox in the Sandbox though.  


## Creating a container image

To create a Docker container, you first need to create a container image. These images are a list of commands specified in a Dockerfile, performed on top of a base container image. With these commands you copy files into the container image, set up dependencies, run shell commands and more. You can find a list of all the Dockerfile commands [here](https://docs.docker.com/engine/reference/builder/).

Read the [NSO installation guide](https://developer.cisco.com/docs/nso/#!getting-and-installing-nso) and think about what needs to be done at the most basic level in order to install, run and use NSO:
* Install the required software packages
* Get the NSO installer
* Install NSO
* Run `ncs` service

### Create the Dockerfile

Create a new folder for your NSO Docker project, and create a file named `Dockerfile` in it. This folder will also serve as the root folder for your Docker project, meaning any relative file reference in your Dockerfile will start from there.

```
developer@devbox:~$ mkdir nso-docker
developer@devbox:~$ cd nso-docker/
developer@devbox:~/nso-docker$ touch Dockerfile
developer@devbox:~/nso-docker$ 
```

Study the Dockerfile commands and populate the `Dockerfile` you created by adding the following commands.  
First, choose the base container image. There are multiple Linux images you can use. In this example, `ubuntu` will be used.

```
FROM ubuntu:latest
```

NSO requires some specific software packages to function, namely Java, Apache Ant, LibXML2, and SSH keygen. Use a `RUN` command to install those packages with a package manager. You can optionally add comment lines, that start with `#`.

```
# Install dependencies
RUN apt-get update \
  && apt-get install -qy default-jdk ant libxml2-utils openssh-server
```

Add a COPY command to copy the NSO installer. In order for your Dockerfile to support multiple versions of installers, add the installer file path as an argument with the `ARG` command

```
# Copy NSO installer to container
ARG NSO_INSTALL_FILE
COPY $NSO_INSTALL_FILE /tmp/nso
```

### Create installation and run scripts

Study the installation process and create an installation Bash script. You could use the `RUN` commands, but since NSO uses the `ncsrc` script which sets up environmental variables, its more practical this way.  
You also need a run script, that will start the NSO service and connect you directly to the NSO CLI when entering the container.

In the root folder of the project, create the `install-nso.sh` and `run-nso.sh` scripts.  
The `install-nso.sh` script should look something like this:

```
#!/bin/bash
/tmp/nso --local-install --non-interactive /nso-install
source /nso-install/ncsrc
ncs-setup --dest /nso-run
```

>Note: Local NSO installation is used in this example, since it is a bit simpler to install, although a System NSO installation could also be set up in a container

And the `run-nso.sh` script should look similar to this:

```
#!/bin/bash
source /nso-install/ncsrc
cd /nso-run
ncs
ncs_cli -C -u admin
```

Add Dockerfile commands that will copy these scripts into the container with `COPY` command, and add a `RUN` command that will execute the install script.

```
# Copy scripts
COPY install-nso.sh /tmp/install-nso.sh
COPY run-nso.sh /tmp/run-nso.sh

# Install NSO
RUN /tmp/install-nso.sh
```

Additionally, NSO container needs needs connectivity from the outside. Using the `EXPOSE` command, expose the following ports on the container:
* Port 22 for SSH
* Ports 80 and 443 for HTTP and HTTPS access
* Ports 830 and 4334 for Netconf communication

```
# Expose SSH, HTTP, HTTPS and NETCONF ports
EXPOSE 22 80 443 830 4334
```

Add `ncsrc` to the `.bashrc` file. This will make sure that environmental variables are set up correctly if you connect to the containers shell.

```
# Source NSO commands
RUN echo 'source /nso-install/ncsrc' >> /root/.bashrc
```

And finally, add the run script as the default container startup command with `CMD`.

```
# Start NSO
CMD ["/tmp/run-nso.sh"]
```

The final Dockerfile should look like this:

```
FROM ubuntu:latest

# Install dependencies
RUN apt-get update \
  && apt-get install -qy default-jdk ant libxml2-utils openssh-server

# Copy NSO installer to container
ARG NSO_INSTALL_FILE
COPY $NSO_INSTALL_FILE /tmp/nso

# Copy scripts
COPY install-nso.sh /tmp/install-nso.sh
COPY run-nso.sh /tmp/run-nso.sh

# Install NSO
RUN /tmp/install-nso.sh

# Expose SSH, HTTP, HTTPS and NETCONF ports
EXPOSE 22 80 443 830 4334

# Source NSO commands
RUN echo 'source /nso-install/ncsrc' >> /root/.bashrc

# Start NSO
CMD ["/tmp/run-nso.sh"]
```

>Note: There are multiple different approaches when it comes to achieving the same thing with Dockerfile commands. This Dockerfile is just meant to give you a general idea on how you would approach this.

### Build the container image

After you successfully create the Dockerfile, you need to use it to build an image.   
The command to build your Docker image is `docker build -t <image_tag>:<image_version> --build-arg <arguments> <path>`. Make sure you execute the command from the root folder of your Docker project. Tag the image with the tag `my-nso`.

```
developer@devbox:~/nso-docker$ docker build -t my-nso:1.0 --build-arg NSO_INSTALL_FILE=nso-5.4.1.linux.x86_64.installer.bin .
Sending build context to Docker daemon    192MB
Step 1/9 : FROM ubuntu:latest

< ... Output Omitted ... >

Successfully built 3e6482951783
Successfully tagged my-nso:1.0
developer@devbox:~/nso-docker$ 
```

To verify that your image was successfully build, check your local images with `docker images` command. There might be other images here, just make sure that `my-nso` image is preset.

```
developer@devbox:~/nso-docker$ docker images
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
my-nso       1.0       3e6482951783   33 minutes ago   1.43GB
developer@devbox:~/nso-docker$ 
```

## Running NSO as a container

Now your container image is ready.  
You can create and run a container from an image by using the `docker run <image>` command. Add the `-it` flag so that the container will run in an interactive terminal mode.

```
developer@devbox:~/nso-docker$ docker run -it my-nso:1.0
ncs[15]: - Enabling daemon log
ncs[15]: - Starting NCS vsn: 5.4.2
ncs[15]: - Loading file confd.fxs
ncs[15]: - Loading file ietf-yang-types.fxs
ncs[15]: - Loading file ietf-inet-types.fxs
ncs[15]: - Loading file ietf-datastores.fxs
ncs[15]: - Loading file ietf-yang-library.fxs
ncs[15]: - Loading file ietf-yang-patch.fxs
ncs[15]: - Loading file ietf-netconf.fxs
ncs[15]: - Loading file ietf-netconf-with-defaults.fxs
ncs[15]: - Loading file netconf_netmod.fxs
ncs[15]: - Loading file ietf-restconf.fxs

< ... Output Omitted ... >

ncs[15]: - NCS started vsn: 5.4.2
ncs[15]: - Starting the NCS Smart Licensing Java VM

admin connected from 127.0.0.1 using console on bf6b66c68a0b
admin@ncs#
```

You were able to observe the log from the `ncs` service starting, and are now located in the NSO CLI.  

```
admin@ncs# show packages 
% No entries found.
admin@ncs# 
```

Congratulations, you have successfully set up NSO in a Docker container!

Since you are in an interactive mode, exiting the NSO CLI will kill that process and thus exit and stop the container.  
Using the `docker ps -a` command, you can see a list of all your containers.

```
admin@ncs# exit
developer@devbox:~/nso-docker$ docker ps -a
CONTAINER ID   IMAGE          COMMAND                  CREATED         STATUS                          PORTS     NAMES
bf6b66c68a0b   my-nso:1.0     "/tmp/run-nso.sh"        6 minutes ago   Exited (0) About a minute ago             great_shamir
developer@devbox:~/nso-docker$ 
```

This is not practical, if you want your container to live in the background even if you are not connected to NSO CLI.  
An alternative approach to running the container interactively and entering the NSO CLI directly with the `run-nso.sh` script, is to run the container in detached mode in the background with `-d` flag, instead of `-it`.  
In order for this to work, the run script would have to only start the `ncs` process, and monitor its process id (PID), or just run indefinitely with a `while true` Bash statement. To keep things simple for this example, just replace the last line in the `nso-run.sh` script with a `while` loop that runs `sleep` command.  

```
#!/bin/bash
source /nso-install/ncsrc
cd /nso-run
ncs
while true; do sleep 10000; done
```

Rebuild the container image and tag it with `1.1` version.    


```
developer@devbox:~/nso-docker$ docker build -t my-nso:1.1 --build-arg NSO_INSTALL_FILE=nso-5.4.1.linux.x86_64.installer.bin .
Sending build context to Docker daemon    192MB
Step 1/10 : FROM ubuntu:latest
 ---> ba6acccedd29
Step 2/10 : RUN apt-get update   && apt-get install -qy default-jdk ant libxml2-utils openssh-server
 ---> Using cache
 ---> 345d32b621b2

< ... Output Omitted ... >

Successfully built 187a22e5781e
Successfully tagged my-nso:1.1
developer@devbox:~/nso-docker$
```

Run the container in a detached mode with `-d` flag.

```
developer@devbox:~/nso-docker$ docker run -d my-nso:1.1
6afebd456836260a7d90de67b94ec86c9aa496157b8521e9cfb0bb759a138d35
developer@devbox:~/nso-docker$ docker ps -a
CONTAINER ID   IMAGE          COMMAND                  CREATED          STATUS                       PORTS                                        NAMES
6afebd456836   my-nso:1.1     "/tmp/run-nso.sh"        4 seconds ago    Up 4 seconds                 22/tcp, 80/tcp, 443/tcp, 830/tcp, 4334/tcp   clever_carson
developer@devbox:~/nso-docker$ 
```

After you run the container in the detached mode, you can still enter its shell and run commands with `docker exec <container> <command>` command.  
For example, you can enter the NSO container shell by interactively (`-it`) running `bash` command in the container, and then entering NSO CLI from there.

```
developer@devbox:~/nso-docker$ docker exec -it 6afebd456836 bash
root@6afebd456836:/# ls nso-run/
README.ncs  logs  ncs-cdb  ncs.conf  packages  scripts  state  store dstate  target
root@6afebd456836:/# ncs_cli -C -u admin

admin connected from 127.0.0.1 using console on 6afebd456836
admin@ncs# 
```

Exiting such a session will not stop the NSO container.

```
admin@ncs# exit
root@6afebd456836:/# exit
exit
developer@devbox:~/nso-docker$ docker ps -a
CONTAINER ID   IMAGE          COMMAND                  CREATED          STATUS                        PORTS                                        NAMES
6afebd456836   my-nso:1.1     "/tmp/run-nso.sh"        5 minutes ago    Up 5 minutes                  22/tcp, 80/tcp, 443/tcp, 830/tcp, 4334/tcp   clever_carson
developer@devbox:~/nso-docker$ 
```

Another thing that is missing is the NSO packages and NEDs. You could simply copy them into a running container with `docker cp <src> <container>:<dest>`, and compile and load them by hand.
Another option would be to use either a volume of a bind mount, where both options add [persistent data](https://docs.docker.com/storage/) to containers. Using this approach, another script would be needed that compiles the packages (by running `make` in package `/src` folders), before they can be loaded into NSO. 

## Project 'NSO in Docker'

All this makes using such quick and simple NSO images problematic to use for anything else that simple testing.  
If you wanted to use NSO in a Docker container as a fully functioning development, testing and production environment, you would also need to take care of things such as:
* Making stored data persistent
* Adding development tools and packages
* Automatic NSO package compiling, loading and testing
* Providing a framework to integrate NSO containers into your workflows
* And much more!

Fortunately, there are open-source projects, that help you comprehensively package NSO deployments into Docker containers.  
One such project is the [NSO in Docker](https://github.com/NSO-developer/nso-docker) project.  
This is a project, maintained by Cisco, that enables users to easily run NSO in Docker containers. It is a tried and tested way of using Docker to set up an environment that allows you to use NSO, develop services, containerize and test with netsim devices, and eventually use a very similar setup for production. 

### Credit

Special Thanks to [Robert Silar](https://www.linkedin.com/in/robert-%C5%A1ilar-a5544487/) for helping write this post! 

