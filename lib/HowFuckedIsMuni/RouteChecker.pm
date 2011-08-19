package HowFuckedIsMuni::RouteChecker;

use strict;
use warnings;

use CHI;
use CHI::Driver::Redis;
use Dancer ':syntax';
use Moose;
use WWW::ProximoBus;

use constant FUCKED_THRESHOLD => 0.2;
use constant SMALL_THRESHOLD => 4.0;
use constant BIG_THRESHOLD => 17.0;
use constant GAP_FACTOR => 0.1;
use constant SHORT_EXPTIME => '5 minutes';
use constant LONG_EXPTIME => '1 day';

sub check_all_key {
    my $agency = shift;
    return "status-all:$agency";
}

sub routes_key {
    my $agency = shift;
    return "routes:$agency";
}

sub termini_key {
    my ($agency, $route) = @_;
    return "termini:$agency:$route";
}

sub runs_key {
    my ($agency, $route) = @_;
    return "runs:$agency:$route";
}

sub stops_key {
    my ($agency, $route, $run) = @_;
    return "stops:$agency:$route:$run";
}

sub fucked_key {
    my ($agency, $route) = @_;
    return "fucked:$agency:$route";
}

sub is_weekend {
    my ($time) = (localtime)[6];
    return ($time == 0 || $time == 6) ? 1 : 0;
}

has 'cache' => (
    is => 'rw',
    default => sub {
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

my $singleton;
sub instance {
    my $class = shift;
    unless (defined $singleton) {
        $singleton = $class->new();
    }
    return $singleton;
}

sub check_all_routes {
    my $self = shift;
    my ($agency) = @_;

    my $key = check_all_key($agency);
    return $self->cache->compute($key, SHORT_EXPTIME, sub {
        my $routes = $self->get_routes($agency);
        my @ids = keys %{$routes};
        my $all = {};
        for my $id (@ids) {
            my $status = $self->check_route($agency, $id);
            $all->{$id} = {
                name => $routes->{$id},
                status => $status,
            };
        }
        return $all;
    });
}

sub check_route {
    my $self = shift;
    my ($agency, $route) = @_;

    my $key = fucked_key($agency, $route);
    return $self->cache->compute( $key, SHORT_EXPTIME, sub {
        return $self->_check_route($agency, $route);
    });
}

sub _check_route {
    my $self = shift;
    my ($agency, $route) = @_;

    my $termini = $self->find_termini($agency, $route);

    my $delayed = 0;
    my $total = 0;
    for my $terminus (@$termini) {
        my ($_total, $_delayed) = $self->_get_delayed_stats($agency, $route, $terminus);
        $delayed += $_delayed;
        $total += $_total;
    }
    my $delayed_pct = ($total > 0) ? $delayed / $total : 0;

    my $runs = $self->get_runs($agency, $route);
    my $smallest = 1000;
    my $biggest = 0;
    for my $run (@$runs) {
        my $stops = $self->get_stops_for_run($agency, $route, $run->{id});
        my $middle = int(scalar @$stops / 2);
        my $stop = $stops->[$middle];
        my ($big, $small) = $self->gap_stats($agency, $route, $stop->{id});
        if ($big > $biggest) {
            $biggest = $big;
        }
        if ($small < $smallest) {
            $smallest = $small;
        }
    }

    my $fuckedness = $delayed_pct;
    my $small_gap = is_weekend() ? SMALL_THRESHOLD * 1.5 : SMALL_THRESHOLD;
    my $big_gap = is_weekend() ? BIG_THRESHOLD * 1.5 : BIG_THRESHOLD;
    if ($smallest < $small_gap) {
        $fuckedness += GAP_FACTOR;
    }
    if ($biggest > $big_gap) {
        $fuckedness += GAP_FACTOR;
    }

    return {
        delayed => $delayed,
        total   => $total,
        delayed_pct => $delayed_pct,
        big_gap => $biggest,
        small_gap => $smallest,
        is_fucked => ($fuckedness >= FUCKED_THRESHOLD) ? 1 : 0,
    };
}

sub find_termini {
    my $self = shift;
    my ($agency, $route) = @_;

    my $key = termini_key($agency, $route);
    return $self->cache->compute( $key, LONG_EXPTIME, sub {
        return $self->_find_termini($agency, $route);
    });
}

sub _find_termini {
    my $self = shift;
    my ($agency, $route) = @_;

    try {
        my $runs = $self->proximobus->runs($agency, $route);
        my @termini;
        for my $run (@{$runs->{items}}) {
            # We should only care about publicly-visible runs.
            if ($run->{display_in_ui}) {
                my $stops = $self->proximobus->stops_for_run($agency, $route, $run->{id});
                my $idx = $#{$stops->{items}};
                push @termini, $stops->{items}->[$idx]->{id};
            }
        }
        return \@termini;
    }
    catch {
        die "couldn't find termini for $agency/$route: $_";
    };
}

sub _get_delayed_stats {
    my $self = shift;
    my ($agency, $route, $stop) = @_;

    try {
        my $predictions = $self->proximobus->predictions_for_stop_by_route($agency, $stop, $route);
        my $delayed = 0;
        my $total = scalar @{$predictions->{items}};
        for my $p (@{$predictions->{items}}) {
            $delayed++ if ($p->{is_delayed});
        }
        return ($total, $delayed);
    }
    catch {
        die "couldn't get predictions for $agency/$route/$stop: $_";
    };
}

sub gap_stats {
    my $self = shift;
    my ($agency, $route, $stop) = @_;

    try {
        my $result = $self->proximobus->predictions_for_stop_by_route($agency, $stop, $route);
        my $predictions = $result->{items};
        my $count = scalar @$predictions;
        my $biggest = 0;
        my $smallest = 1000;
        for (my $i = 0; $i < $count - 2; $i++) {
            my $gap = $predictions->[$i+1]->{minutes} - $predictions->[$i]->{minutes};
            if ($gap > $biggest) {
                $biggest = $gap;
            }
            if ($gap < $smallest) {
                $smallest = $gap;
            }
        }
        return ($biggest, $smallest);
    }
    catch {
        die "Couldn't get predictions for $agency/$stop/$route: $_";
    };
}

sub get_routes {
    my $self = shift;
    my ($agency) = @_;

    my $key = routes_key($agency);
    return $self->cache->compute( $key, LONG_EXPTIME, sub {
        return $self->_get_routes($agency);
    });
}

sub get_sorted_names {
    my $self = shift;
    my ($agency) = @_;

    my $routes = $self->get_routes($agency);
    my @names = keys %$routes;
    return [ sort _by_route_name @names ];

}

sub _by_route_name {
    # Put the lettered routes first, in lexicographic order.
    if (($a =~ /^[A-Z]/) && ($b =~ /^[A-Z]/)) {
        return $a cmp $b;
    }
    elsif ($a =~ /^[A-Z]/) {
        return -1;
    }
    elsif ($b =~ /^[A-Z]/) {
        return 1;
    }
    # Numbered lines should go in numeric order with
    # the "main" line coming before any suffixed variants thereof.
    else {
        my $a_ = $a;
        my $b_ = $b;
        my $a_suf = ($a_ =~ s/\D+//);
        my $b_suf = ($b_ =~ s/\D+//);
        if ($a_ <=> $b_) {
            return $a_ <=> $b_;
        }
        else {
            return $a_suf cmp $b_suf;
        }
    }
}

sub _get_routes {
    my $self = shift;
    my ($agency) = @_;

    try {
        my $result = $self->proximobus->routes($agency);
        my $routes = $result->{items};
        my %by_id = map { $_->{id} => $_->{display_name} } @$routes;
        return \%by_id;
    }
    catch {
        die "Couldn't get route list: $_";
    };
}

sub get_runs {
    my $self = shift;
    my ($agency, $route) = @_;

    my $key = runs_key($agency, $route);
    return $self->cache->compute( $key, LONG_EXPTIME, sub {
        return $self->_get_runs($agency, $route);
    });
}

sub _get_runs {
    my $self = shift;
    my ($agency, $route) = @_;

    try {
        my $result = $self->proximobus->runs($agency, $route);
        return $result->{items};
    }
    catch {
        die "Couldn't get runs for $agency/$route: $_";
    };
}

sub get_stops_for_run {
    my $self = shift;
    my ($agency, $route, $run) = @_;

    my $key = stops_key($agency, $route, $run);
    return $self->cache->compute( $key, LONG_EXPTIME, sub {
        return $self->_get_stops_for_run($agency, $route, $run);
    });
}

sub _get_stops_for_run {
    my $self = shift;
    my ($agency, $route, $run) = @_;

    try {
        my $result = $self->proximobus->stops_for_run($agency, $route, $run);
        return $result->{items};
    }
    catch {
        die "Couldn't get stops for $agency/$route/$run: $_";
    };
}

=head1 NAME

IsMuniFucked::RouteChecker - Check to see if a route is fucked.

=head1 SYNOPSIS

my $agency = "sf-muni";
my $route = "L";

my $fucked = IsMuniFucked::RouteChecker->check_route($agency, $route);
my $status = $fucked ? "is" : "is not";
print "$agency's $route $status fucked\n";

=cut

"Outbound train: 2 car L L in 6 minutes.";
