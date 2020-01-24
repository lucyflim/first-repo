#! /usr/bin/env python3

################################################################################
# usage: session2htmlp3.py [-h] -s SESSION_FILE [-o OUTPUT_FILE]
# example: 
# $ python3 session2htmlp3.py -s recovery.jsonlz4 -o recovery-out.html
#
# Convert Firefox recovery.jsonlz4 file to html.
#
# optional arguments:
#   -h, --help       show this help message and exit
#   -s SESSION_FILE  session file to be converted
#   -o OUTPUT_FILE   write html output to OUTPUT_FILE; if not defined write html
#                    output to stdout
################################################################################

# "This Python 3 script requires the LZ4 bindings for Python, see: https://pypi.python.org/pypi/lz4"
#
# make sure lz4 for python is installed:
# $ conda install lz4
#
import os, sys, json, time, argparse, lz4.block
import pathlib
from xml.sax.saxutils import escape

html_escape_table = {
    '"': "&quot;",
    "'": "&apos;"
}

# escapes this characters: '&', '<', '>', '"', and ''' 
def html_escape(text):
    return escape(text, html_escape_table)

# parse script arguments
##desc="Convert Firefox sessionstore.js file to html."
desc="Convert Firefox recovery.jsonlz4 file to html."
parser = argparse.ArgumentParser(description=desc)
parser.add_argument("-s", dest="sessionfile", type=argparse.FileType('r'), 
      metavar="SESSION_FILE", required=True, help="session file to be converted")
parser.add_argument("-o", dest="outputfile", type=argparse.FileType('w'),
      default=sys.stdout, metavar="OUTPUT_FILE", help="write html output \
      to OUTPUT_FILE; if not defined write html output to stdout")    
args = parser.parse_args()

# debugging
# print(parser.parse_args())
# print(args.sessionfile)
# print(args.sessionfile.name)

# read session file and parse it to json structure
# decompress if necessary
# "This file format is in fact just plain LZ4 data with a custom header (magic number [8 bytes] and
#  uncompressed file size [4 bytes, little endian])."
#
##ss = json.loads(args.sessionfile.read().decode("utf-8"))
bytfile = args.sessionfile.name
print(bytfile)
#byt = read_bytes(bytfile)

#byt = args.sessionfile.read_bytes()
bytpath = pathlib.Path.cwd() / bytfile
byt = bytpath.read_bytes()
if byt[:8] == b'mozLz40\0':
    print(byt[:8])
    sstxt = lz4.block.decompress(byt[8:])
    ss = json.loads(sstxt)

mtimeInfo = "<p>File mtime {0}</p>".format(
      time.ctime(os.stat(args.sessionfile.name).st_mtime))

mtimeInfo2 = " {0} ".format(
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
 <title>Open Tabs from session file: {2} </title>
</head>
<body>
<h1>Open Tabs from Session File </h1>
{0}
{1}
<ul style="list-style-type:none">
""".format(mtimeInfo, lastUpdateInfo, mtimeInfo2))

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
    wcount += 1
    args.outputfile.write('<p> ------- New Window '+str(wcount)+' page count '+str(pcount)+' ------- </p> \n')
    wpcount = 0
    print("windows processed: {0}".format(wcount))
    for tab in window["tabs"]:
        entries = tab["entries"]
        args.outputfile.write('<li>#{0} in window {1}<ul style="list-style-type:none">'.format(
              counter, wcount))
        for entry in entries:
#            url = entry["url"].encode("utf-8")  # utf-8 encoding not needed in python3
            url = entry["url"]
#            title = html_escape(entry.get("title", url)).encode("utf-8")
            title = html_escape(entry.get("title", url))
            line = '<li><a href="{0}">{1}</a> : <tt>{2}</tt></li>\n'.format(
                  url, title, url)
            args.outputfile.write(line)
        args.outputfile.write("</ul>")
##        print "tabs processed: {0}".format(counter)
##        print "window tabs processed: {0}".format(wpcount)
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
