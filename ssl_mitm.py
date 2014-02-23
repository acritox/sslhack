#!/usr/bin/env python
import sys, socket, ssl, select, os.path

if len(sys.argv) != 5:
    print "Usage: " + sys.argv[0] + " <[bindaddr:]port> <certificate.pem> <key.pem> <target[:port]>\n"
    exit(1)

bind = sys.argv[1].split(":")
if len(bind) == 2:
    BINDADDR = bind[0]
    BINDPORT = int(bind[1])
else:
    BINDADDR = '0.0.0.0'
    BINDPORT = int(bind[0])
target = sys.argv[4].split(":")
if len(target) == 2:
    TARGETADDR = target[0]
    TARGETPORT = int(target[1])
else:
    TARGETADDR = target[0]
    TARGETPORT = BINDPORT
CERTFILE = sys.argv[2]
KEYFILE = sys.argv[3]
if not os.path.isfile(CERTFILE):
    print "Error: certificate file " + CERTFILE + " does not exist!\n"
    exit(1)
if not os.path.isfile(KEYFILE):
    print "Error: private key " + KEYFILE + " does not exist!\n"
    exit(1)

bindsocket = socket.socket()
bindsocket.bind((BINDADDR, BINDPORT))
bindsocket.listen(5)

print "Listening for connections on " + BINDADDR + ":" + str(BINDPORT) + " ..."

def deal_with_client(connstream):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    ssl_sock = ssl.wrap_socket(s)
    ssl_sock.connect((TARGETADDR, TARGETPORT))
    socks = [ssl_sock,connstream]
    # null data means the client is finished with us
    while True:
        try:
            inputready,outputready,exceptready = select.select(socks,[],[],5)
            for sin in inputready:
                if sin == connstream:
                    data = connstream.read()
                    if not data: return
                    print data
                    ssl_sock.write(data)
                elif sin == ssl_sock:
                    data = ssl_sock.read()
                    if not data: return
                    print data
                    connstream.write(data)
                else:
                    return
        except KeyboardInterrupt:
            exit(0)

while True:
    try:
        newsocket, fromaddr = bindsocket.accept()
        connstream = ssl.wrap_socket(newsocket,
                                 server_side=True,
                                 certfile=CERTFILE,
                                 keyfile=KEYFILE,
                                 ssl_version=ssl.PROTOCOL_TLSv1)
    except KeyboardInterrupt:
        break
    try:
        deal_with_client(connstream)
    finally:
        connstream.shutdown(socket.SHUT_RDWR)
        connstream.close()

