-- Applescript for BibDesk
-- Extract the DOI information from the PDF, then use curl to download ADS BibTeX record
--2020-01-24 use the crossref-recommended DOI regex first in findDOI()
--2020-01-24 add "newADS" to the name to clarify purpose; delete some unused subroutines
--v12b, 2019-12-17: comment out some of the debugging dialog boxes from v12
--v12, 2019-11-??: work with new ADS
-- v11, 2016-11-01:  automatically stick the extracted DOI in the DOI field even if ADS record retrieval fails (dx.doi.org can then be used instead)
--- changed " -f 2" to "-f 1" in findDOI() to try to increase the chances of getting the correct DOI
-- v10, 2013-05-28


tell application "BibDesk"
	-- without document, there is no selection, so nothing to do
	if (count of documents) = 0 then
		beep
		display dialog "No documents found." buttons {"¥"} default button 1 giving up after 3
	end if
	set theDoc to document 1
	
	tell theDoc
		set theSel to selection
		set thePub to item 1 of theSel
		get value of field "DOI" of thePub
		set pasteItem to result as string
		set theExistingDOI to pasteItem
		if theExistingDOI = "" then
			set theDOIString to ""
			tell thePub
				set theCount to count of (get linked files)
				--return theCount
				set theAlreadyLinkedFiles to " "
				if theCount = 0 then error
				if theCount > 0 then
					--set theAlreadyLinkedFiles to the POSIX path of (get linked files)
					set theAlreadyLinkedFiles to (get linked files)
					set theFirstLinkedFile to item 1 of theAlreadyLinkedFiles
					set theFirstFile to the POSIX path of theFirstLinkedFile
					-- Extract the DOI from the first linked file using pdftotext and sed
					set theDOIString to my findDOI(theFirstFile)
					--return theDOIString
				end if
				-- 2016-11-01 (v11), automatically add retrieved DOI to DOI field
				set value of field "Doi" to theDOIString
				-- end (v11)
			end tell
		else
			set theDOIString to theExistingDOI
		end if
		
		-- Now that we have a DOI, construct an ADS URL and a DOI URL from it; add to linked URL and linked files
		if theDOIString is not "" then
			-- If it's not already in there, copy to remote URL list
			set theDOIString2 to my removebrackets(theDOIString)
			
			-- Add the DOI URL to the list of URLs if it's not already there			
			set urlName to "http://dx.doi.org/" & theDOIString2
			set theExistingURLs to linked URLs of thePub
			if (theDOIString is not "") and (urlName is not in (theExistingURLs)) then add urlName to end of linked URLs of thePub
			-- Add the ADS URL to its own field (Adsurl) if it's not already there
			set theExistingAdsurl to value of field "Adsurl" of thePub
			-- this is now a provisional URL, not the real one
			if "adsabs" is not in theExistingAdsurl then
				--set adsurlName to "https://ui.adsabs.harvard.edu/doi/" & theDOIString2
				-- the "new" ui... gives a 404 without the redirect
				--old ADS: this works in 2019 for giving the DOI redirect all the way to the ADSurl
				-- 301 document moved
				set adsurlName to "http://adsabs.harvard.edu/doi/" & theDOIString2
				set value of field "Adsurl" of thePub to adsurlName
			end if
		end if
		
		-- Now use the ADS URL to fill out the Bibdesk record for this publication.
		-- First save the existing values of every field so they won't be overwritten by the new ADS information:
		--- 1. construct "newPub" with the ADS values
		--- 2. copy thePub's linked URL and linked file lists to newPub, along with the abstract, if any
		--- 3. overwrite all fields of "thePub" from newPub
		--- 4. delete the now-redundant newPub.
		
		get value of field "Adsurl" of thePub
		set theAdsurl to result as string
		if theAdsurl is "" then
			beep
			set theMessage to "No Adsurl"
			display dialog theMessage buttons {"¥"} default button 1 giving up after 3
			
		else
			-- Download the BibTeX information from ADS
			set theBibtexUrl to my getADSBibtexUrl(theAdsurl)
			--display dialog "toplevel theBibtexUrl: " & theBibtexUrl buttons {"¥"} default button 1 giving up after 4
			-- 2019: edit the curl command to handle redirects
			-- in the old ADS, at this point theNewBibtexString was the entire BibTeX entry for the publication!
			-- now it is a mess of html
			-- need a new function to fix this?
			set theNewBibtexString to my getBibtexEntry(theBibtexUrl)
			--remove/decode the external "&#34;" quote codes, otherwise the new pub can't be created:
			set theNewBibtexString2 to my cleanBibtexString(theNewBibtexString)
			--display dialog "toplevel: theNewBibtexString 1  %%%" & theNewBibtexString & "%%%" buttons {"¥"} default button 1 giving up after 6
			--display dialog "toplevel: theNewBibtexString 2  %%%" & theNewBibtexString2 & "%%%" buttons {"¥"} default button 1 giving up after 6
			--return TheCommand
			--return theTitle
			if theNewBibtexString2 = "" then
				beep
				set theMessage to "No ADS BibTeX downloaded." & TheCommand
				display dialog theMessage buttons {"¥"} default button 1 giving up after 4
				--return theNewBibtexString
			else
				--return theNewBibtexString
				-- Temporarily stash the ADS results in "newPub"
				set theMessage to "ADS BibTeX string found"
				--display dialog theMessage buttons {"¥"} default button 1 giving up after 4
				--tell theDoc
				--	set newPub to make new publication at end of publications
				--	tell newPub
				--		set BibTeX string to theNewBibtexString
				--	end tell
				--end tell
				set newPub to make new publication with properties {BibTeX string:theNewBibtexString2} at end of publications
				set theMessage to "New Pub created"
				--display dialog theMessage buttons {"¥"} default button 1 giving up after 4
				
				-- Preserve the original entry's linked file list
				set theAlreadyLinkedFiles to linked files of thePub
				set theMessage to "LinkedFiles: " & theAlreadyLinkedFiles
				--display dialog theMessage buttons {"¥"} default button 1 giving up after 4
				--return theAlreadyLinkedFiles
				tell newPub
					make new linked file with data theAlreadyLinkedFiles at end of linked files
				end tell
				-- Preserve the original entry's abstract, if it has one
				set theExistingAbstract to the abstract of thePub
				--display dialog "Existing Abstract: " & theExistingAbstract buttons {"¥"} default button 1 giving up after 4
				
				-- If the original entry doesn't already have an abstract, fill it from ADS
				if theExistingAbstract is not "" then
					set the abstract of newPub to theExistingAbstract
				else
					--set TheCommand to "curl '" & theAdsurl & "'"
					--set theGoodAdsurl to my cleanADSUrl(theAdsurl)
					set theMessage to "theAdsurl: " & theAdsurl
					-- this is still somehow the old URL at this point in the code
					-- the redirect-following in getADSAbstract() is probably happening for the second time here, haven't figured out yet how to remove the redundancy
					--display dialog theMessage buttons {"¥"} default button 1 giving up after 4
					set theAbstract to my getADSAbstract(theAdsurl)
					--display dialog "toplevel theAbstract: " & theAbstract buttons {"¥"} default button 1 giving up after 4
					--return theAbstract
					if theAbstract is not " " then
						get theAbstract
						set pasteItem to result as string
						--return pasteItem
						set abstract of newPub to pasteItem
					else
						set theMessage to "No abstract found"
						display dialog theMessage buttons {"¥"} default button 1 giving up after 4
					end if
				end if
				
				
				
				-- Now that the linked file list and abstract have been copied into the "newPub", we can overwrite every field in "ThePub"
				-- Copy all the fields in "newPub" into the original entry "ThePub"
				set theNewFields to every field of newPub
				repeat with theField in every field of newPub
					set fieldName to name of theField
					--return fieldName
					set value of field fieldName of thePub to (get value of field fieldName of newPub)
				end repeat
				get the cite key of newPub
				set newCiteKey to result
				--return newCiteKey
				set cite key of thePub to newCiteKey
				
				
				-- Copy the ADS URL from its own special field to the "normal" list of linked URLs
				get value of field "Adsurl" of thePub
				set pasteItem to result as string
				set theAdsurl to pasteItem
				tell thePub
					-- generate a new value for the field, we use the "Url" field as a dummy
					if (theAdsurl is not "") and (theAdsurl is not in (get linked URLs)) then Â
						add theAdsurl to end of linked URLs
				end tell
				
				remove newPub
				--return theAbstract
				--return theNewFields
			end if -- end of "if a non-empty ADS Bibtex entry has been downloaded"
		end if -- end of "if a valid ADS Url exists"
	end tell
end tell

-- end of the main program

-------------------------

on findDOI(theFilename)
	
	-- Given a PDF file, extract the DOI.
	
	--set theSedString to "'s_.*doi: *\\([0-9][0-9]*.[a-zA-Z0-9./]*\\).*_\\1_p'"
	--set theSedString to "'s_.*[Dd][Oo][Ii][:)] *\\([0-9][0-9]*.[)a-z(A-Z0-9./-]*\\).*_\\1_p'"
	--
	--crossref recommends "/^10.\d{4,9}/[-._;()/:A-Z0-9]+$/i"
	--  Escaping the curly braces and doubling all the backslashes:
	--  Don't forget you need single quotes inside the double quotes!
	set theSedslashString to "'s_.*\\(10\\.[0-9]\\{4,9\\}/[-._;()/:a-zA-Z0-9]*\\).*_doi\\1_p'"
	--set theSedslashString to "'s_.*\\(10\\.[0-9]\\{4,9\\}/[-.;()/:a-zA-Z0-9]*\\).*_doi\\1_p'"
	--set theSedslashString to "'s_.*\\(10\\.[0-9]*/[-.;()/:a-zA-Z0-9]*\\).*_doi\\1_p'"
	--set theSedSlashCommand to "sed -n -e " & theSedSlashString
	--set TheCommand to "/opt/local/bin/xpdf-pdftotext -l 1 " & quoted form of theFilename & " - |  LC_ALL=C " & theSedSlashCommand
	set theSedSlashCommand to "sed -n -e " & theSedslashString
	set TheCommand to "/opt/local/bin/xpdf-pdftotext -l 1 " & quoted form of theFilename & " - | " & theSedSlashCommand
	--return TheCommand
	--display dialog TheCommand buttons {"¥"} default button 1 giving up after 5
	do shell script TheCommand
	set theDOIString to result
	--return theDOIString
	
	--display dialog theDOIString buttons {"¥"} default button 1 giving up after 3
	
	------  Some backup DOIs ----
	-- Any number of digits + a period + any number of alphanumeric characters + a solidus + at least one of  (alphanumeric characters, parentheses, periods, or dashes) 
	-- Also, artifically add a "doi" to the front of the resulting string to use later as a delimiter	
	-- For SsRev, allow a space ([:blank:]) to be the delimiter between "DOI" and the DOI
	-- For ApJ and AAP, try adding another solidus
	-- Do not allow consecutive solidi?
	-- Do not allow the DOI to end with a solidus, period, or comma
	--set theSedslashString to "'s_.*[Dd][Oo][Ii][:)] *\\([[:digit:]][[:digit:]]*.[[:alnum:])(.-]*/[[:alnum:])(.-][[:alnum:]):(.-]*[[:alnum:]-]*/[[:alnum:]):(.-]*[[:alnum:]-]*[[:alnum:]):(.-]/[[:alnum:]):(.-]*/[[:alnum:]):(.-]*\\).*_doi\\1_p'"
	--set theSedslashString to "'s_.*[Dd][Oo][Ii][:)[:blank:]] *\\([[:digit:]][[:digit:]]*.[[:alnum:])(.-]*/[[:alnum:]][[:alnum:]):(.-]*[[:alnum:]):(.-/]*[[:alnum:])(]\\).*_doi\\1_p'"
	--set theSedslashString to "'s_.*[Dd][Oo][Ii][:)/[:blank:]] *\\([[:digit:]][[:digit:]]*\\.[[:alnum:]]*[[:alnum:]/)(.-]*[[:alnum:]]\\).*_doi\\1_p'"
	--
	if theDOIString = "" then
		-- Try allowing ONE whitespace character after "10.1111" for the PNAS format (the dot can be a slash or
		-- whitespace or any other non-EOL character)
		--- the problem with PNAS is that it looks like a slash, but pdftotext reads it as a space.
		--- the extracted DOI has a space and does not resolve properly in ADS
		--- could substitute a slash, but that would be awfully specific to PNAS.  For now just
		--- handle PNAS manually.
		set theSedslashString to "'s_.*[Dd][Oo][Ii][:)/[:blank:]] *\\([[:digit:]][[:digit:]]*\\.[[:alnum:]]*.[[:alnum:]]*[[:alnum:]/)(.-]*[[:alnum:]]\\).*_doi\\1_p'"
		set theSedSlashCommand to "sed -n -e " & theSedslashString
		set TheCommand to "/opt/local/bin/xpdf-pdftotext -l 1 " & quoted form of theFilename & " - | " & theSedSlashCommand
		--return TheCommand
		--display dialog TheCommand buttons {"¥"} default button 1 giving up after 5
		do shell script TheCommand
		set theDOIString to result
		--return theDOIString
	end if
	
	--display dialog theDOIString buttons {"¥"} default button 1 giving up after 3
	
	-- Fall back to a simpler DOI
	-- Any number of digits + a period + any number of alphanumeric characters + a solidus + at least one of  (alphanumeric characters, parentheses, periods, or dashes) 
	-- Also, artifically add a "doi" to the front of the resulting string to use later as a delimiter	
	
	if theDOIString = "" then
		display dialog "No DOI found.  Retrying" buttons {"¥"} default button 1 giving up after 3
		set theSedString to "'s_.*[Dd][Oo][Ii][:)] *\\([[:digit:]][[:digit:]]*.[[:alnum:])(.-]*/[[:alnum:])(.-][[:alnum:]):(.-]*[[:alnum:]-]\\).*_doi\\1_p'"
		
		--return theSedString
		set theSedCommand to "sed -n -e " & theSedString
		set theGrepCommand to " grep -i doi "
		set TheCommand to "/opt/local/bin/xpdf-pdftotext -l 1 " & quoted form of theFilename & " - | " & theSedCommand
		--return TheCommand
		do shell script TheCommand
		set theDOIString to result
		--display dialog theDOIString buttons {"¥"} default button 1 giving up after 3
	end if
	
	-- If the DOI isn't found on the first page, try searching the rest of the document
	if theDOIString = "" then
		--set TheCommand to "/sw/bin/pdftotext -f 2 " & quoted form of theFilename & " - | " & theSedCommand
		--set TheCommand to "/opt/local/bin/xpdf-pdftotext -f 2 " & quoted form of theFilename & " - | " & theSedSlashCommand
		set TheCommand to "/opt/local/bin/xpdf-pdftotext -f 1 " & quoted form of theFilename & " - | " & theSedSlashCommand
		do shell script TheCommand
		set theDOIString to result
	end if
	-- If there's no labeled DOI, try again with just the form
	if theDOIString = "" then
		
		--set theSedString to "'s_.* *\\([[:digit:]][[:digit:]]\\.[[:alnum:])(.-]*/[[:alnum:])(.-][[:alnum:]):(.-]*[[:alnum:]-]\\).*_doi\\1_p'"
		set theSedString to "'s_.* *\\(10\\.[[:alnum:])(.-]*/[[:alnum:]][[:alnum:]):(.-]*[[:alnum:]):(.-/]*[[:alnum:])(]\\).*_doi\\1_p'"
		
		set theSedCommand to "sed -n -e " & theSedString
		set TheCommand to "/opt/local/bin/xpdf-pdftotext -l 1 " & quoted form of theFilename & " - | " & theSedCommand
		--return TheCommand
		do shell script TheCommand
		
		set theDOIString to result
		--display dialog theDOIString buttons {"¥"} default button 1 giving up after 3
	end if
	
	---- Keep this one ----
	if theDOIString = "" then
		beep
		display dialog "No DOI found." buttons {"¥"} default button 1 giving up after 3
	else
		-- In case more than one DOI has been returned, select just the first one
		--display dialog theDOIString buttons {"¥"} default button 1 giving up after 3
		set savedTextItemDelimiters to AppleScript's text item delimiters
		--set AppleScript's text item delimiters to ASCII character 10
		--set AppleScript's text item delimiters to space
		--set AppleScript's text item delimiters to "10."
		set AppleScript's text item delimiters to "doi"
		set thefirstDOIString to the second text item of theDOIString
		--set thefirstDOIString to AppleScript's text item delimiters & partofthefirstDOIString
		-- Eliminate trailing carriage returns
		set AppleScript's text item delimiters to ASCII character 13
		set thefirstDOIString to the first text item of thefirstDOIString
		set AppleScript's text item delimiters to savedTextItemDelimiters
		set theDOIString to thefirstDOIString
	end if
	
	return theDOIString
end findDOI

-------------------------

on removebrackets(theDOIString)
	
	-- If the DOI is in brackets (ScienceDirect will do this) then remove the brackets
	if the first item of theDOIString is "{" then
		set savedTextItemDelimiters to AppleScript's text item delimiters
		-- replace theBadString with theGoodString in theBibtexUrl
		set AppleScript's text item delimiters to "{"
		set theDOIString2 to the second text item of theDOIString
		set AppleScript's text item delimiters to "}"
		set theDOIString2 to the first text item of theDOIString2
		set AppleScript's text item delimiters to savedTextItemDelimiters
	else
		set theDOIString2 to theDOIString
	end if
	return theDOIString2
end removebrackets

-------------------------

on getADSBibtexUrl(theAdsurl)
	
	-- Eliminate ":443/"
	set theBibtexUrl to my cleanADSUrl(theAdsurl)
	
	-- Eliminate carriage returns
	if (theBibtexUrl contains (ASCII character 13)) then
		
		set savedTextItemDelimiters to AppleScript's text item delimiters
		-- replace theBadString with theGoodString in theBibtexUrl
		set AppleScript's text item delimiters to ASCII character 13
		set the text_item_list to every text item of theBibtexUrl
		set AppleScript's text item delimiters to ""
		set theBibtexUrl to the text_item_list as string
		set AppleScript's text item delimiters to savedTextItemDelimiters
	end if
	--return theBibtexUrl
	
	--set theBibtexUrl to theBibtexUrl & "&amp;data_type=BIBTEX"
	--set theBibtexUrl to theBibtexUrl & "/exportcitation"
	set theBadString to "/abstract"
	
	if (theBibtexUrl contains theBadString) then
		set theGoodString to "/exportcitation"
		set savedTextItemDelimiters to AppleScript's text item delimiters
		-- replace theBadString with theGoodString in theAdsurl
		set AppleScript's text item delimiters to theBadString
		set the text_item_list to every text item of theBibtexUrl
		set AppleScript's text item delimiters to theGoodString
		set theGoodAdsurl to the text_item_list as string
		set AppleScript's text item delimiters to savedTextItemDelimiters
	else
		set theGoodAdsurl to theBibtexUrl
	end if
	
	--display dialog "getADSBibtexUrl: " & theGoodAdsurl buttons {"¥"} default button 1 giving up after 5
	return theGoodAdsurl
end getADSBibtexUrl

-------------------------
on cleanADSUrl(theAdsurl)
	
	set theBadString to "cgi-bin/nph-bib_query?"
	
	if (theAdsurl contains theBadString) then
		set theGoodString to "abs/"
		set savedTextItemDelimiters to AppleScript's text item delimiters
		-- replace theBadString with theGoodString in theAdsurl
		set AppleScript's text item delimiters to theBadString
		set the text_item_list to every text item of theAdsurl
		set AppleScript's text item delimiters to theGoodString
		set theGoodAdsurl to the text_item_list as string
		set AppleScript's text item delimiters to savedTextItemDelimiters
	else
		set theGoodAdsurl to theAdsurl
	end if
	
	-- the new "curl" command follows the redirect and returns the new URL
	-- the "-w %{url_effective}" does this
	set TheCommand to "curl -Ls -o /dev/null -w %{url_effective} " & the quoted form of theGoodAdsurl
	do shell script TheCommand
	set theGoodAdsurl2 to the result
	--display dialog theGoodAdsurl2 buttons {"¥"} default button 1 giving up after 5
	
	-- including the ":443" seems to be returning a "not found" page
	set theAdsurl to theGoodAdsurl2
	set theBadString to ":443/"
	
	if (theAdsurl contains theBadString) then
		set theGoodString to "/"
		set savedTextItemDelimiters to AppleScript's text item delimiters
		-- replace theBadString with theGoodString in theAdsurl
		set AppleScript's text item delimiters to theBadString
		set the text_item_list to every text item of theAdsurl
		set AppleScript's text item delimiters to theGoodString
		set theGoodAdsurl3 to the text_item_list as string
		set AppleScript's text item delimiters to savedTextItemDelimiters
	else
		set theGoodAdsurl3 to theAdsurl
	end if
	--display dialog "cleanADSUrl: " & theAdsurl & "  " & theGoodAdsurl3 buttons {"¥"} default button 1 giving up after 8
	return theGoodAdsurl3
end cleanADSUrl
-------------------------

on getADSAbstract(theAdsurl)
	
	-- Download an ADS record (from the supplied URL) and extract the abstract text.
	
	--set TheCommand to "curl '" & theAdsurl & "'"
	-- the new "curl" command follows the redirect and returns the new URL
	-- the "-w %{url_effective}" does this
	set TheCommand to "curl -Ls -o /dev/null -w %{url_effective} " & the quoted form of theAdsurl
	do shell script TheCommand
	set theGoodAdsurl2 to the result
	--display dialog "getADSAbstract: " & theAdsurl & " " & theGoodAdsurl2 buttons {"¥"} default button 1 giving up after 8
	
	set TheCommand to "curl '" & theGoodAdsurl2 & "'"
	do shell script TheCommand
	set theAbstract to the result
	--display dialog theAbstract buttons {"¥"} default button 1 giving up after 5
	--if theAbstract = "" then error
	--if theAbstract contains "Abstract</h3>" then
	--set string1 to "<meta name=" & the quoted form of "description" & " content="
	set string1 to "name=\"description\" content=\""
	--set string1 to "description\" content=\""
	--display dialog string1 buttons {"¥"} default button 1 giving up after 5
	if theAbstract contains string1 then
		try
			set savedTextItemDelimiters to AppleScript's text item delimiters
			set AppleScript's text item delimiters to string1
			get last text item of theAbstract
			set theAbstract to the result
			--set AppleScript's text item delimiters to {"<hr>"}
			--set AppleScript's text item delimiters to {">"}
			set AppleScript's text item delimiters to "\">"
			get first text item of theAbstract
			set theAbstract to the result
			set AppleScript's text item delimiters to savedTextItemDelimiters
		end try
	else
		set theAbstract to " "
	end if
	-- clean up HTML ascii &#34; and &#39; (straight quote and straight single quote)
	set theCleanAbstract to my cleanBibtexString(theAbstract)
	get theCleanAbstract
	set pasteItem to result as string
	--display dialog "getADSAbstract: " & theCleanAbstract buttons {"¥"} default button 1 giving up after 5
	
	return theCleanAbstract
	
end getADSAbstract

-------------------------
on getBibtexEntry(theBibtexUrl)
	
	-- Extract the BibTeX information from the results of "curl".
	
	set TheCommand to "curl '" & theBibtexUrl & "'"
	set cmdstring to "getbibtexentry " & TheCommand
	--display dialog cmdstring buttons {"¥"} default button 1 giving up after 5
	do shell script TheCommand
	set theHtmlBibtexString to the result
	--display dialog "getBibtexEntry: " & theHtmlBibtexString buttons {"¥"} default button 1 giving up after 5
	--set theFile to (((path to desktop folder) as string) & "scriptout.txt")
	--display dialog theFile buttons {"¥"} default button 1 giving up after 5
	--writeTextToFile(theHtmlBibtexString, theFile, true)
	
	-- Eliminate carriage returns
	if (theHtmlBibtexString contains (ASCII character 13)) then
		
		set savedTextItemDelimiters to AppleScript's text item delimiters
		set AppleScript's text item delimiters to ASCII character 13
		set the text_item_list to every text item of theHtmlBibtexString
		set AppleScript's text item delimiters to ""
		set theHtmlBibtexString to the text_item_list as string
		set AppleScript's text item delimiters to savedTextItemDelimiters
	end if
	
	--display dialog "getBibtexEntry: " & theHtmlBibtexString buttons {"¥"} default button 1 giving up after 5
	--set theFile to (((path to desktop folder) as string) & "scriptout.txt")
	--display dialog theFile buttons {"¥"} default button 1 giving up after 5
	--writeTextToFile(theHtmlBibtexString, theFile, true)
	
	-- The next few (commented out) lines are about debugging -- 
	-- they just pipe the curl/sed command results to output files so they can be read later
	set theFile2 to "~/Documents/BibdeskPapers/curlsedtest2019c.txt"
	set theFile3 to "~/Documents/BibdeskPapers/curlsedtest2019d.txt"
	--display dialog theFile2 buttons {"¥"} default button 1 giving up after 5
	--set TheCommand2 to "curl '" & theBibtexUrl & "'" & " | sed -e '/<textarea/','/<\\/textarea>/!d' " & " >>  " & theFile2
	--set TheCommand2 to "curl '" & theBibtexUrl & "'" & " | grep textarea " & " >>  " & theFile2 & " 2>&1 "
	--set TheCommand2 to "curl '" & theBibtexUrl & "'" & " >>  " & theFile2 & " 2>&1 "
	set TheCommand2 to "curl '" & theBibtexUrl & "'" & " >>  " & theFile2
	--display dialog TheCommand2 buttons {"¥"} default button 1 giving up after 5
	--display dialog theFile2 buttons {"¥"} default button 1 giving up after 5
	--set TheCommand2 to "curl '" & theBibtexUrl & "'" & " | sed -e '/<textarea/','/<\\/textarea>/!d' " & " >>  " & theFile3
	--do shell script TheCommand2
	--set TheCommand2 to "curl '" & theBibtexUrl & "'" & " | sed -e '/<textarea/','/<\\/textarea>/!d' "
	do shell script TheCommand2
	set theBibtexString2 to the result
	--if theAbstract = "" then error
	--if theAbstract contains "Abstract</h3>" then
	--set string1 to "<textarea class=" & the quoted form of "export-textarea form-control" & " readonly=" & the quoted form of "" & the quoted form of "" & ">"
	set string1 to "<textarea class=\"export-textarea form-control\" readonly=\"\">"
	--set string1 to "<textarea"
	--set string1 to "ARTICLE"
	--set string1 to "!DOCTYPE"
	--display dialog string1 buttons {"¥"} default button 1 giving up after 5
	
	--	repeat with aa from 1 to length of text_item_list
	--		set thetextitem to item aa of text_item_list
	--		if aa is 1 then display dialog "Item " & aa & thetextitem
	--		if aa is 10 then display dialog thetextitem
	--		if thetextitem contains string1 then display dialog "Item " & aa & " " & thetextitem
	--		if thetextitem contains "textarea" then display dialog "Item " & aa & " " & thetextitem
	--	end repeat
	--	display dialog "Item " & aa & thetextitem
	if theHtmlBibtexString contains string1 then
		--display dialog "string1 found " buttons {"¥"} default button 1 giving up after 5
		try
			set savedTextItemDelimiters to AppleScript's text item delimiters
			set AppleScript's text item delimiters to string1
			get last text item of theHtmlBibtexString
			set theRealBibtex to the result
			--display dialog theRealBibtex buttons {"¥"} default button 1 giving up after 5
			
			--set AppleScript's text item delimiters to {"<hr>"}
			set AppleScript's text item delimiters to {"</textarea>"}
			get first text item of theRealBibtex
			set theRealBibtex to the result
			set AppleScript's text item delimiters to savedTextItemDelimiters
		end try
	else
		set theRealBibtex to " "
	end if
	--display dialog "getBibtexEntry (3): " & theRealBibtex buttons {"¥"} default button 1 giving up after 5
	
	return theRealBibtex
	
end getBibtexEntry

-------------------------

on cleanBibtexString(theBibtexString)
	-- get rid of HTML ascii &#34; and &#39; (straight quote and straight single quote)
	
	set theBadString to "&#34;"
	
	if (theBibtexString contains theBadString) then
		set theGoodString to "\""
		set savedTextItemDelimiters to AppleScript's text item delimiters
		-- replace theBadString with theGoodString in theBibtexString
		set AppleScript's text item delimiters to theBadString
		set the text_item_list to every text item of theBibtexString
		set AppleScript's text item delimiters to theGoodString
		set theNewBibtexString1 to the text_item_list as string
		set AppleScript's text item delimiters to savedTextItemDelimiters
	else
		set theNewBibtexString1 to theBibtexString
	end if
	
	set theBibtexString to theNewBibtexString1
	set theBadString to "&#39;"
	
	if (theBibtexString contains theBadString) then
		set theGoodString to "'"
		set savedTextItemDelimiters to AppleScript's text item delimiters
		-- replace theBadString with theGoodString in theBibtexString
		set AppleScript's text item delimiters to theBadString
		set the text_item_list to every text item of theBibtexString
		set AppleScript's text item delimiters to theGoodString
		set theNewBibtexString2 to the text_item_list as string
		set AppleScript's text item delimiters to savedTextItemDelimiters
	else
		set theNewBibtexString2 to theBibtexString
	end if
	--display dialog "cleanBibtexString: " & theNewBibtexString2 buttons {"¥"} default button 1 giving up after 8
	return theNewBibtexString2
end cleanBibtexString
-------------------------

