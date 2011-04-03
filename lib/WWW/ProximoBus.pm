package WWW::ProximoBus;

use strict;
use warnings;

use JSON;
use LWP::UserAgent;
use Moose;
use Try::Tiny;

=head1 NAME

WWW::ProximoBus - A simple client library for the ProximoBus API.

=head1 SYNOPSIS

my $proximo = WWW::ProximoBus->new();
my $agencies = $proximo->agencies();
my $agency = $agencies->{items}[0];
my $routes = $proximo->routes($agency->{id});
for my $route (@{$routes->{items}}) {
    print $route->{id};
}

=head1 DESCRIPTION

WWW::ProximoBus is a Perl library implementing an interface to the ProximoBus API.

ProximoBus is a simple alternative API for NextBus' publicly-available data.

=cut

has 'api_host' => ( is => 'rw', default => 'proximobus.appspot.com' );

has 'ua' => (
    is     => 'rw',
    isa    => 'LWP::UserAgent',

    default => sub {
        my $ua = LWP::UserAgent->new;
        $ua->max_redirect( 0 );
        $ua->timeout( 5 );
        return $ua;
    },
    trigger => sub {
        my ($self, $ua, $attr) = @_;
        $ua->timeout( 5 );
        $ua->max_redirect( 0 );
    },
);

sub uri_for {
    my $self = shift;
    my ($path) = @_;

    $path = '/' . $path unless $path =~ m!^/!;
    return 'http://' . $self->api_host . $path;
}

sub get {
    my $self = shift;
    my ($path) = @_;

    my $uri = $self->uri_for($path);
    my $res = $self->ua->get($uri);
    if ($res->is_success) {
        return JSON::decode_json($res->content);
    }
    else {
        die "HTTP error " . $res->code . ": " . $res->content;
    }
}

sub agencies {
    my $self = shift;
    my $path = "/agencies.json";
    return $self->get($path);
}

sub agency {
    my $self = shift;
    my ($agency) = @_;
    my $path = "/agencies/$agency.json";
    return $self->get($path);
}

sub routes {
    my $self = shift;
    my ($agency) = @_;
    my $path = "/agencies/$agency/routes.json";
    return $self->get($path);
}

sub route {
    my $self = shift;
    my ($agency, $route) = @_;
    my $path = "/agencies/$agency/routes/$route.json";
    return $self->get($path);
}

sub stops_for_route {
    my $self = shift;
    my ($agency, $route) = @_;
    my $path = "/agencies/$agency/routes/$route/stops.json";
    return $self->get($path);
}

sub runs {
    my $self = shift;
    my ($agency, $route) = @_;

    my $path = "/agencies/$agency/routes/$route/runs.json";
    return $self->get($path);
}

sub run {
    my $self = shift;
    my ($agency, $route, $run) = @_;
    my $path = "/agencies/$agency/routes/$route/runs/$run.json";
    return $self->get($path);
}

sub stops_for_run {
    my $self = shift;
    my ($agency, $route, $run) = @_;
    my $path = "/agencies/$agency/routes/$route/runs/$run/stops.json";
    return $self->get($path);
}

sub vehicles_for_route {
    my $self = shift;
    my ($agency, $route) = @_;
    my $path = "/agencies/$agency/routes/$route/vehicles.json";
    return $self->get($path);
}

sub stop {
    my $self = shift;
    my ($agency, $stop) = @_;
    my $path = "/agencies/$agency/stops/$stop.json";
    return $self->get($path);
}

sub routes_for_stop {
    my $self = shift;
    my ($agency, $stop) = @_;
    my $path = "/agencies/$agency/stops/$stop/routes.json";
    return $self->get($path);
}

sub predictions_for_stop {
    my $self = shift;
    my ($agency, $stop) = @_;
    my $path = "/agencies/$agency/stops/$stop/predictions.json";
    return $self->get($path);
}

sub predictions_for_stop_by_route {
    my $self = shift;
    my ($agency, $stop, $route) = @_;
    my $path = "/agencies/$agency/stops/$stop/predictions/by-route/$route.json";
    return $self->get($path);
}

sub vehicles {
    my $self = shift;
    my ($agency) = @_;
    my $path = "/agencies/$agency/vehicles.json";
    return $self->get($path);
}

sub vehicle {
    my $self = shift;
    my ($agency, $vehicle) = @_;
    my $path = "/agencies/$agency/vehicles/$vehicle.json";
    return $self->get($path);
}

"The next inbound train is going out of service. Do not board.";







