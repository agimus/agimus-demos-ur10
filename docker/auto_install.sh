#!/bin/bash

envPath="export DEVEL_HPP_DIR=/home/$USER/react/devel/"
ros_setup_path="/opt/ros/noetic/setup.bash"

VERBOSE=false

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        --verbose)
        VERBOSE=true
        shift
        ;;
        *)
        shift
        ;;
    esac
done

# Update the apt package index and Upgrade the Ubuntu system
function systemBasicUpdates() {
    sudo apt-get update
    if [[ $? > 0 ]]; then
        echo "apt-get update failed, exiting."
        exit
    else
        echo "apt-get update ran successfully, continuing with script."
    fi
    sudo apt-get -y upgrade
    if [[ $? > 0 ]]; then
        echo "apt-get upgrade failed, exiting."
        exit
    else
        echo "apt-get upgrade ran successfully, continuing with script."
    fi
}

# Install apt packages if not already installed
function installAptPackages() {
    for pkg in $1; do
        if dpkg --get-selections | grep -q "^$pkg[[:space:]]*install$" >/dev/null; then
            echo -e "$pkg is already installed"
        else
            if sudo apt-get -qq install $pkg; then
                echo "Successfully installed $pkg"
            else
                echo "Error installing $pkg"
            fi
        fi
    done
}

# Install pip packages
function installPipPackages() {
    echo "Note: Pip install with  --user Mode"
    if [ "$1" == "2" ]; then
        pip install $2 --user
    else
        pip3 install $2 --user
    fi
}

# Remove apt packages if installed
function removeAptPackages() {
    for pkg in $1; do
        if dpkg --get-selections | grep -q "^$pkg[[:space:]]*install$" >/dev/null; then
            echo -e "$pkg is installed. Gonna remove"
            if sudo apt-get -qq remove $pkg; then
                echo "Successfully removed $pkg"
            else
                echo "Error removing $pkg"
            fi
        else
            echo -e "$pkg is not installed"
        fi
    done
}

# Configure robotpkg apt repository
function robotpkgAptConfiguration() {
    sudo touch /etc/apt/sources.list.d/robotpkg.list
    sudo bash -c 'echo "deb [arch=amd64] http://robotpkg.openrobots.org/wip/packages/debian/pub $(lsb_release -cs) robotpkg" >> /etc/apt/sources.list.d/robotpkg.list'
    sudo bash -c 'echo "deb [arch=amd64] http://robotpkg.openrobots.org/packages/debian/pub $(lsb_release -cs) robotpkg" >> /etc/apt/sources.list.d/robotpkg.list'

    curl -s http://robotpkg.openrobots.org/packages/debian/robotpkg.key | sudo apt-key add -
}

# Main React setup function
function ReactSetup()
{
	echo -e "┌──────────────────────────────────────────────────────────────────────────┐"
	echo -e "│\U0001F964 This might take a while, so grab a cup of coffee and relax!    │"
	echo -e "└──────────────────────────────────────────────────────────────────────────┘"


    # Clone the agimus-demos package
    mkdir -p /home/$USER/tmp/react/ && cd /home/$USER/tmp/react/ && \
    git clone -b dependency-updates-and-bugfixes https://github.com/nullbyte91/agimus-demos-ur10.git | pv -l -N "Cloning agimus-demos-ur10" > /dev/null

    # Create a development environment
    mkdir -p /home/$USER/react/devel/src/

    # Copy laas Make file
    cp /home/$USER/tmp/react/agimus-demos-ur10/docker/Makefile /home/$USER/react/devel/src/

    # Copy config file from agimus-demos to dev folder
    cp /home/$USER/tmp/react/agimus-demos-ur10/docker/config.sh.noetic /home/$USER/react/devel/config.sh

    # Get username and append
    sed -i "1s#.*#$envPath#g" /home/$USER/react/devel/config.sh

    chmod a+x /home/$USER/react/devel/config.sh

    cd /home/$USER/react/devel/

    source ./config.sh

    cd /home/$USER/react/devel/src/

    # Install packages
    for pkg in realsense_gazebo_plugin rgbd_launch visp_auto_tracker visp_camera_calibration visp_hand2eye_calibration \
                sot-universal-robot roscontrol_sot gerard-bauzil agimus-sot agimus-hpp agimus agimus-demos rviz_camera_stream \
                rviz_lighting Universal_Robots_ROS_Driver react_inria agimus-doc hpp-doc
    do
        if [ "$VERBOSE" = false ]; then
            make -C /home/$USER/react/devel/src/ ${pkg}.install 2>&1 | pv -l -N "Installing $pkg" > /dev/null
        else
            make -C /home/$USER/react/devel/src/ ${pkg}.install 2>&1
        fi
        
        if [ $? -ne 0 ]; then
            echo "Error: Package $pkg installation failed. Exiting."
            exit 1
        fi
    done

    # Post installation
    sudo cp /home/$USER/tmp/react/agimus-demos-ur10/docker/99-realsense-libusb.rules /etc/udev/rules.d/
    sudo cp /home/$USER/tmp/react/agimus-demos-ur10/docker/set_env_for_ur10 /root/

    configPath="/home/$USER/react/devel/config.sh"
    current_shell=$(echo $SHELL)

    if [[ $current_shell == "/usr/bin/bash" ]]; then
        echo "source $configPath" >> ~/.bashrc
        echo "source ${DEVEL_HPP_DIR}install/setup.bash" >> ~/.bashrc
    elif [[ $current_shell == "/usr/bin/zsh" ]]; then
        echo "source $configPath" >> ~/.zshrc
        echo "source ${DEVEL_HPP_DIR}install/setup.zsh" >> ~/.zshrc
    else
        echo "You are using a different shell: $current_shell"
    fi

    rm -rf /home/$USER/tmp/react/
}

# MainStartsHere

# Check ROS Noetic installation
if [ -f "$ros_setup_path" ]; then
    echo "Sourcing ROS Noetic setup.bash"
    . "$ros_setup_path"
else
    echo "ROS Noetic setup.bash not found. Please install ROS Noetic."
fi

#Basic system update
systemBasicUpdates

#Dep install
installAptPackages "curl wget git cmake vim g++ emacs pv"

#robotpkg apt update
robotpkgAptConfiguration

#robotpkg dep install
systemBasicUpdates
sudo apt install -qy ccache evince gdb gnuplot htop libzbar-dev liburdfdom-tools inetutils-ping libgtk2.0-dev libx11-dev liblapack-dev \
	 libeigen3-dev libjpeg-dev libpng-dev libssl-dev libusb-1.0-0-dev ros-${ROS_DISTRO}-image-common ros-${ROS_DISTRO}-tf ros-${ROS_DISTRO}-ddynamic-reconfigure \
	 ros-${ROS_DISTRO}-diagnostic-updater ros-${ROS_DISTRO}-rosdoc-lite texlive-latex-extra ps2eps python3-dev python3-pip python3-catkin ros-${ROS_DISTRO}-resource-retriever \
	 libassimp-dev robotpkg-collada-dom python-numpy doxygen liboctomap-dev liburdfdom-dev cmake-curses-gui libgraphviz-dev graphviz robotpkg-omniorb \
	 robotpkg-romeo-description robotpkg-py38-omniorbpy libccd-dev libltdl-dev python-omniorb python3-matplotlib qtbase5-private-dev qtdeclarative5-dev \
	 qtmultimedia5-dev libqt5svg5-dev libxml2 libtinyxml2-dev oxygen-icon-theme robotpkg-openscenegraph libpcre3-dev robotpkg-qt5-qgv \
	 robotpkg-qt5-osgqt ros-${ROS_DISTRO}-realtime-tools libbullet-dev ros-${ROS_DISTRO}-smach-ros ros-${ROS_DISTRO}-qt-gui-py-common \
	 ros-${ROS_DISTRO}-robot-state-publisher ros-${ROS_DISTRO}-gazebo-ros ros-${ROS_DISTRO}-xacro python-is-python3 python3-scipy \
	 ros-${ROS_DISTRO}-ros-control ros-${ROS_DISTRO}-gazebo-ros-control python3-move-base-msgs ros-${ROS_DISTRO}-rviz \
	 ros-${ROS_DISTRO}-joint-state-controller ros-${ROS_DISTRO}-qt-gui ros-${ROS_DISTRO}-rqt-gui ros-${ROS_DISTRO}-rqt-gui-py \
	 ros-${ROS_DISTRO}-roslint robotpkg-humanoid-nav-msgs libtf-conversions-dev libimage-geometry-dev ros-${ROS_DISTRO}-industrial-robot-status-interface \
	 ros-${ROS_DISTRO}-scaled-joint-trajectory-controller ros-${ROS_DISTRO}-speed-scaling-interface ros-${ROS_DISTRO}-speed-scaling-state-controller \
	 ros-${ROS_DISTRO}-ur-msgs ros-${ROS_DISTRO}-pass-through-controllers libzbar-dev ros-noetic-librealsense2 ros-noetic-realsense2-camera \
	 ros-noetic-realsense2-description mesa-utils net-tools novnc terminator firefox x11-apps tigervnc-standalone-server tigervnc-xorg-extension xfce4 iproute2

# Package installation
ReactSetup