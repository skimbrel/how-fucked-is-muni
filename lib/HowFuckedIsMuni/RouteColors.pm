package HowFuckedIsMuni::RouteColors;

use strict;
use warnings;

use CHI;
use Dancer ':syntax';
use HowFuckedIsMuni::RouteChecker;
use Moose;
use WWW::ProximoBus;

has 'cache' => (
    is => 'rw',
    default => sub {
        # Use a File cache here so we can share between processes
        # and persist across restarts. This is ugly to reload when we miss.
        my $cache = CHI->new(
            driver => 'Redis',
            server => config->{redis_server},
            global => 1
        );
        return $cache;
    },
);
has 'proximobus' => (
    is => 'rw',
    default => sub {
        my $proximo = WWW::ProximoBus->new();
        return $proximo;
    },
);

sub cache_key {
    my ($agency) = @_;
    return "route-colors:$agency";
}

sub get_colors_for_route {
    my $self = shift;
    my ($agency, $route) = @_;

    my $key = cache_key($agency);
    my $map = $self->cache->get($key);
    unless ($map) {
        $map = $self->_load_colors($agency);
    }

    return $map->{$route};
}

sub foreground {
    my $self = shift;
    my ($agency, $route) = @_;

    my $colors = $self->get_colors_for_route($agency, $route);
    return $colors->{fg};
}

sub background {
    my $self = shift;
    my ($agency, $route) = @_;

    my $colors = $self->get_colors_for_route($agency, $route);
    return $colors->{bg};
}

sub _load_colors {
    my $self = shift;
    my ($agency) = @_;

    my $key = cache_key($agency);
    my $map = $self->cache->get($key) || {};
    if (keys %$map) {
        debug "loaded route colors from cache";
        return $map;
    }
    try {
        my $routes = $self->proximobus->routes($agency);
        for my $r (@{$routes->{items}}) {
            my $id = $r->{id};
            debug "loading colors for $id";
            my $route = $self->proximobus->route($agency, $id);
            $map->{$id} = {
                fg => $route->{fg_color},
                bg => $route->{bg_color},
            };
        }
        my $key = cache_key($agency);
        $self->cache->set($key, $map, "1 week");
        return $map;
    }
    catch {
        die "Couldn't load route colors: $_";
    };
}

"double rainbow oh my god";
