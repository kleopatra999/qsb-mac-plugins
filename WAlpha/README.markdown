Wolfram Alpha for Quick Search Box
==================================

A QSB plugin that lets you invoke Wolfram Alpha searches right from your desktop.

[Watch screencast](http://vimeo.com/12683438)

Installation
------------

1. Make sure you are running the latest build (3328) of Google QSB.
2. Download (and extract, if necessary) the latest binary of the plugin from [github](http://github.com/mattrajca/WAlpha-QSB/downloads).
3. Move the extracted 'WAlpha.hgs' file to '~/Library/Application Support/Google/Quick Search Box/PlugIns'.
4. Restart QSB.

Usage
-----

1. Open QSB.
2. Enter the keyword "alpha" (without the quotation marks), followed by your search query.
3. Hit enter to invoke the search.

Building from Source
--------------------

1. Setup your QSB source tree (Navigate [here](http://qsb-mac.googlecode.com/svn/trunk/QuickSearchBox/QSB/SDK/Templates/QSBPlugin/README.txt) for instructions).
2. Build the Xcode project per usual.
3. Copy the 'WAlpha.hgs' file from the 'Build/Release' directory to '~/Library/Application Support/Google/Quick Search Box/PlugIns'.
4. Restart QSB.

Credits
-------

The Wolfram Alpha extension icon is courtesy of [http://theletter.co.uk/](http://theletter.co.uk/).

Issues
------

You may report any issues or feature requests [here](http://github.com/mattrajca/WAlpha-QSB/issues). If you installed the plugin properly but it doesn't load, you are probably using an older version of QSB.
