package HowFuckedIsMuni::BackgroundDriver;

use strict;
use warnings;

use Dancer ':syntax';
use HowFuckedIsMuni::RouteChecker;
use Try::Tiny;

sub refresh {
    my $class = shift;

    my $checker = HowFuckedIsMuni::RouteChecker->instance();
    my $agency = config->{agency};

    my $time = localtime;
    debug "Refreshing all $agency routes at $time";
    try {
        my $routes = $checker->get_routes($agency);
        for my $route (keys %$routes) {
            my $status = $checker->check_route($agency, $route); # Ensures cache is populated.
            my $out = sprintf "%s: %d", $route, $status->{is_fucked};
            debug $out;
        }
        my $finished = localtime;
        debug "Finished refresh at $time";
    }
    catch {
        error "Couldn't refresh $agency routes: $_";
    };
}

1;
