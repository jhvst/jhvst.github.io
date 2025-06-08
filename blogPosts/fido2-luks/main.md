# Multi-token FIDO2 LUKS

_What happens to your data if your computer gets lost or stolen?_

It is a trick question -- you do not need to worry *unless* you run Linux.
This guide shows how to make a LUKS partition that supports multiple FIDO2 keys.
I use (and the company I run insists) the use of [Yubico](https://www.yubico.com/) YubiKeys with PIN codes for SSH access, but the devices are general enough to also encrypt disks.

## The disk setup

Linux comes with various ways to arrange disks.
[Arch Linux documentation on dm-crypt](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Overview) lists options relevant to Linux Unified Key Setup (LUKS).
The ones I would recommend is to install LUKS onto a disk partition or combine it with Logical Volume Manager (LVM).
As such, the options would be:

1. LUKS on a partition
2. LVM on LUKS
3. LUKS on LVM

The first option is the simplest.
LVM setups only make sense if you need the flexibility that LVM provides.
But for personal devices, it is rather unlikely you benefit from LVM that much.
And if you are like me, who already has unencrypted partitions on the same disk, the partitioning makes even more sense.
One may ask, *what such unencrypted partition might be?*
For most people it is the bootloader, which often must reside in a dumbed-down EFI-readable partition.
I use [rEFInd](https://www.rodsbooks.com/refind/linux.html) as my bootloader, so I fall into this category by choice.

Once you have done overthinking about the two other options, you continue with the first.
My LUKS partition will happen to be `sda3`, because `sda1` is for EFI, and `sda2` is my unencrypted `btrfs` filesystem.
The song for this sprog begins with:

```bash
sudo cryptsetup -v luksFormat /dev/sda3
```

This will prompt for a passphrase.
Choose something you can remember for around 10 minutes.
We are going to delete this password later, so no need to get fancy here.

You can now open it:

```bash
sudo cryptsetup open /dev/sda3 luks
```

Here `luks` is a mapper key that will pop up on `lsblk` under the partition.
Next, choose your filesystem.
Nobody ever got fired for choosing `xfs`:

```bash
sudo mkfs.xfs /dev/mapper/luks
```

We can now mount it:

```bash
mkdir luks
sudo mount /dev/mapper/luks luks
```

Unmounting:

```bash
sudo umount luks
```

And closing:

```bash
sudo cryptsetup close luks
```

## Enrolling your FIDO2 token

I assume you have a FIDO2 token such as YubiKey setup.
I also assume you happen to be on a distro that uses systemd.

With one of the YubiKeys on your hand and *one* of them plugged into your computer, we enroll the first token.
We can check the YubiKey is initialized fine with:

```bash
sudo systemd-cryptenroll --fido2-device=list /dev/sda3
```

This might print something like:

```
PATH         MANUFACTURER PRODUCT               COMPATIBLE
/dev/hidraw2 Yubico       YubiKey OTP+FIDO+CCID ✓
```

Encouraged by the checkmark, we continue:

```bash
sudo systemd-cryptenroll --fido2-device=auto --fido2-with-client-pin=true /dev/sda3
```

First option picks the device for you, the second makes sure a PIN is always required.
PIN is useful if a crook steals *both* your computer and the YubiKey, because a simple tap on the YubiKey will not be enough to decrypt the partition.

The command above will prompt the password you gave earlier, so I hope you still remember it.
To "open" the crypted partition with FIDO:

```bash
sudo systemd-cryptsetup attach luks /dev/sda3
```

Notice how opening is now called attaching and the order of the arguments is flipped compared to `cryptsetup`.
Similarly, closing is now called detaching:

```bash
sudo systemd-cryptsetup detach luks
```

To induce further confusion, you can still print the partition state using `cryptsetup` which should now have `Tokens` with an index 0 pointing to keyslot 1:

```bash
sudo cryptsetup luksDump /dev/sda3
```

Keyslot 0 is the old password.
You can now un-plug the first YubiKey and plug-in the second one.
You may add a new YubiKey while deleting the initial password by running the following:

```bash
sudo systemd-cryptenroll --fido2-device=auto --fido2-with-client-pin=true --wipe-slot=0 /dev/sda3
```

You cannot enroll new FIDO2 tokens without a password seemingly because `systemd-cryptenroll` does not recognize more than a single token at a time.
If you want to enroll a new device, first re-set a plain password:

```bash
sudo systemd-cryptenroll --unlock-fido2-device=auto --password /dev/sda3
```

This will prompt a new password.
You can now enroll a new FIDO device e.g. by re-using the command above which wipes some slot while adding a new one.
To find the slot index of the plain password re-inspect the output of the `luksDump` command.

Your tinfoil hat is now more airtight.
You are still suspectible to wrench-attacks.

## Notes

- NixOS can prompt and attach your LUKS partition in initrd: [FDE using systemd-cryptenroll with fido2 key - Help - NixOS Discourse](https://discourse.nixos.org/t/fde-using-systemd-cryptenroll-with-fido2-key/47762/2)
- Setting the PIN on YubiKeys can be done with `ykman`: [FIDO Commands - ykman CLI and YubiKey Manager GUI Guide  documentation](https://docs.yubico.com/software/yubikey/tools/ykman/FIDO_Commands.html)
