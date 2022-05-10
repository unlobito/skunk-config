skunk-config
============
Config panel for [Skunk](https://github.com/unlobito/skunk). Responsible for
allowing users to add barcodes as well as generating the images for these barcodes.

Problem?
--------
Please file issues against [unlobito/skunk](https://github.com/unlobito/skunk/issues).

Setup
-----
If you're not using rbenv, please make sure you have Ruby 2.1.2 installed.

Use `bundle` to install skunk-config's dependencies. Then, use `thin -R config.ru start -p 4567`
to start the web server.

If you want to point your Pebble at your web server, change Skunk's `src/js/pebble-app-js.js`'s
third line to your computer's IP address. You can then push the modified Skunk build
to your phone using the usual `pebble build && pebble install` or CloudPebble.
