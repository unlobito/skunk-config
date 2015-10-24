skunk-config
============
Config panel for [Skunk](https://github.com/henriwatson/skunk). Responsible for
allowing users to add barcodes as well as generating the images for these barcodes.

Problem?
--------
Please file issues against [henriwatson/skunk](https://github.com/henriwatson/skunk/issues).

Setup
-----
If you're not using rbenv, please make sure you have JRuby 9.0.1.0 installed.

Use `bundle` to install skunk-config's dependencies. Then, use `puma -b tcp://0.0.0.0:4567`
to start the web server.

If you want to point your Pebble at your web server, change Skunk's `src/js/pebble-app-js.js`'s
third line to your computer's IP address. You can then push the modified Skunk build
to your phone using the usual `pebble build && pebble install` or CloudPebble.
