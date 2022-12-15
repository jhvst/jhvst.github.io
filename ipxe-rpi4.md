# iPXE, NixOS, EDK2 UEFI BIOS, and Raspberry Pi 4

This is an excerpt from a reddit comment of mine in response to running NixOS with additional kernel modules on NixOS.

I use config in which the instrumental part is this:

```
boot.kernelPackages = pkgs.linuxPackages_rpi4;
boot.loader.raspberryPi = {
    enable = true;
    version = 4;
};
boot.loader.grub.enable = false;
```

This will create all the dtb (i.e., device-tree) modules for you. These are Raspberry Pi 4 firmware files which e.g. enable the software layer of RPi4 to work.

However, there is a blog post worthy alternative way to ensure the modules are loaded which have little to do with your OS config, which is to UEFI boot your Raspberry Pi. I don't have such blog post, and since my config currently works, my motivation to mechanize the process is not great. Nevertheless, the general idea is disposed below:

Enabling this boot process is very contrived: the RPi uses the GPU to boot up the device, which is different from a normal UEFI boot. However, there is a UEFI boot loader available. See this comment on Fedora issue of mine: https://discussion.fedoraproject.org/t/fedora-coreos-device-tree-and-aarch64/33434/4?u=juuso

So, this alternative method works by "fooling" the RPi to boot an OS, which is actually the UEFI BIOS, which is able to load the modules before Linux starts. I've enabled this with network booting, but I don't have mechanized build process for this either.

First, you need to enable network booting from the RPi firmware. This is enabled with this: https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#raspberry-pi-4-bootloader-configuration

Next, you need a folder structure which looks like this: https://github.com/jhvst/pipxe/tree/master/example/tftpboot

Here, you can now modify the config file to add the modules you want, which solves your problem... once you get to boot up a kernel:

You will need to have a DHCP server which has to be configured with ARM 64 bit file name option to point to the efi/boot/bootaa64.efi in the TFTP server alongside option called UEFI HTTPBoot URL which has to point to the RPI_EFI.d file from the ipxe project builds. Unfortunately, I have no idea how to apply the DHCP settings unless you happen to run pfSense, which has the option under DHCP server settings. If you manage to do this some other way, you can then add a file called autoexec.ipxe to the efi/boot folder. You can generate the autoexec.ipxe file by running the following script, for example: https://github.com/jhvst/nix-config/blob/main/minimal.nix (the command to run it is in the first line of the file).

This will generate a result folder with a ipxe script which has to be renamed to autoexec.ipxe and put into the TFTP server. You also must replace the paths in the script to correspond to either a HTTP or TFTP server where you have the Image and initrd files. If you somehow managed to do this without misconfiguration, then you would have a boot process which works as follows: the RPi boots into network boot mode and asks the DHCP server for instructions. The DHCP serves the UEFI BIOS alongside the firmware blobs in the config file. The UEFI BIOS continues to PXE boot, which loads the kernel and initrd over HTTP or TFTP. The OS boots with the firmware blobs loaded alongside the OS. Things work, and your whole OS is on your RPi RAM. Why to do this? In this scenario, you can have a PoE hat on your Pi, through which the Pi gets its power, networking, and the OS. "Cattle, not pets."
