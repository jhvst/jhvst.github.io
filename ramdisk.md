
# RAMsteam

1. From BIOS enable network booting, usually some weird on-board LAN setting which has to be enabled, then the BIOS settings applied --> reboot, then back to BIOS, then boot options, then PXE over IPV4 should appear.

2. Make a USB stick which has netboot.xyz on it, or configure your DHCP server to pass out boot options to TFTP server which has `.ipxe` file.

3. From the iPXE menu, select the shell option. Type in `chain -a http://boot.ponkila.com/menu.ipxe`. Then, select option `u-root`. Then, from `u-root` prompt write `dhclient -ipv4`. Wait a long time or Ctrl+D when you get an IP from DHCP server (this assumes you have a DHCP server).

4. Type `wget http://boot.ponkila.com/initrd` and then `wget http://boot.ponkila.com/phasedKernel`. Then, `wget http://boot.ponkila.com/netboot.ipxe`. Then, `cat netboot.ipxe`. This will show the path of the `init` process, which is prefixed as `init=/nix/store/...`. You will have to manually write this long hash into the next command: `kexec --load phasedKernel --initrd=initrd -c "boot.shell_on_fail nvidia-drm.modeset=1 init=/nix/store/..."`. Then, `kexec -e`.

5. You will boot to crashed NixOS, press `f` for PID1 emergency shell. Write `ip a` to see your network interfaces. One of them shows the Ethernet interface, usually something like `enp5s0` or similar. Next, configure your IP manually. Suppose your DHCP server is `192.168.1.1` (you have to figure this out on your own). Write `ip addr a 192.168.1.100/24 dev enp5s0` (e.g., any available IP in your DHCP range), then `ip link set enp5s0 up`. Then, `ip r add default via 192.168.1.1 dev enp5s0`. Then, `vi /etc/resolv.conf` and write `nameserver 1.1.1.1`. Check that `ping 1.1.1.1` and `ping google.com` works.

6. Now, `wget http://boot.ponkila.com/squashfs.img`. Then, remove the previous squashfs image in your `/` folder: `rm nix-store.squashfs`. Then, `mv squasfs.img nix-store.squashfs`.

7. Write `./init`. This will give you prompt you to `switch_root`. Type: `switch_root /mnt-root /nix/store/.../init` Tip: you can autocomplete the `init` now by the following: start writing `/mnt-root/nix/store/` and then add the first few characters from the `init` hash. Then, you have to go back in the buffer, then remove the `/mnt-root` prefix. Once your buffer looks like `switch_root /mnt-root /nix/store/.../init`, you can press Enter. The system will boot to stage 2 and then to final environment. Commands like `sway` and `steam` should now be present, or with a hint of luck, even work properly.

It's also possible to replace the step `7.` by manually formatting the filesystem. This probably does not work on NixOS, so this is for documentation only:

1. The ramdisk filesystem is declared [in this file](https://github.com/jhvst/nix-config/blob/main/system/ramdisk.nix). With this file as reference, proceed to format the filesystem manually:

2. First, the `/` path: `mkdir /mnt-root`. Then, `mount -t tmpfs none /mnt-root -o mode=0755`.

3. Then, `mkdir -p /mnt-root/nix/.ro-store`. Then, `losetup squashfs.img`. This will print the loopdevice to which it was attached, such as `/dev/loop0`. Then, use this here: `mount /dev/loop0 /mnt-root/nix/.ro-store`.

4. Then, `mkdir -p /mnt-root/nix/.rw-store`. Then, `mount -t tmpfs none /mnt-root/nix/.rw-store -o mode=0755`.

5. Then, `mkdir -p /mnt-root/nix/store`. Then, `mkdir /mnt-root/nix/.rw-store/{store,work}` Then, `mount -t overlay -o lowerdir=/mnt-root/nix/.ro-store,upperdir=/mnt-root/nix/.rw-store/store,workdir=/mnt-root/nix/.rw-store/work overlay /mnt-root/nix/store`.

6. Then, `switch_root /mnt-root /nix/store.../init`. The system will try to switch root, but probably fail, unless the host OS happened to have `systemd`. Nevertheless, this shows how the filesystem is prepared.

7. Tell your friends you know how Linux initialization process works?

## Takeaways

This explains more or less how Linux boots. First, you have your kernel, which for us was named `phasedKernel`. In this file, you will have your drivers and whatnot features enabled. For example, if you don't have Ethernet drivers embedded in your kernel (either as a module or as a yes option), you would not see your interfaces when running `ip a`. Similarly, you wouldn't have loopdevices unless you have that feature as well. Same goes for any filesystem (tmpfs, squashfs, overlayfs) that we used. Gentoo is quite big on making these bespoke kernels -- the smaller the kernel, the faster the boot time, but more chances that something is _really_ slow, or just outright broken.

On the other hand, the `initrd` is the initial ramdisk (or initial RAM file system -- initramfs, as the name suggests) which is what you get when you crash into these bare-bones environments. These are where the userspace tools like `ip` and `mount` live. Unless these would be located in your `/bin` folder, you could not do much. These usually come from some project, such as `u-root`, or `BusyBox`. These binaries usually have less features than the ones you find from "full desktop" environments, mostly to save space and for compatibility, but more-so to make your question whether the bugs you might run into in `inird` are caused by those space-saving trade-offs rather than user errors. Jokes aside, these tools exist solely to make it possible to eventually reach the same conclusion, which is to pivot, or `switch_root`. Reaching this step might require decryption of file-systems, but for us, it's mostly about network configuration. Note: the `switch_root` resembles what `chroot` does, and by that extend, containers. Again, Gentoo wiki has more on this.

