#!/usr/bin/python

################################################################################
# usage: session2html.py [-h] -s SESSION_FILE [-o OUTPUT_FILE]
#
# Convert Firefox sessionstore.js file to html.
#
# optional arguments:
#   -h, --help       show this help message and exit
#   -s SESSION_FILE  session file to be converted
#   -o OUTPUT_FILE   write html output to OUTPUT_FILE; if not defined write html
#                    output to stdout
################################################################################


import os, sys, json, time, argparse
from xml.sax.saxutils import escape

html_escape_table = {
    '"': "&quot;",
    "'": "&apos;"
}

# escapes this characters: '&', '<', '>', '"', and ''' 
def html_escape(text):
    return escape(text, html_escape_table)

# parse script arguments
desc="Convert Firefox sessionstore.js file to html."
parser = argparse.ArgumentParser(description=desc)
parser.add_argument("-s", dest="sessionfile", type=argparse.FileType('r'), 
      metavar="SESSION_FILE", required=True, help="session file to be converted")
parser.add_argument("-o", dest="outputfile", type=argparse.FileType('w'),
      default=sys.stdout, metavar="OUTPUT_FILE", help="write html output \
      to OUTPUT_FILE; if not defined write html output to stdout")    
args = parser.parse_args()

# read session file and parse it to json structure
ss = json.loads(args.sessionfile.read().decode("utf-8"))


mtimeInfo = "<p>File mtime {0}</p>".format(
      time.ctime(os.stat(args.sessionfile.name).st_mtime))

lastUpdateInfo = ""
if "session" in ss:
    if "lastUpdate" in ss["session"]:
        lastUpdateInfo = "<p>Recorded session.lastUpdate {0}</p>".format(
              time.ctime(ss["session"]["lastUpdate"]/1000.0))



args.outputfile.write("""
<html>
<head>
 <meta http-equiv="Content-type" content="text/html; charset=utf-8">
 <title>Open Tabs from session file</title>
</head>
<body>
<h1>Open Tabs from Session File</h1>
{0}
{1}
<ul style="list-style-type:none">
""".format(mtimeInfo, lastUpdateInfo))

counter = 1
## LL addition of pcount: count pages
pcount = 0
wcount = 0
for window in ss["windows"]:
    ## LL additions: keep a running count of pages,
    ## try to separate windows
    pline = '<p> Page Count: '+str(pcount)+' </p>'
    args.outputfile.write(pline)
    args.outputfile.write('<hr>\n')
    args.outputfile.write('<p> ------- New Window '+str(wcount)+' ------- </p> \n')
    wcount += 1
    wpcount = 0
##   print '<p> Page Count: ',pcount,'</p>'
    for tab in window["tabs"]:
        entries = tab["entries"]
        args.outputfile.write('<li>#{0} in window {1}<ul style="list-style-type:none">'.format(
              counter, wcount))
        for entry in entries:
            url = entry["url"].encode("utf-8")
            title = html_escape(entry.get("title", url)).encode("utf-8")
            line = '<li><a href="{0}">{1}</a> : <tt>{2}</tt></li>\n'.format(
                  url, title, url)
            args.outputfile.write(line)
        args.outputfile.write("</ul>")
##        print "tabs processed: {0}".format(counter)
##        print "window tabs processed: {0}".format(wpcount)
        print "windows processed: {0}".format(wcount)
        counter += 1
        pcount += 1
        wpcount += 1
        args.outputfile.write("""
</ul>
<p></p>
</body>
</html>
"""
)
args.outputfile.close()
