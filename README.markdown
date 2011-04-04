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

# Credits

Sam Kimbrel (kimbrel@me.com)




