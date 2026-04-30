#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use File::Spec;
use Test::More;

my $repo_root = File::Spec->catdir( $FindBin::Bin, '..', '..' );
my %scripts = (
    'legacy install post.xcat' => File::Spec->catfile(
        $repo_root,
        'xCAT-server/share/xcat/install/scripts/post.xcat'
    ),
    'legacy netboot xcatdsklspost' => File::Spec->catfile(
        $repo_root,
        'xCAT/postscripts/xcatdsklspost'
    ),
);

foreach my $path ( values %scripts ) {
    plan skip_all => "$path not found" unless -r $path;
}

foreach my $name ( sort keys %scripts ) {
    my $path = $scripts{$name};
    open( my $fh, '<', $path ) or die "Unable to read $path: $!";
    my $script = do { local $/; <$fh> };
    close($fh);

    like(
        $script,
        qr/--reject\s+"index\.html\*,post\.xcat\.ng,post\.xcat\.rhels10"/,
        "$name recursive wget ignores dispatcher scripts that contain literal HTML-link regexes"
    );
    like(
        $script,
        qr/Newer\s+(?:#\s+)?wget\s+parses\s+HTML-looking\s+regex\s+strings/s,
        "$name download policy documents why dispatcher scripts are excluded"
    );
    unlike(
        $script,
        qr/<a\s+href=/i,
        "$name comments do not contain HTML links that wget can recurse into"
    );
}

done_testing();
