FROM ubuntu:20.04

WORKDIR /app

RUN apt update && apt install -y net-tools curl cmake ninja-build gpg xz-utils python3 wget libgcc-s1 libcap2-bin

COPY ./install_azure_sphere_sdk.sh ./

RUN mkdir -p /etc/udev/rules.d/
RUN /bin/bash ./install_azure_sphere_sdk.sh

ENV AzureSphereDefaultSDKDir=/opt/azurespheresdk/

# Install GCC ARM
RUN cd .. && \
    wget https://developer.arm.com/-/media/Files/downloads/gnu-rm/9-2020q2/gcc-arm-none-eabi-9-2020-q2-update-x86_64-linux.tar.bz2 && \
    tar xjf gcc-arm-none-eabi-9-2020-q2-update-x86_64-linux.tar.bz2 && \
    echo "PATH=$PATH:/gcc-arm-none-eabi-9-2020-q2-update/bin" >> ~/.bashrc && \
    cd /app

ENV PATH="/gcc-arm-none-eabi-9-2020-q2-update/bin:${PATH}"
ENV ARM_GNU_PATH="/gcc-arm-none-eabi-9-2020-q2-update/"

# Install recent CMake
RUN mkdir -p /opt/cmake && \
    cd /opt/cmake && \
    wget https://github.com/Kitware/CMake/releases/download/v3.19.0-rc3/cmake-3.19.0-rc3-Linux-x86_64.sh && \
    sh cmake-3.19.0-rc3-Linux-x86_64.sh --prefix=/opt/cmake --skip-license && \
    ln -s /opt/cmake/bin/cmake /usr/local/bin/cmake

ENV PATH="${PATH}:/opt/azurespheresdk/Tools/"
