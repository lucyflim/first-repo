-- Applescript for Bibdesk
-- Extract the arXiv ID from the arXiv PDF and create a .bib entry based on arXiv info
-- adapted from  @konn/arXiv to BibDesk-BibLaTeX.scpt 
-- @konn's script did all of the XML to BibTeX conversion
--  https://gist.github.com/konn/bc7b5c45f1bd1b8b1bca.js

property arxivPrefixes : {"http://www.arxiv.org/", "http://arxiv.org/", "https://www.arxiv.org/", "https://arxiv.org/"}

--on run
--	tell application "Safari"
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
		tell thePub
			set theCount to count of (get linked files)
			--return theCount
			--display dialog "File Count " & theCount buttons {"¥"} default button 1 giving up after 4
			set theAlreadyLinkedFiles to " "
			if theCount = 0 then error
			if theCount > 0 then
				--set theAlreadyLinkedFiles to the POSIX path of (get linked files)
				set theAlreadyLinkedFiles to (get linked files)
				set theFirstLinkedFile to item 1 of theAlreadyLinkedFiles
				set theFirstFile to the POSIX path of theFirstLinkedFile
				-- display dialog theFirstFile buttons {"¥"} default button 1 giving up after 4
				-- Extract the ID from the first linked file using pdftotext and sed
				set theIDString to my findArxivID(theFirstFile)
				if theIDString is "" then
					-- display dialog theIDString buttons {"¥"} default button 1 giving up after 4
					set theIDString to my findArxivID2(theFirstFile)
				end if
				
				--				set value of field "Doi" to my removebrackets(theIDString)
				--return theDOIString
			end if
		end tell
	end tell
	--	get value of field "Url" of thePub
	--	set theURL to result as string
	--	display dialog theURL buttons {"¥"} default button 1 giving up after 4
	-- set theURL to URL of the first document as string
end tell
--display dialog arxivPrefixes buttons {"¥"} default button 1 giving up after 4
--set pathComps to split("/", nthElement(arxivPrefixes, 2, theURL))
--display dialog pathComps buttons {"¥"} default button 1 giving up after 4
--set c to count of pathComps
--main(join("/", items 2 thru c of pathComps))
--main(theURL)
main(theIDString)
--end run

on parseDate(val)
	set dateTxt to val as string
	set oldDelim to AppleScript's text item delimiters
	set AppleScript's text item delimiters to {"T"}
	set datePart to the first text item of dateTxt
	set AppleScript's text item delimiters to oldDelim
	return datePart
end parseDate

on main(ident)
	--display dialog ident buttons {"¥"} default button 1 giving up after 4
	
	tell application "System Events"
		log ident
		set tmpPath to path to temporary items from system domain
		set tmpPathPOSIX to POSIX path of tmpPath
		set rndName to do shell script "uuidgen"
		set tmpFile to tmpPathPOSIX & "/" & rndName & ".xml"
		
		set uri to ("http://export.arxiv.org/api/query?id_list=" & ident)
		--		display dialog uri buttons {"¥"} default button 1 giving up after 4
		set src to do shell script ("curl -s '" & uri & "' > " & tmpFile) as text
		try
			set xmlDoc to XML file tmpFile
			tell the first XML element of xmlDoc
				set theEntry to XML element "entry"
				tell theEntry
					set theTitle to (the value of the XML element "title") as text
					set updated to parseDate(the value of the XML element "updated") of me
					set published to parseDate(the value of the XML element "published") of me
					set abst to the value of the XML element "summary" as string
					set cat to the value of the XML attribute "term" of the XML element "arxiv:primary_category" as string
					set theJournal to ""
					--set theJournal to "arXiv"
					if the (count of (every XML element whose name is "arxiv:journal_ref" as list)) > 0 then
						set theJournal to the value of the XML element "arxiv:journal_ref"
					end if
					set now to current date
					set dois to (every XML element whose name is "arxiv:doi") as list
					set theDoi to ""
					if (count of dois) > 0 then
						set theDoi to the value of the XML element "arxiv:doi" as string
					end if
					set visited to {the year of now, the month of now as number, the day of now}
					set authorItems to every XML element whose name is "author"
					set theAuthors to {}
					repeat with anAuthor in authorItems
						set theAuthors to theAuthors & {the value of the first XML element of anAuthor as Unicode text}
					end repeat
					set revision to my nthElement("v", 2, my nthElement("/", 2, ident)) as number
					tell the first document of application "BibDesk"
						--
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
							end if
						end tell
						
						--
						set authorTxt to my join(" and ", theAuthors)
						set props to {title:theTitle, abstract:abst}
						set newpub to make new publication with properties props at the beginning of publications
						tell newpub
							if theJournal is not "" then
								set type of newpub to "article"
								set the value of field "journaltitle" to theJournal
							else
								set type of newpub to "online"
								set theJournal to "arXiv"
							end if
							set the value of field "date" to updated
							set the publication year to my nthElement("-", 1, updated)
							set the publication month to my nthElement("-", 2, updated)
							set the value of field "day" to my nthElement("-", 3, updated)
							set the value of field "author" to authorTxt as Unicode text
							set the value of field "eprinttype" to "arxiv"
							set the value of field "urldate" to my join("-", visited)
							set the value of field "eprint" to ident
							if theDoi is not "" then
								set the value of field "doi" to theDoi
							end if
							if cat is not "" then
								set the value of field "eprintclass" to cat
							end if
							set the value of field "version" to revision
							set cite key to its generated cite key
							show
						end tell
						tell thePub
							-- Now that the linked file list and abstract have been copied into the "newPub", we can overwrite every field in "ThePub"
							-- Copy all the fields in "newPub" into the original entry "ThePub"
							set theNewFields to every field of newpub
							repeat with theField in every field of newpub
								set fieldName to name of theField
								--return fieldName
								set value of field fieldName of thePub to (get value of field fieldName of newpub)
							end repeat
							
							set isjournal to the value of field "journal" of thePub
							if isjournal is "" then set the value of field "journal" of thePub to "arXiv"
							
							get the cite key of newpub
							set newCiteKey to result
							--return newCiteKey
							set cite key of thePub to newCiteKey
							
						end tell
						remove newpub
					end tell
				end tell
			end tell
		on error e
			log ("error! " & e)
		end try
		do shell script ("rm " & tmpFile)
		tell application "BibDesk" to activate
	end tell
end main

on join(s, targ)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to s
	set answer to targ as string
	set AppleScript's text item delimiters to oldDelims
	return answer
end join


on split(s, targ)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to s
	set theList to every text item of targ
	set AppleScript's text item delimiters to oldDelims
	return theList
end split

on nthElement(s, n, targ)
	set theList to split(s, targ)
	if (count of items of theList) ³ n then
		set targ to item n of theList
	else
		set targ to ""
	end if
	return targ
end nthElement


on findArxivID(theFilename)
	-- let's get a little more sophisticated and at least use grep
	-- Relies on the Arxiv ID to be in the very first line of the output of pdftotext
	--	set theSedSlashCommand to "sed -n -e " & theSedslashString
	--	set TheCommand to "/opt/local/bin/xpdf-pdftotext -l 1 " & quoted form of theFilename & " - | head -n 1"
	-- display dialog theFilename buttons {"¥"} default button 1 giving up after 4
	-- set TheCommand to "/usr/local/bin/pdftotext -l 1 " & quoted form of theFilename & " - | head -n 1"
	set TheCommand to "/usr/local/bin/pdftotext -l 1 " & quoted form of theFilename & " - | grep -i arxiv | head -n 1"
	-- & theSedSlashCommand
	do shell script TheCommand
	set theIDString to result
	-- display dialog "theIDString " & theIDString buttons {"¥"} default button 1 giving up after 4
	
	if theIDString is not "" then
		set oldDelims to AppleScript's text item delimiters
		set AppleScript's text item delimiters to "arXiv:"
		--	set theList to every text item of theIDString
		set theList to the second text item of theIDString
		-- display dialog theList buttons {"¥"} default button 1 giving up after 4
		set AppleScript's text item delimiters to " "
		set theIDonly to the first text item of theList
		-- display dialog theIDonly buttons {"¥"} default button 1 giving up after 4
		set AppleScript's text item delimiters to oldDelims
	else
		set theIDonly to ""
	end if
	return theIDonly
end findArxivID

on findArxivID2(theFilename)
	-- ok - if the first way didn't work, try just grabbing the filename
	
	-- display dialog theFilename buttons {"¥"} default button 1 giving up after 4
	
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "/"
	--	set theList to every text item of theIDString
	set theList to the last text item of theFilename
	-- display dialog theList buttons {"¥"} default button 1 giving up after 4
	set AppleScript's text item delimiters to ".pdf"
	set theIDonly to the first text item of theList
	-- display dialog theIDonly buttons {"¥"} default button 1 giving up after 4
	set AppleScript's text item delimiters to oldDelims
	return theIDonly
end findArxivID2