#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

my $pre_path = defined $ENV{XCATROOT} ? "$ENV{XCATROOT}/share/xcat/install/scripts/pre.ubuntu.subiquity" : '';
$pre_path = "xCAT-server/share/xcat/install/scripts/pre.ubuntu.subiquity"
    unless -f $pre_path;

plan skip_all => "pre.ubuntu.subiquity not found" unless -f $pre_path;

my $script = do { local $/; open my $fh, '<', $pre_path or die $!; <$fh> };

# Shell syntax check
my $rc = system("bash -n $pre_path 2>/dev/null");
is($rc, 0, 'pre.ubuntu.subiquity passes bash -n syntax check');

# UEFI storage layout checks
like($script, qr/if \[ -d \/sys\/firmware\/efi \]/, 'script detects UEFI via /sys/firmware/efi');

# UEFI: grub_device on EFI partition, NOT on disk
like($script, qr/id: efi-part.*grub_device: true/s, 'UEFI: grub_device on EFI partition');

# UEFI: EFI partition formatted as fat32
like($script, qr/id: efi-part-fs.*fstype: fat32/s, 'UEFI: EFI partition formatted fat32');

# UEFI: EFI partition mounted at /boot/efi
like($script, qr/efi-part-mount.*path: \/boot\/efi/s, 'UEFI: EFI partition mounted at /boot/efi');

# BIOS storage layout checks
like($script, qr/id: bios-grub.*flag: bios_grub/s, 'BIOS: has bios_grub partition');
like($script, qr/id: disk-detected.*grub_device: true/s, 'BIOS: grub_device on disk');

# Both paths must have storage: version: 1
my @storage_version = ($script =~ /storage:\s*\n\s*version:\s*1/g);
is(scalar @storage_version, 2, 'both UEFI and BIOS have storage: version: 1');

# Both paths write to /tmp/partitionfile
my @partfile = ($script =~ /\/tmp\/partitionfile/g);
cmp_ok(scalar @partfile, '>=', 2, 'both paths write to /tmp/partitionfile');

# Storage at column 0 (for re-serialized autoinstall.yaml)
like($script, qr/^storage:\n  version: 1/m, 'storage block starts at column 0');

done_testing();
