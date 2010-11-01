--  Send_To_OF.applescript
--  Send_To_OF
--
--  Created by Brian Edginton on 10/9/10.
--  Copyright Dancing Lizard Forge 2010. All rights reserved.

on Send_To_OF(results)
	using terms from application "Quick Search Box"
		repeat with x in results
			--display dialog "Name: " & name of x & return & "URI: " & URI of x
			copy name of x to thisAction
			tell application "OmniFocus"
				tell default document
					parse tasks with transport text thisAction
					compact
				end tell
			end tell
		end repeat
	end using terms from
end Send_To_OF

-- OF email syntax
-- > or :: is project name
-- @ is context
-- # start (1 date) or start and due (2 dates)
-- $ time estimate
-- ! set flag 
-- // sets note
