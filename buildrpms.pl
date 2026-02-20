#!/usr/bin/perl

use strict;
use warnings;

use feature 'say';

sub install_deps {
    system(<<"EOF");
    set -x
    source /etc/os-release
    case "\$ID" in
        rhel)
            subscription-manager repos --enable codeready-builder-for-rhel-10-\$(arch)-rpms
            ;;
        *)
            dnf config-manager --set-enabled crb
            ;;
    esac
    dnf install -y perl-generators https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
    dnf install -y \$(/usr/lib/rpm/perl.req $0)
    dnf install -y tar mock nginx createrepo podman rpmdevtools

    rpmdev-setuptree
EOF
    $? >> 8;
}

BEGIN {

    exit(install_deps())
        if grep { "--install_deps" eq $_ } @ARGV;
}

use Carp;
use Cwd qw();
use Data::Dumper;
use File::Copy qw(cp);
use File::Path qw(make_path);
use File::Slurper qw(read_text write_text);
use FindBin qw($Bin);
use Getopt::Long qw(GetOptions);
use Parallel::ForkManager;

use autodie;
use autodie qw(cp);

my $SOURCES = "$ENV{HOME}/rpmbuild/SOURCES";
my $VERSION = read_text("Version");
my $RELEASE = read_text("Release");
my $GITINFO = read_text("Gitinfo");
my $PWD = Cwd::cwd();

chomp($VERSION);
chomp($RELEASE);
chomp($GITINFO);


my @PACKAGES = qw(
    perl-xCAT
    xCAT
    xCAT-buildkit
    xCAT-client
    xCAT-confluent
    xCAT-genesis-base
    xCAT-genesis-scripts
    xCAT-openbmc-py
    xCAT-probe
    xCAT-rmc
    xCAT-server
    xCAT-test
    xCAT-vlan
);

my @TARGETS = qw(
    rhel+epel-8-x86_64
    rhel+epel-9-x86_64
    rhel+epel-10-x86_64);


my %opts = (
    configure_nginx => 0,
    force => 0,
    help => 0,
    nginx_port => 8080,
    nproc => int(`nproc --all`),
    packages => \@PACKAGES,
    targets => \@TARGETS,
    verbose => 0,
    setup_vhpc_repo => 0,
    xcat_dep_path => "$PWD/../xcat-dep/",
);

GetOptions(
    "configure_nginx" => \$opts{configure_nginx},
    "force" => \$opts{force},
    "help" => \$opts{help},
    "nginx_port" => \$opts{nginx_port},
    "nproc=i" => \$opts{nproc},
    "package=s@" => \$opts{packages},
    "target=s@" => \$opts{targets},
    "verbose" => \$opts{verbose},
    "xcat_dep_path=s" => \$opts{xcat_dep_path},
    "setup_vhpc_repo" => \$opts{setup_vhpc_repo},
) or usage();

sub sh {
    my ($cmd) = @_;
    say "Running: $cmd"
        if $opts{verbose};
    system($cmd);
    $? >> 8;
}

# sed { s/foo/bar/ } $filepath applies s/foo/bar/ to the file at $filepath
sub sed (&$) {
    my ($block, $path) = @_;
    my $content = read_text($path);
    local $_ = $content;
    $block->();
    $content = $_;
    write_text($path, $content);
}

sub is_in {
    my $needle = shift;
    for (@_) {
        return 1 if $_ eq $needle;
    }
    0;
}

# product(\@A, \@B) returns the catersian product of \@A and \@B
sub product {
    my ($a, $b) = @_;
    return map {
        my $x = $_;
        map [ $x, $_ ], @$b;
    } @$a
}

sub setup_vhpc_repo {
    write_text("/etc/yum.repos.d/VersatusHPC.repo", <<'EOF');
[VersatusHPC]
name=VersatusHPC
baseurl=https://mirror.versatushpc.com.br/versatushpc/rpm/el10/
gpgcheck=0
EOF
    system("dnf makecache --repoid=VersatusHPC");
    $? >> 0;
}

sub createmockconfig {
    my ($pkg, $target) = @_;
    my $chroot = "$pkg-$target";
    my $cfgfile = "/etc/mock/$chroot.cfg";
    return if -f $cfgfile && ! $opts{force};
    cp "/etc/mock/$target.cfg", $cfgfile;
    my $contents = read_text($cfgfile);
    $contents =~ s/config_opts\['root'\]\s+=.*/config_opts['root'] = \"$chroot\"/;
    if ($pkg eq "perl-xCAT") {
        # perl-generators is required for having perl(xCAT::...) symbols
        # exported by the RPM
        $contents .= "config_opts['chroot_additional_packages'] = 'perl-generators'\n";
    }
    write_text($cfgfile, $contents);
}

sub buildsources_genesis_base() {
    die "Assertion failed! No directory xCAT-genesis-builder in the current directory"
        unless -d "./xCAT-genesis-builder";

    my @deps = qw(
        bind-utils
        dosfstools
        ethtool
        ipmitool
        kexec-tools
        lldpad
        mdadm
        mstflint
        nmap-ncat
        net-tools
        pciutils
        psmisc
        rpm-build
        rpmdevtools
        screen
        usbutils

        nfs-utils rpcbind
        dhclient
    );
    sh("dnf install -y " . join " ", @deps)
        and die "Error installing packages $?";


    my $dracutmoddir = "/usr/lib/dracut/modules.d/97xcat/";

    my $buildarch = `uname -m`;
    my $kernelversion = `uname -r`;
    chomp $buildarch;
    chomp $kernelversion;

    my $genesispath = "/tmp/xcatgenesis.$$";
    my $buildpath = "$genesispath/opt/xcat/share/xcat/netboot/genesis/$buildarch";

    make_path $dracutmoddir;
    make_path "$buildpath/fs/etc/ssh/";

    my @files = map { "$Bin/xCAT-genesis-builder/dracut_105/el/$_" }
        qw(
            module-setup.sh
            xcat-cmdline.sh
            xcatroot
            dhclient.conf
            dhclient-script
            rsyslog.conf
        );
    # copy @files to $dracutmoddir
    cp $_, $dracutmoddir for @files;

    # The dependents of these must be updated
    # * netstat
    # * /sbin/route
    # * /sbin/ifconfig -> net-tool
    # * nslookup



    my $opts = $opts{verbose} ? "set -x" : "";
    sh(<<"EOF");
$opts
dracut --compress gzip -m "xcat base" --no-early-microcode -N -f $genesispath.rfs;
rm -rf $buildpath/fs || :
mkdir -p $buildpath/fs || :
cd $buildpath/fs
zcat $genesispath.rfs | cpio -dumi
EOF

    my @perl_lib_dir = qw(
        /usr/share/perl5
        /usr/lib64/perl5
        /usr/local/lib64/perl5
        /usr/local/share/perl5
        /usr/share/ntp/lib
    );

    for my $d (@perl_lib_dir) {
        next unless -d $d;
        my $temp_dir = "$buildpath/fs/$d";
        make_path $temp_dir;
        # cp function does not copy directories recursively
        `cp -a -t $temp_dir $d/.`;
    }

    make_path "$buildpath/fs/lib/udev/rules.d/";
    my $oldcwd = Cwd::cwd();
    my $lib_udev_rules="/lib/udev/rules.d/";
    cp "$lib_udev_rules/80-net-name-slot.rules", "$buildpath/fs/lib/udev/rules.d/"
        if -e "$lib_udev_rules/80-net-name-slot.rules";

    make_path("$buildpath/kernel/");
    cp "/boot/vmlinuz-$kernelversion", "$buildpath/kernel/";

    # Create the targz
    #
    # Note:
    #
    #   Deletes character devices from the genesis-base
    #   image filesystem prior to tarball creation. The installation
    #   of the package fails in vanilla containers with "Operation not
    #   permited" during the creation of
    #
    #       /opt/xcat/../genesis/../fs/dev/{console,random,...}
    #
    #   otherwise.
    sh(<<"EOF")
cd $genesispath
find . -type c -delete
tar jcf $SOURCES/xCAT-genesis-base-$buildarch.tar.bz2 opt
EOF
}

sub buildsources {
    my ($pkg, $target) = @_;

    if ($pkg eq "xCAT") {
        my @files = ("bmcsetup", "getipmi");
        for my $f (@files) {
            cp "xCAT-genesis-scripts/usr/bin/$f", "$pkg/postscripts/$f";
            sed { s/xcat.genesis.$f/$f/ } "${pkg}/postscripts/$f";
        }
        sh(<<"EOF");
          cd xCAT
          tar --exclude upflag -czf $SOURCES/postscripts.tar.gz  postscripts LICENSE.html
          tar -czf $SOURCES/prescripts.tar.gz  prescripts
          tar -czf $SOURCES/templates.tar.gz templates
          tar -czf $SOURCES/winpostscripts.tar.gz winpostscripts
          tar -czf $SOURCES/etc.tar.gz etc
          cp xcat.conf $SOURCES
          cp xcat.conf.apach24 $SOURCES
          cp xCATMN $SOURCES
EOF
    } elsif ($pkg eq "xCAT-genesis-scripts") {
      sh qq(tar -cjf "$SOURCES/$pkg.tar.bz2" $pkg);
    } elsif ($pkg eq "xCAT-genesis-base") {
        buildsources_genesis_base();
    } else {
      sh qq(tar -czf "$SOURCES/$pkg-$VERSION.tar.gz" $pkg);
    }
}

sub buildspkgs {
    my ($pkg, $target) = @_;

    my $chroot = "$pkg-$target";

    my $diskcache = "dist/$target/srpms/$pkg-$VERSION-$RELEASE.src.rpm";
    return if -f $diskcache and not $opts{force};

    my $dir = sub {
        return "xCAT-genesis-builder"
            if $pkg eq "xCAT-genesis-base";
        $pkg;
    }->();

    my @opts;
    push @opts, "--quiet" unless $opts{verbose};

    say "Building $diskcache";

    sh(<<"EOF");
mock -r $chroot \\
    -N \\
    @{[ join "  ", @opts ]} \\
    --define "version $VERSION" \\
    --define "release $RELEASE" \\
    --define "gitinfo $GITINFO" \\
    --buildsrpm \\
    --spec $dir/$pkg.spec \\
    --sources $SOURCES \\
    --resultdir "dist/$target/srpms/"
EOF
}

sub buildpkgs {
    my ($pkg, $target) = @_;
    my $optsref = \%opts;
    my $chroot = "$pkg-$target";

    my @native_pkgs = qw(
        xCAT
        xCAT-genesis-scripts
    );

    # get x86_64 from rhel+epel-9-x86_64
    my $targetarch = (split /-/, $target, 3)[2];

    # get the builder arch, xCAT-genesis-base include it in its package name
    my $nativearch = `uname -m`;
    chomp $nativearch;
    $nativearch = "ppc64" if $nativearch =~ /^ppc/;
    my $arch = is_in($pkg, @native_pkgs) ? $targetarch : "noarch";

    my $diskcache = "dist/$target/rpms/$pkg-$VERSION-$RELEASE.$arch.rpm";
    return if -f $diskcache and not $opts{force};

    my @opts;
    push @opts, "--quiet" unless $opts{verbose};

    my $spkgname = sub {
        return "${pkg}-${arch}-${VERSION}-${RELEASE}.src.rpm"
            if $pkg eq 'xCAT-genesis-scripts';
        return "xCAT-genesis-base-${nativearch}-${VERSION}-${RELEASE}.src.rpm"
            if $pkg eq 'xCAT-genesis-base';

        return "$pkg-${VERSION}-${RELEASE}.src.rpm";
    }->();

    say "Building $pkg $diskcache";

    sh(<<"EOF");
mock -r $chroot \\
    -N \\
    @{[ join "  ", @opts ]} \\
    --define "version $VERSION" \\
    --define "release $RELEASE" \\
    --define "gitinfo $GITINFO" \\
    --resultdir "dist/$target/rpms/" \\
    --rebuild dist/$target/srpms/$spkgname
EOF
}

sub buildall {
    my ($pkg, $target) = @_;
    createmockconfig($pkg, $target);
    buildsources($pkg, $target);
    buildspkgs($pkg, $target);
    buildpkgs($pkg, $target);
}

sub configure_nginx {
    my $xcat_dep_path = $opts{xcat_dep_path};
    my $port = $opts{nginx_port};
    my $conf = <<"EOF";
server {
    listen $port;
    listen [::]:$port;
EOF

    # We always generate the nginx config for all
    # the targets, not $opts{targets}
    for my $target (@TARGETS) {
        my $fullpath = "$PWD/dist/$target/rpms";
        $conf .= <<"EOF";
    location /$target/ {
        alias $fullpath/;
        autoindex on;
        index off;
        allow all;
    }
EOF
    }
    # TODO:I need one xcat-dep for each target
    $conf .= <<"EOF";
    location /xcat-dep/ {
        alias $xcat_dep_path;
        autoindex on;
        index off;
        allow all;
    }
}
EOF
    write_text("/etc/nginx/conf.d/xcat-repos.conf", $conf);
    `systemctl restart nginx`;
    $? >> 8;
}

sub update_repo {
    my ($target) = @_;
    say "Creating repository dist/$target/rpms";
    `find dist/$target/rpms -name ".src.rpm" -delete`;
    `createrepo --update dist/$target/rpms`;
}


sub usage {
    my ($errmsg) = @_;
    say STDERR "Usage: $0 [--package=<pkg1>] [--target=<tgt1>] [--package=<pgk2>] [--target=<tgt2>] ...";
    say STDERR "";
    say STDERR "  RPM builder script";
    say STDERR "     .. build xCAT RPMs for these targets:";
    say STDERR map { "     $_\n" } @TARGETS;
    say STDERR "";
    say STDERR " Options:";
    say STDERR "";
    say STDERR "  --target <tgt> .................. build only these targets";
    say STDERR "  --package <pkg> ................. build only these packages";
    say STDERR "  --force ......................... override built RPMS";
    say STDERR "  --configure_nginx ............... update nginx configuration";
    say STDERR "  --nginx_port=8080 ............... change the nginx port in";
    say STDERR "                                 (use with --configure_nginx)";
    say STDERR "  --nproc <N> ..................... run up to N jobs in parallel";
    say STDERR "  --xcat_dep_path=../xcat-dep ..... path to xcat-dep repositories";
    say STDERR "";
    say STDERR " If no --target or --package is given all combinations are built";
    say STDERR "";
    say STDERR " See test/README.md for more information";

    say STDERR $errmsg if $errmsg;
    exit -1;
}

sub main {
    return usage() if $opts{help};
    return exit(configure_nginx()) if $opts{configure_nginx};
    return exit(setup_vhpc_repo()) if $opts{setup_vhpc_repo};

    my @rpms = product($opts{packages}, $opts{targets});
    my $pm = Parallel::ForkManager->new($opts{nproc});

    for my $pair (@rpms) {
        my ($pkg, $target) = $pair->@*;
        $pm->start and next;

        buildall($pkg, $target);

        $pm->finish;
    }

    $pm->wait_all_children;

    for my $target ($opts{targets}->@*) {
        $pm->start and next;

        update_repo($target);

        $pm->finish;
    }
    $pm->wait_all_children;

    configure_nginx();

}

main();

__END__;

=head1 SYNOPSIS

Build all xCAT RPM packages in parallel using mock for isolation

=head1 KNOWN ERRORS

=over 4

    1. Error    : GPG error during mock cache creation/update
       Cause    : Out-dated distribution-gpg-keys in host machine
       Solution : Run `dnf update -y distribution-gpg-keys` in the host.
=back
