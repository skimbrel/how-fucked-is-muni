package HowFuckedIsMuni;
use Dancer ':syntax';
use HowFuckedIsMuni::RouteChecker;
use Try::Tiny;

our $VERSION = '0.1';

get '/' => sub {
    try {
        my $checker = HowFuckedIsMuni::RouteChecker->instance();
        my $colors = HowFuckedIsMuni::RouteColors->new();
        my $routes = $checker->check_all_routes(config->{agency});
        my $names = $checker->get_sorted_names(config->{agency});
        template 'index', { agency => config->{agency}, names => $names, routes => $routes, colors => $colors };
    }
    catch {
        error "Error loading all routes: $_";
        status 500;
        return "Sorry, but we seem to be fucked ourselves.";
    };
};

get '/:name' => sub {
    my $name = uc params->{name};
    try {
        my $checker = HowFuckedIsMuni::RouteChecker->instance();
        my $colors = HowFuckedIsMuni::RouteColors->new();
        my $routes = $checker->get_routes(config->{agency});
        unless ($routes->{$name}) {
            status '404';
            return "Route $name is so fucked it doesn't even exist.";
        }
        my $status = $checker->check_route(config->{agency}, $name);
        template 'status.tt', { agency => config->{agency}, name => $name, status => $status, colors => $colors };
    }
    catch {
        error "Error looking up $name: $_";
        status 500;
        return "Sorry, but we seem to be fucked ourselves.";
    };
};

true;
