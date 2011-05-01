# HowFuckedIsMuni

This is the code powering howfuckedismuni.com.
 It's inspired by [Is The L Train Fucked?](https://github.com/jgv/is-the-L-train-fucked/)
and powered by [Dancer](http://perldancer.org/).
Also included is a Perl client library for Martin Atkins' [ProximoBus](http://proximobus.appspot.com/),
a handy JSON-format wrapper for the [NextBus](http://nextbus.com/) API.

The logic is fairly straightforward. Three factors can contribute to a route being fucked:

* The percentage of delayed vehicles on the route exceeds a configurable threshold

* The smallest gap between vehicles traveling the same direction on the route
is under a threshold value

* The largest gap between vehicles traveling the same direction on the route
exceeds a threshold value

# Setup

HFIM requires Redis to run. Configure Redis as you'd like and tell the app where it lives
using the configuration files in environments/.

Configure an appropriate NextBus-enabled transit agency. See ProximoBus docs for more here.

HFIM now supports background refreshing route status -- bin/driver.pl can be run to
periodically query the status of all routes, thus keeping the caches hot. If you don't
use this, the site will still work, but the first request for each separate route will be
slow because the data access layer will have to go run half a dozen queries to compute
the response.

Enjoy!

# Requirements

* Dancer
* Redis
* Perl modules: Moose, CHI/CHI::Driver::Redis, JSON, WWW::ProximoBus (currently
included in this repository, will probably get a separate distribution later)

# Credits

Sam Kimbrel (kimbrel@me.com)

# TODO

Figure out how to use plackup to spawn a single background refresher before launching
the actual server processes. (Doing it in app.psgi would result in one refresher for each
server worker under servers like Starman, which is decidedly not what we want.)

Support a configurable min/max gap threshold for each line -- if at all possible, do this
automatically based on the agency's published schedules.

Similarly, it'd be awesome if we could only display the routes that are actually running right now.

Now that we have background refresh enabled (and should now have data for all lines at all times),
expose fuckedness on the front page somehow.

Use background refresh to compute stats. Perhaps order the lines by historical fuckedness on the front page?



