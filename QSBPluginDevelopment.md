**Work in progress** - please post questions to http://groups.google.com/group/qsb-mac-dev and we'll update this page with answers.

## Getting the SDK ##
Get the latest SDK (or build it from the [top of QSB tree](http://code.google.com/p/qsb-mac/source/checkout)). Look for it here: http://code.google.com/p/qsb-mac/downloads/list

## Setting up Xcode ##
  1. Go to "Xcode>Preferences" and click on the "Source Trees" icon.
  1. Click on the "Plus" button on the left hand side of the window.
  1. Set the "Setting Name" of your new tree to "`QSBBUILDROOT`"
  1. Set the "Display Name" to "`QSBBUILDROOT`"
  1. Set the path to the debug build directory for QSB. For me the path looks like this "`/Users/dmaclach/src/QuickSearchBox/QSB/build/Debug`". If you use a common build directory or some other customized build location, you will have to set it here.
  1. Click on the "Plus" button again
  1. Set the "Setting Name" of your new tree to "`QSBSRCROOT`"
  1. Set the "Display Name" to "`QSBSRCROOT`"
  1. Set the path to the root directory for QSB. For me the path looks like this "`/Users/dmaclach/src/QuickSearchBox`".