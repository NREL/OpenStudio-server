import requests

URL = 'http://127.0.0.1/'
f = open('/opt/openstudio/server/spec/files/mongodump_1651085721.tar.gz', 'rb')
files = {"file": ("mongodump_1651085721.tar.gz", f)}
r = requests.post(url=URL+'admin/restore_database', files=files)
print(r.json)

