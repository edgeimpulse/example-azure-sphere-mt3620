# Edge Impulse example on Azure Sphere MT3620

## Prerequisites

You'll need:

* [Azure Sphere MT3620 Starter Kit](https://www.avnet.com/shop/us/products/avid-technologies/aes-ms-mt3620-sk-g-3074457345636825680/).
* [SparkFun FTDI Basic Breakout board](https://www.sparkfun.com/products/9873) (3.3V) or an FTDI cable to see logs from the realtime cores. Hook TX on the mikrobus 2 slot up to RX on the SparkFun board, and GND to GND. The board is logging information on baud rate 115,200.

You'll also need:

* [Docker desktop](https://www.docker.com/products/docker-desktop) - to build the firmware.
* A Windows 10 VM with the Azure SDK installed. I couldn't get this to work on Linux (let alone macOS). Make sure `azsphere` is in your PATH, and you've followed the steps to [claim your device](https://docs.microsoft.com/en-us/azure-sphere/install/claim-device) and to [enable development and debugging](https://docs.microsoft.com/en-us/azure-sphere/install/qs-real-time-application?tabs=windows&pivots=cli#enable-development-and-debugging).

## Building and flashing the example

1. Build the container with all dependencies:

    ```
    $ docker build -t azure-sphere .
    ```

1. Build the firmware:

    ```
    $ docker run --rm -it -v $PWD:/app azure-sphere /bin/bash /app/build/build.sh
    ```

1. Mount the `build` folder to your Windows 10 VM, open a command prompt and navigate to the `build` folder. Then run:

    ```
    $ flash.bat
    ```

1. You should now see data coming in from the FTDI Breakout board.
