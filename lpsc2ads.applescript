-- Applescript for BibDesk
-- Extract the LPSC year from the PDF, then use curl to download ADS BibTeX record
-- pdftotext or xpdf-pdftotext must be on your system somewhere
--2021-02-10: replace path for pdftotext, version lpsc2ads4b
--2021-02-09: ADS API token, version lpsc2ads4
--2021-02-08: fix to work with new ADS

tell application "BibDesk"
	-- without document, there is no selection, so nothing to do
	if (count of documents) = 0 then
		beep
		display dialog "No documents found." buttons {"¥"} default button 1 giving up after 3
	end if
	set theDoc to document 1
	--set theName to the name of selection -- usually the publication's title, if this is an editor window
	
	tell theDoc
		set theAlreadyLinkedFiles to " "
		set theSel to selection
		set thePub to item 1 of theSel
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
				
				set theSedString to "'s_.*Lunar and Planetary Science.*(\\([[:digit:]][[:digit:]][[:digit:]][[:digit:]]\\).*_\\1_p'"
				--return theSedString
				set theSedCommand to "sed -n -e " & theSedString
				--set theGrepCommand to " grep -i doi "
				-- make sure the path here points to a valid pdftotext on your system
				-- (type which pdftotext or which xpdf-pdftotext at a terminal prompt to get the path)
				--set TheCommand to "/sw/bin/pdftotext -l 1 " & quoted form of theFirstFile & " - | " & theSedCommand
				set TheCommand to "/usr/local/bin/pdftotext -f 2 " & quoted form of theFirstFile & " - | " & theSedCommand
				set TheCommand to "/usr/local/bin/pdftotext -l 1 " & quoted form of theFirstFile & " - | " & theSedCommand
				
				--return TheCommand
				do shell script TheCommand
				set theLPSCString to result
				--return theLPSCString
				set theLPSCYear to theLPSCString as integer
				if theLPSCYear is greater than 1969 then
					--return theLPSCYear
					set theLPSCNumber to theLPSCYear - 1969
					--return theLPSCNumber
					set theLPSCNumberString to theLPSCNumber as string
					set theSedString2 to "'s_.*\\([[:digit:]][[:digit:]][[:digit:]][[:digit:]]\\).pdf_\\1_p'"
					set theSedCommand2 to "sed -n -e " & theSedString2
					--set TheCommand to "/opt/local/bin/xpdf-pdftotext -l 1 " & quoted form of theFirstFile & " - | " & theSedCommand2
					set TheCommand to "/usr/local/bin/pdftotext -l 1 " & quoted form of theFirstFile & " - | " & theSedCommand2
					
					do shell script TheCommand
					set theAbstractNumberString to the result
					--return theAbstractNumberString
					set theADSString to theLPSCString & "LPI...." & theLPSCNumberString & "." & theAbstractNumberString
					-- in 2013 the format was changed to "2013LPICo1719.2865W".  Hard-coding the "1719" instead of the LPSC meeting number is a kluge.
					-- They changed it back by 2014... not sure when
					--if theLPSCYear is greater than 2012 then
					--if theLPSCYear is 2013 then
					--	set theADSString to theLPSCString & "LPICo" & "1719" & "." & theAbstractNumberString
					--					end if
					
					--return theADSString
				end if
			end if
		end tell
		--display dialog "LPSC " & theADSString buttons {"¥"} default button 1 giving up after 3
		
		set theExistingAdsurl to value of field "Adsurl" of thePub
		--	if "adsabs" is not in theExistingAdsurl then
		-- set adsurlName to "http://adsabs.harvard.edu/abs/" & theADSString
		set adsurlName to "https://api.adsabs.harvard.edu/v1/search/query?q=" & theADSString & "*&fl=bibcode"
		
		--But wait, there's more!  The ADS LPSC codes give an additional "magic letter" at the end of the bibcode, which is the first letter of the first author's last name.  The old ADS would resolve this for you if you gave the code without the magic letter, but it wouldn't give you the BibTeX without it.  So we had to scrape the "real" URL from the ADS page.
		-- how to do this with the new ADS?
		-- Look for the line containing "bibcode" and pass it to sed
		-- set TheCommand to "curl " & the quoted form of adsurlName & " | " & "grep -i 'name=\"bibcode\"'"
		--curl -H 'Authorization: Bearer:PMH0qE0KEbsBmP9fwDQZJrXjtAatejF8ioSHa2mQ' 'https://api.adsabs.harvard.edu/v1/search/query?q=star&fl=bibcode'
		set theAuthString to "Authorization: Bearer:PMH0qE0KEbsBmP9fwDQZJrXjtAatejF8ioSHa2mQ"
		set TheCommand to "curl -H " & the quoted form of theAuthString & " " & the quoted form of adsurlName & " | " & "grep -i \"bibcode\\\":\"" --return TheCommand
		--display dialog TheCommand buttons {"¥"} default button 1 giving up after 4
		
		do shell script TheCommand
		set theFirstADSString to the result
		--return theFirstADSString
		--display dialog theFirstADSString buttons {"¥"} default button 1 giving up after 4
		
		if theFirstADSString = "" then
			beep
			set theMessage to "No ADS info downloaded." & TheCommand
			display dialog theMessage buttons {"¥"} default button 1 giving up after 4
			--return theNewBibtexString
		else
			--eliminate carriage returns
			if (theFirstADSString contains (ASCII character 13)) then
				set savedTextItemDelimiters to AppleScript's text item delimiters
				-- replace theBadString with theGoodString in theBibtexUrl
				set AppleScript's text item delimiters to ASCII character 13
				set theFirstADSString to the first text item of theFirstADSString
				set AppleScript's text item delimiters to savedTextItemDelimiters
			end if
			
			--display dialog theFirstADSString buttons {"¥"} default button 1 giving up after 4
			
			--set theSedString3 to "'s_.*name=\"bibcode\" value=\"\\([[:digit:]][[:digit:]][[:digit:]][[:digit:]]\\)\"_\\1_p'"
			--set theSedString3 to "'s_.*value=.*\\([[:digit:]][[:digit:]][[:digit:]][[:digit:]].*[[:digit:]][[:digit:]][[:digit:]][[:digit:]].*\\)\".*_\\1_p'"
			set theSedString3 to "'s_.*bibcode.*\\([[:digit:]][[:digit:]][[:digit:]][[:digit:]].*[[:digit:]][[:digit:]][[:digit:]][[:digit:]].*\\)\".*_\\1_p'"
			-- in 2013 the format was changed to "2013LPICo1719.2865W", so there are three sets of four numbers, not just two
			--			if theLPSCYear is greater than 2012 then
			--				set theSedString3 to "'s_.*value=.*\\([[:digit:]][[:digit:]][[:digit:]][[:digit:]].*[[:digit:]][[:digit:]][[:digit:]][[:digit:]].*[[:digit:]][[:digit:]][[:digit:]][[:digit:]].*\\)\".*_\\1_p'"
			--end if
			set theSedCommand3 to "sed -n -e " & theSedString3
			--return theSedString3
			set TheCommand to "echo " & the quoted form of theFirstADSString & " | " & theSedCommand3
			--return TheCommand
			--display dialog TheCommand buttons {"¥"} default button 1 giving up after 4
			do shell script TheCommand
			set theSecondADSString to the result
			--return theSecondADSString
			set adsurlName to "http://adsabs.harvard.edu/abs/" & theSecondADSString
		end if
		
		set value of field "Adsurl" of thePub to adsurlName
		--	end if
		
		
		-- From here on out it used to be identical to "getDOIfromPDF_4.scpt"
		
		get value of field "Adsurl" of thePub
		set theAdsurl to result as string
		if theAdsurl is "" then
			beep
			set theMessage to "No Adsurl"
			display dialog theMessage buttons {"¥"} default button 1 giving up after 3
			
		else
			-- Download the BibTeX information from ADS
			-- 2021-02-08 replacement code from getDOIfromPDF_newads3 to deal with new ADS:
			-- Download the BibTeX information from ADS
			set theBibtexUrl to my getADSBibtexUrl(theAdsurl)
			--display dialog "toplevel theBibtexUrl: " & theBibtexUrl buttons {"¥"} default button 1 giving up after 7
			-- 2019: edit the curl command to handle redirects
			
			set theNewBibtexString to my getBibtexEntry(theBibtexUrl)
			--display dialog theNewBibtexString buttons {"¥"} default button 1 giving up after 7
			
			
			--remove/decode the external "&#34;" quote codes, otherwise the new pub can't be created:
			set theNewBibtexString2 to my cleanBibtexString(theNewBibtexString)
			--display dialog theNewBibtexString2 buttons {"¥"} default button 1 giving up after 7
			--display dialog "toplevel: theNewBibtexString 1  %%%" & theNewBibtexString & "%%%" buttons {"¥"} default button 1 giving up after 6
			--display dialog "toplevel: theNewBibtexString 2  %%%" & theNewBibtexString2 & "%%%" buttons {"¥"} default button 1 giving up after 6
			
			--set theNewBibtexString2 to theNewBibtexString
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
				
				set newPub to make new publication with properties {BibTeX string:theNewBibtexString2} at end of publications
				--set theMessage to "New Pub created"
				--display dialog theMessage buttons {"¥"} default button 1 giving up after 4
				
				-- Preserve the original entry's linked file list
				set theAlreadyLinkedFiles to linked files of thePub
				--set theMessage to "LinkedFiles: " & theAlreadyLinkedFiles
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
					--set theMessage to "theAdsurl: " & theAdsurl
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
				
				-- end of code from getDOIfromPDF_newads3
				-- the rest of this is unchanged
				
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
				
				get value of field "Adsurl" of thePub
				set pasteItem to result as string
				set urlName to pasteItem
				tell thePub
					-- generate a new value for the field, we use the "Url" field as a dummy
					if (urlName is not "") and (urlName is not in (get linked URLs)) then 
						add urlName to end of linked URLs
					end if
				end tell
				
				-- set the value of "Journal" to "LPSC" because this is not done automatically
				-- "Journal" is used for type "Article" but not "inproceedings"
				-- "Journal" only gets used to autofile the files 
				set value of field "Journal" of thePub to "LPSC"
				
				remove newPub
			end if
		end if
	end tell
end tell


-- end of the main program

-------------------------
-------------------------
-- subroutines from getDOIfromPDF_newads3.applescript
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
	--set theFile2 to "~/Documents/BibdeskPapers/curlsedtest2019c.txt"
	--set theFile3 to "~/Documents/BibdeskPapers/curlsedtest2019d.txt"
	--set TheCommand2 to "curl '" & theBibtexUrl & "'" & " >>  " & theFile2
	--do shell script TheCommand2
	--set TheCommand2 to "curl '" & theBibtexUrl & "'" & " | sed -e '/<textarea/','/<\\/textarea>/!d' "
	--do shell script TheCommand2
	--set theBibtexString2 to the result
	-------------------------
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
