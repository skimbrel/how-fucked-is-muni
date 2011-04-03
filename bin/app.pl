#!/usr/bin/env perl
use Dancer;
use HowFuckedIsMuni;
use HowFuckedIsMuni::RouteColors;
my $colors = HowFuckedIsMuni::RouteColors->new();
$colors->_load_colors(config->{agency});
dance;
