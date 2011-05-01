#!/usr/bin/env perl

use strict;
use warnings;

use Cwd qw( realpath );
use Dancer ':syntax';
use FindBin;

use lib "$FindBin::Bin/../lib";
use HowFuckedIsMuni::BackgroundDriver;

my $environment = shift || 'development';

my $appdir = realpath("$FindBin::Bin/..");

Dancer::Config::setting('appdir', $appdir);
Dancer::Config::load();
config->{environment} = $environment;

my $agency = config->{agency};
my $period = config->{refresh_period};
die "bad configuration!"
    unless (defined $agency && defined $period);

print STDERR "loaded config, entering run loop\n";

while (1) {
    HowFuckedIsMuni::BackgroundDriver->refresh($agency);
    sleep $period;
}
