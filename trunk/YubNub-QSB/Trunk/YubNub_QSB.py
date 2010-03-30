#!/usr/bin/python
#
#  Yub_Nub_QSB.py
#  Yub-Nub-QSB
#
#  Created by Gordon on 2/24/10.
#  Copyright __MyCompanyName__ 2010. All rights reserved.
#

"""A python search source for QSB.
"""

__author__ = 'Gordon'

"""import urllib for url calling"""
import urllib

"""import webbrowser to open auth webpage if necissary"""
import webbrowser

import sys
import thread
import AppKit
import Foundation

try:
  import Vermilion	# pylint: disable-msg=C6204
except ImportError:

  class Vermilion(object):
	"""A mock implementation of the Vermilion class.

	Vermilion is provided in native code by the QSB
	runtime. We create a stub Result class here so that we
	can develop and test outside of QSB from the command line.
	"""
	
	IDENTIFIER = 'IDENTIFIER'
	DISPLAY_NAME = 'DISPLAY_NAME'
	SNIPPET = 'SNIPPET'
	IMAGE = 'IMAGE'
	DEFAULT_ACTION = 'DEFAULT_ACTION'

	class Query(object):
	  """A mock implementation of the Vermilion.Query class.

	  Vermilion is provided in native code by the QSB
	  runtime. We create a stub Result class here so that we
	  can develop and test outside of QSB from the command line.
	  """
	  
	  def __init__(self, phrase):
		self.raw_query = phrase
		self.normalized_query = phrase
		self.pivot_object = None
		self.finished = False
		self.results = []

	  def SetResults(self, results):
		self.results = results

	  def Finish(self):
		self.finished = True

class YubNub_Search(object):
	def __init__(self, extension=None):
		"""Initializes the plugin.
	      Args:
	      extension: An opaque instance of the extension.
	    """
		self.extension = extension
	    
	def AppliesToResults(self, result):
		"""Determine if the action applies to the results.

    	Args:
      	result: An array of result objects for which to determine the
        action's applicability.

    	Returns:
      	A boolean indicating if the action is appropriate for ALL of the
      	results contained in the results array.
    	"""
		return True

	def Perform(self, direct_objects, other_arguments=None):
		"""Perform the action on each of the results.

    	Args:
      	direct_objects: An array of result objects to perform the action with.
      	other_arguments: A dictionary of other arguments keyed by argument id.

    	Returns:
      	If this action returns results, an array of results on success. Otherwise
      	return True on success, and False on failure.
    	"""
		for direct_object in direct_objects:
			the_search = direct_object[Vermilion.DISPLAY_NAME]
			the_search = urllib.quote(the_search)
			cmd = "http://yubnub.org/parser/parse?command=%s" % (the_search)
			webbrowser.open(cmd)
		return True

def main():
  """Command line interface for easier testing."""
  argv = sys.argv[1:]
  if not argv:
	print 'Usage: Yub_Nub_QSB <query>'
	return 1

  query = Vermilion.Query(argv[0])
  search = YubNub_Search()
  if not search.IsValidSourceForQuery(Vermilion.Query(argv[0])):
	print 'Not a valid query'
	return 1
  search.PerformSearch(query)

  while query.finished is False:
	time.sleep(1)

  for result in query.results:
	print result


if __name__ == '__main__':
  sys.exit(main())
