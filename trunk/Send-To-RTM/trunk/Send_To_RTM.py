#!/usr/bin/python
#  Send_To_RTM.py
#  Send_To_RTM
#
#  Created by Gordon on 10/26/09.
#  Copyright Gordon Fontenot 2009. All rights reserved.

"""A python quick-add plugin for QSB and Remember the Milk.
"""

__author__ = 'Gordon Fontenot'


#import urllib for url calling
import urllib

#import webbrowser to open auth webpage if necessary
import webbrowser

#import ElementTree to parse / work with XML
from xml.etree import ElementTree as ET

#import NSDictionary and NSString from Cocoa to work with the plist that will hold the token
from Cocoa import NSDictionary, NSString

#import os to work with paths. Needed to see if file exists.
import os

#Import hashlib for MD5 encoding
import hashlib

#import time to be used for the pause during auth.	This should be done more gracefully.
import time

#These are imported by QSB.  Don't change these.
import sys
import thread
import AppKit
import Foundation

#The debug variable. Set to True for debug messages in the command line, printout of the resp.xml on the desktop
debug = False

#Define some main variables. Don't change these.
api_url='http://api.rememberthemilk.com/services/rest/?'
auth_url='http://www.rememberthemilk.com/services/auth/?'
api_key='60a9369798aa92cc5cc291b2280422f1'
api_secret='6fdf8ca0e501715f'
the_plist='~/Library/Preferences/com.rememberthemilk.RTM-QSB.plist'
the_plist=NSString.stringByExpandingTildeInPath(the_plist)
if debug:
	xml_resp = '~/Desktop/resp.xml'
	xml_resp = NSString.stringByExpandingTildeInPath(xml_resp)
auth=1
the_token=0


try:
  import Vermilion	# pylint: disable-msg=C6204
  import VermilionNotify
except ImportError:

  	class Vermilion(object):
	    """A mock implementation of the Vermilion class.

	    Vermilion is provided in native code by the QSB
	    runtime. We create a stub Result class here so that we
	    can develop and test outside of QSB from the command line.
	    """

	    IDENTIFIER = 'IDENTIFIER'
	    DISPLAY_NAME = 'DISPLAY_NAME'
	    MAIN_ITEM = 'MAIN_ITEM'
	    OTHER_ITEMS = 'OTHER_ITEMS'
	    SNIPPET = 'SNIPPET'
	    IMAGE = 'IMAGE'
	    DEFAULT_ACTION = 'DEFAULT_ACTION'
	    TYPE = 'TYPE'

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

	try:
	  import VermilionLocalize
	except ImportError:
	  class VermilionLocalizeStubClass(object):	
	    """Stub class used when running from the command line.	

	    Required when this script is run outside of the Quick Search Box.  This	
	    class is not needed when Vermilion is provided in native code by the	
	    Quick Search runtime.

	    When this source is called from QSB, i.e. when not being run from the
	    command line, user-visible strings can be localized by making a call
	    like:

	      localized_string = VermilionLocalize.String(raw_string, self.extension)

	    The localization version of all strings to be localized in this plugin
	    must be provided in the appropriate Localizable.strings file in the
	    plugin's bindle.
	    """	

	    def String(self, string, extension):	
	      return string

	  VermilionLocalize = VermilionLocalizeStubClass()

class RTM(object):
	"""Holds all the RTM specific functions, mainly the common auth processes"""

	def getLocalToken(self):
		"""Get the local token from the PList"""
		
		if debug:
			print 'Getting local token'
		
		if os.path.exists(the_plist):
			
			if debug:
				print 'Token exists'
			
			mydict = NSDictionary.dictionaryWithContentsOfFile_(the_plist)
			the_token = mydict['Token']
			return the_token
		else:
			
			if debug:
				print 'No Token Found'
			
			return 0
	

	def checkToken(self, the_token):
		"""Check to see if the Token is valid"""
	
		if debug:
			print 'Checking token'
	
		method = 'rtm.auth.checkToken'
		url = "%smethod=%s&api_key=%s&auth_token=%s" % (api_url, method, api_key, the_token)
		the_token = RTM.ParseURL(RTM(), url, 'auth/token/')
		return the_token

	
	def writePlist(self, the_token):
		"""Function to write to the plist. Only sets the token for now. Could add in more parameters later."""
	
		if debug:
			print 'Writing plist'
	
		mydict = {}
		mydict['Token']=the_token
		NSDictionary.dictionaryWithDictionary_(mydict).writeToFile_atomically_(the_plist, True)

		
	def getFrob(self):
		"""get the Frob to begin auth process, because the token came back false"""
		
		if debug:
			print 'getting frob'
			
		method = 'rtm.auth.getFrob'
		the_sig = "%sapi_key%smethod%s" % (api_secret, api_key, method)
		hashed_sig= RTM.createMD5(RTM(), the_sig)
		url = "%smethod=%s&api_key=%s&api_sig=%s" % (api_url, method, api_key, hashed_sig)
		the_frob=RTM.ParseURL(RTM(), url, 'frob/')
		return the_frob

	def createMD5(self, the_string):
		"""Create the MD5 hash out of the constructed sig"""
		
		if debug:
			print 'creating md5 hash'
		
		return hashlib.md5(the_string).hexdigest()
		
	def doAuth(self):
		
		if debug:
			print 'Entered auth'
		
		#Need to get a frob to be used to obtain a new token
		the_frob=RTM.getFrob(RTM())

		#Get the user to give their auth via the RTM website
		RTM.getAuth(RTM(), the_frob)

		#sleep for 15 seconds to allow user to grant auth before proceeding with getting the token. This needs to be implimented better.
		if debug:
			print 'begin sleep'
		
		time.sleep(15)
		
		if debug:
			print 'end sleep'
			
		#Should have auth by now. May run into problems where user isn't paying attention, didn't auth. Again, there may be a better solution for this.

		#Start to get the actual token that will be stored in our plist.
		the_token=RTM.getRemoteToken(RTM(), the_frob)

		if the_token != 0:
			#Token came back successfully. Display success message for Dev

			if debug:
				print 'Sucess'
				print 'Token: '+the_token

			#Store token in plist
			RTM.writePlist(RTM(), the_token)
			return 1
		else:
			#Token did not come back succesfully Should maybe add some error handling here

			if debug:
				print 'Token did not come back succesfully'
			
			return 0

	def getRemoteToken(self, the_frob):
		"""Get the new token from RTM"""
		
		if debug:
			print 'Getting remote token'
		
		method = 'rtm.auth.getToken'
		the_sig = "%sapi_key%sfrob%smethod%s" % (api_secret, api_key, the_frob, method)
		hashed_sig= RTM.createMD5(RTM(), the_sig)
		url = "%smethod=%s&api_key=%s&frob=%s&api_sig=%s" % (api_url, method, api_key, the_frob, hashed_sig)
		the_token = RTM.ParseURL(RTM(), url, 'auth/token/')
		return the_token


	def getAuth(self, the_frob):
		
		if debug:
			print 'getting user auth'
			
		method = 'rtm.auth.getFrob'
		the_sig = "%sapi_key%sfrob%spermswrite" % (api_secret, api_key, the_frob)
		hashed_sig= RTM.createMD5(RTM(), the_sig)
		url = "%sapi_key=%s&frob=%s&perms=write&api_sig=%s" % (auth_url, api_key, the_frob, hashed_sig)
		webbrowser.open(url)

		#For dev: Print out the full URL opened, for error checking.
		if debug:
			print 'Website Opened:'
			print url

	
	def createTimeline(self, the_token):
		"""function to create timeline for sendTask function"""
		
		if debug:
			print 'creating timeline'
		
		method='rtm.timelines.create'
		the_sig = "%sapi_key%sauth_token%smethod%s" % (api_secret, api_key, the_token, method)
		hashed_sig=RTM.createMD5(RTM(), the_sig)
		url = "%smethod=%s&api_key=%s&auth_token=%s&api_sig=%s" % (api_url, method, api_key, the_token, hashed_sig)
		#send url to the parser
		timeline = RTM.ParseURL(RTM(), url, 'timeline/')
		return timeline

	def ParseURL(self, url, ItemNeeded):
		"""Function to call and parse the URL."""
		if debug:
			print 'parsing url'
		
		page = urllib.urlopen(url)

		if debug:
			print "Url sent: " + url

			#Seperate the variable from the file. Used to write the Resp to disk. Used for development.
			the_resp=ET.parse(page)
			tree=the_resp.getroot()
		
			#Write the response to the local XML file. Used for Dev only.	
			the_resp.write(xml_resp)
			
			print 'response written to ~/desktop/resp.xml'
			
			var = 0 
			#Grab the response message	
			for element in tree.findall(ItemNeeded):
				var = str(element.text)
		else:
			#Parse the XML
			the_resp=ET.parse(page).getroot()

			var = 0 
			#Grab the response message	
			for element in the_resp.findall(ItemNeeded):
				var = str(element.text)

		return var
		
	def makeNetSafe(self, url):
		#Escape special characters to net safe strings.
		
		if debug:
			print 'making net safe'
		
		url = urllib.quote(url)
		
		if debug:
			print 'net safe url: ' + url 
		return url
	
	
	def core(self):
		
		if debug:
			print 'in RTM.core()'
		
		#Read the plist, grab the Token
		
		auth = 1
		local_token=RTM.getLocalToken(RTM())
		if debug:
			print local_token
			print "local token recieved"

		if local_token != 0:
			#There is a token, need to check to make sure it isn't expired.

			#Check token't validity
			if debug:
				print "Checking local token"
			
			result = RTM.checkToken(RTM(), local_token)
			
			if debug:
				print "Local token checked"
			
			if result == 0:
				#Token came back false, token is expired.
				if debug:
					print 'Token is false'
					print "Doing auth"
				
				auth=RTM.doAuth(RTM())
				
				if debug:
					print "Auth done"
		else:
			#There is no token. We need to run through the auth process and save a new plist
			if debug:
				print "No token exists"
				print "Doing Auth"
			
			auth=RTM.doAuth(RTM())
			
			if debug:
				print "Auth done"
		
		return auth
	
class Task_Action(object):
  	"""Send_To_RTM Action
		
	Creates a new task in RTM using the Smart Add syntax

  	This class conforms to the QSB search action protocol by
  	providing the mandatory AppliesToResults and Perform methods.
  
  	"""

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
		
		def SendTask(the_task):
			"""Function to send the task to RTM"""
			if debug:
				print 'in SendTask'
				print 'The Task: ' + the_task
			
			#get the local token (again.  Was having problems with the token not being recognized as global.  This solves the issue)
			the_token=RTM.getLocalToken(RTM())

			#need to create timeline.
			timeline=RTM.createTimeline(RTM(), the_token)

			method ='rtm.tasks.add'
			#sets the parse value to 1. With it set to 1, smart-add is in effect.
			doParse = '1'
			
			the_task_u = the_task.decode('utf8')
			the_sig = "%sapi_key%sauth_token%smethod%sname%sparse%stimeline%s" % (api_secret, api_key, the_token, method, the_task_u, doParse, timeline)
			hashed_sig = hashlib.md5(the_sig.encode('utf8')).hexdigest()			
			the_task=RTM.makeNetSafe(RTM(), the_task)
			url = "%smethod=%s&api_key=%s&timeline=%s&name=%s&parse=%s&auth_token=%s&api_sig=%s" % (api_url, method, api_key, timeline, the_task, doParse, the_token, hashed_sig)
			success = RTM.ParseURL(RTM(), url, "list")
			return success
		
		
		
		for direct_object in direct_objects:
		
			if debug:
				the_task = direct_objects
			else:
				the_task = direct_object[Vermilion.DISPLAY_NAME]
					

			auth = RTM.core(RTM())
			if debug:
				print "Made it out of core"
				print auth
			if auth == 1:
				#Auth was sucessfull, should have a token to use.

				#Call SendTask function to create new task
			
				if debug:
					print "Sending task"
			
				success = SendTask(the_task)
				if success == "None":
					if debug:
						print 'Success!'
					msg = "test"
					VermilionNotify.DisplayNotification("Remember The Milk", self.extension, "Task Added: " + the_task, "RTM-QSB-Task-Sucess")
					return True
				else:
					VermilionNotify.DisplayNotification("Remember The Milk", self.extension, "Something Went Wrong!" + the_task, "RTM-QSB-Error")
			
					if debug:
						print 'something went wrong!'
			
					return False
			else:
				#something went wrong. Print a failure message for dev.
				if debug:
					print 'An error occured during the code.  Auth not sucessfull.'
				VermilionNotify.DisplayNotification("Remember The Milk", self.extension, "Something Went Wrong!" + the_task, "RTM-QSB-Error")
				return False
	
		return True

class List_Action(object):
  	"""Send_To_RTM Action

	Creates a new list in RTM.

  	This class conforms to the QSB search action protocol by
  	providing the mandatory AppliesToResults and Perform methods.

  	"""

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
	
		def MakeList(the_list):
			"""Function to send the new list to RTM"""
			#get the local token (again.  Was having problems with the token not being recognized as global.  This solves the issue)
			the_token=RTM.getLocalToken(RTM())

			#need to create timeline.
			timeline=RTM.createTimeline(RTM(), the_token)

			method ='rtm.lists.add'

			the_list_u = the_list.decode('utf8')
			the_sig = "%sapi_key%sauth_token%smethod%sname%stimeline%s" % (api_secret, api_key, the_token, method, the_list_u, timeline)
			hashed_sig = hashlib.md5(the_sig.encode('utf8')).hexdigest()

			the_list=RTM.makeNetSafe(RTM(), the_list)

			url = "%smethod=%s&api_key=%s&timeline=%s&name=%s&auth_token=%s&api_sig=%s" % (api_url, method, api_key, timeline, the_list, the_token, hashed_sig)
			success = RTM.ParseURL(RTM(), url, "list")
			return success
				
		for direct_object in direct_objects:
			if debug:
				the_list = direct_objects
			else:
				the_list = direct_object[Vermilion.DISPLAY_NAME]
			
			auth = RTM.core(RTM())
			if debug:
				print "Made it out of core"
				print auth
			if auth == 1:
				#Auth was sucessfull, should have a token to use.

				#Call SendTask function to create new task
				if debug:
					print "Sending List"
					success = MakeList(the_list)
				if success:
					VermilionNotify.DisplayNotification("Remember The Milk", self.extension, "List Added: " + the_list, "RTM-QSB-List-Sucess")
					if debug:
						print "List Sent"
					return True
				else:
					VermilionNotify.DisplayNotification("Remember The Milk", self.extension, "Something Went Wrong!" + the_task, "RTM-QSB-Error")
					if debug:
						print 'Something went wrong!'
					return False
			else:
				#something went wrong. Print a failure message for dev.
				VermilionNotify.DisplayNotification("Remember The Milk", self.extension, "Something Went Wrong!" + the_task, "RTM-QSB-Error")
				if debug:
					print 'An error occured during the code.  Auth not sucessfull.'
				return False
			

		return True



def main():
  #Command line interface for easier testing.
  argv = sys.argv[1:]
  if not argv:
	print 'Usage: Send_To_RTM <query>'
	return 1
  argv = " ".join(argv)
  
  #Running this plugin via terminal automatically enables Debug mode

  print argv
  global debug
  debug = True
  global xml_resp
  xml_resp = '~/Desktop/resp.xml'
  xml_resp = NSString.stringByExpandingTildeInPath(xml_resp)
  Task_Action.Perform(Task_Action(), argv)
	

if __name__ == '__main__':
  main()
