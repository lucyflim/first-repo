-- Applescript for BibDesk
-- Extract the DOI information from the PDF
-- 2020-01-27 (v6): replace on findDOI() with the new on findDOI() 
--  from "getDOIfromPDF_newADS"; 
--   new version uses the crossref-recommended DOI regex first 


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
				set theAlreadyLinkedFiles to " "
				if theCount = 0 then error
				if theCount > 0 then
					--set theAlreadyLinkedFiles to the POSIX path of (get linked files)
					set theAlreadyLinkedFiles to (get linked files)
					set theFirstLinkedFile to item 1 of theAlreadyLinkedFiles
					set theFirstFile to the POSIX path of theFirstLinkedFile
					-- Extract the DOI from the first linked file using pdftotext and sed
					set theDOIString to my findDOI(theFirstFile)
					set value of field "Doi" to my removebrackets(theDOIString)
				end if
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
			if "adsabs" is not in theExistingAdsurl then
				set adsurlName to "http://adsabs.harvard.edu/doi/" & theDOIString2
				set value of field "Adsurl" of thePub to adsurlName
			end if
		end if
		
		-- Now use the DOI URL to fill out the Bibdesk record for this publication.
		-- First save the existing values of every field so they won't be overwritten by the new information:
		--- 1. construct "newPub" with the new DOI values
		--- 2. copy thePub's linked URL and linked file lists to newPub, along with the abstract, if any
		--- 3. overwrite all fields of "thePub" from newPub
		--- 4. delete the now-redundant newPub.
		
		get value of field "Doi" of thePub
		set theDoi to result as string
		if theDoi is "" then
			beep
			set theMessage to "No Doi"
			display dialog theMessage buttons {"¥"} default button 1 giving up after 3
			
		else
			-- Download the BibTeX information from dx.doi.org
			set theDoiUrl to "http://dx.doi.org/" & theDoi
			set theDoiBibTexString to "Accept: text/bibliography; style=bibtex"
			set TheCommand to "curl -LH " & the quoted form of theDoiBibTexString & " " & the quoted form of theDoiUrl
			
			--display dialog TheCommand buttons {"¥"} default button 1 giving up after 4
			do shell script TheCommand
			set theNewBibtexString to the result
			display dialog theNewBibtexString buttons {"¥"} default button 1 giving up after 4
			if theNewBibtexString = "" then
				beep
				set theMessage to "No Doi BibTeX downloaded." & TheCommand
				display dialog theMessage buttons {"¥"} default button 1 giving up after 4
				--return theNewBibtexString
			else
				--return theNewBibtexString
				-- Temporarily stash the ADS results in "newPub"
				set newPub to make new publication with properties {BibTeX string:theNewBibtexString} at end of publications
				
				-- Preserve the original entry's linked file list
				set theAlreadyLinkedFiles to linked files of thePub
				tell newPub
					make new linked file with data theAlreadyLinkedFiles at end of linked files
				end tell
				-- Preserve the original entry's abstract, if it has one
				-- If the original entry doesn't already have an abstract, fill it from ADS
				set theExistingAbstract to the abstract of thePub
				if theExistingAbstract is not "" then
					set the abstract of newPub to theExistingAbstract
				else
					
				end if
				
				
				-- Now that the linked file list and abstract have been copied into the "newPub", we can overwrite every field in "ThePub"
				-- Copy all the fields in "newPub" into the original entry "ThePub"
				set theNewFields to every field of newPub
				repeat with theField in every field of newPub
					set fieldName to name of theField
					set value of field fieldName of thePub to (get value of field fieldName of newPub)
				end repeat
				get the cite key of newPub
				set newCiteKey to result
				set cite key of thePub to newCiteKey
				
				-- Copy the ADS URL from its own special field to the "normal" list of linked URLs
				get value of field "Adsurl" of thePub
				set pasteItem to result as string
				set Adsurl to pasteItem
				
				remove newPub
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
	--display dialog TheCommand buttons {"«"} default button 1 giving up after 5
	do shell script TheCommand
	set theDOIString to result
	--return theDOIString
	
	--display dialog theDOIString buttons {"«"} default button 1 giving up after 3
	
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
		--display dialog TheCommand buttons {"«"} default button 1 giving up after 5
		do shell script TheCommand
		set theDOIString to result
		--return theDOIString
	end if
	
	--display dialog theDOIString buttons {"«"} default button 1 giving up after 3
	
	-- Fall back to a simpler DOI
	-- Any number of digits + a period + any number of alphanumeric characters + a solidus + at least one of  (alphanumeric characters, parentheses, periods, or dashes) 
	-- Also, artifically add a "doi" to the front of the resulting string to use later as a delimiter	
	
	if theDOIString = "" then
		display dialog "No DOI found.  Retrying" buttons {"«"} default button 1 giving up after 3
		set theSedString to "'s_.*[Dd][Oo][Ii][:)] *\\([[:digit:]][[:digit:]]*.[[:alnum:])(.-]*/[[:alnum:])(.-][[:alnum:]):(.-]*[[:alnum:]-]\\).*_doi\\1_p'"
		
		--return theSedString
		set theSedCommand to "sed -n -e " & theSedString
		set theGrepCommand to " grep -i doi "
		set TheCommand to "/opt/local/bin/xpdf-pdftotext -l 1 " & quoted form of theFilename & " - | " & theSedCommand
		--return TheCommand
		do shell script TheCommand
		set theDOIString to result
		--display dialog theDOIString buttons {"«"} default button 1 giving up after 3
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
		--display dialog theDOIString buttons {"«"} default button 1 giving up after 3
	end if
	
	---- Keep this one ----
	if theDOIString = "" then
		beep
		display dialog "No DOI found." buttons {"«"} default button 1 giving up after 3
	else
		-- In case more than one DOI has been returned, select just the first one
		--display dialog theDOIString buttons {"«"} default button 1 giving up after 3
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
-------------------------