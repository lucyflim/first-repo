#!/usr/bin/python

## Usage:
##  $ python sstore2html.py -s recovery.js -o recovery-output.html
##   will read the "recovery.js" file and output to "recovery-output.html"
##
##   python sstore2html.py -o session-output.html
##   will read the "sessionstore.js" file and output to "session-output.html"
##   without the -o argument, the html just goes to stdout

# warner / make-html.py
# Created 2012-05-13

# turn a firefox sessionstore.js into an HTML page

# https://gist.github.com/warner/2690106

import os, sys, json, time
from twisted.python import usage
class Usage(usage.Options):
   optParameters = [
       ("sessionfile", "s", None, "sessionstore.js to read, uses new-b9 profile by default"),
       ("outfile", "o", "-", "write tabs.html to here"),
       ]
   def postOptions(self):
       if self["sessionfile"] is None:
            self["sessionfile"] = "./sessionstore.js"
#            self["sessionfile"] = os.path.expanduser("~/Library/Application Support/Firefox/Profiles/sjkwtbb1.new-b9/sessionstore.js")
       self.sessionfile = open(self["sessionfile"], "rb")
       if self["outfile"] == "-":
           self.outfile = sys.stdout
       else:
           self.outfile = open(self["outfile"], "wb")
o = Usage()
o.parseOptions()

ss = json.loads(o.sessionfile.read().decode("utf-8"))

o.outfile.write("""
<html>
<head>
<meta http-equiv="Content-type" content="text/html; charset=utf-8">
<title>Open Tabs from session file</title>
</head>
<body>
<h1>Open Tabs from Session File</h1>
<p>File mtime %s, Recorded session.lastUpdate %s</p>
<ul>
""" % (time.ctime(os.stat(o["sessionfile"]).st_mtime),
      time.ctime(ss["session"]["lastUpdate"]/1000.0))
               )

urls = []
pcount = 0
for w in ss["windows"]:
   pline = '<p> Page Count: '+str(pcount)+' </p>'
   o.outfile.write(pline)
   o.outfile.write('<hr>\n')
   o.outfile.write('<p> ------- New Window ------- </p> \n')
   wpcount = 0
##   print '<p> Page Count: ',pcount,'</p>'
   for t in w["tabs"]:
      try:
             e = t["entries"][t["index"]-1]
             url = e["url"]
      ## LL addition to try to fix blank title problem
      ##       title = e["title"]
             title = e.get('title', 'Missing: title')
             line = ' <li><a href="%s">%s</a> : <tt>%s</tt></li>\n' % \
                   (url, title, url)
      ##             (e["url"], e["title"], e["url"])
      ##             (e["url"], e.get('title', 'Missing: title'), e["url"])
             o.outfile.write(line.encode("utf-8"))
             pcount = pcount+1
             wpcount = wpcount+1
             print ' Window Page Count: ',wpcount
             o.outfile.write('Window Page Count: '+str(wpcount)+' \n <br> ')
             #print e["title"]
             #print e["url"]
             #print   
      except IndexError:
             print ' Index Error '             
             print ' Window Page Count: ',wpcount             
             o.outfile.write('Index Error,  Window Page: '+str(wpcount))
o.outfile.write('\n')
pline = '<p> Page Count: '+str(pcount)+' </p> \n'
o.outfile.write(pline)
print 'Page Count: ',pcount
o.outfile.write("""
</ul>
<p></p>
</body>
</html>
"""
)
o.outfile.close()
