SSLhack
=======

various scripts to tamper with SSL certificates and SSL connections

fake_certificate.bash
---------------------

fetches an existing certificate and creates a fake certificate request (CSR)
that has the same information (Subject, Issuer, all X.509v3 extensions, ...) as
the original certificate, it only replaces the signature and public key section
with the keys of a new private key.  It also creates a fake CA certificate that
matches the original Issuer certificate in its Subject and Subject Key
Identifier.  Then the fake certificate request (CSR) is signed by the fake CA,
which results in a fake certificate that has all the information of the original
certificate (except modified signature and public key) and that validates
against the fake CA.

Dependencies:
* patched openssl (openssl_req_resign_rekey.patch)
* x509v3ext2req.pl

Usage:

    fake_certificate.bash <orig.crt|host[:port[:servername]]> [<fake.key> [fakeca.key>]]

Example:

    ./fake_certificate.bash www.google.com
    Generating RSA private key, 1024 bit long modulus
    e is 65537 (0x10001)
    Getting request Private Key
    Generating certificate request
    Generating RSA private key, 1024 bit long modulus
    e is 65537 (0x10001)
    Using configuration from tmpCA/ca.cnf
    Check that the request matches the signature
    Signature ok
    Certificate Details:
            Serial Number: 5606004509688922644 (0x4dcc8766513f0214)
            Validity
                Not Before: Feb 12 15:11:16 2014 GMT
                Not After : Jun 12 00:00:00 2014 GMT
            Subject:
                countryName               = US
                stateOrProvinceName       = California
                localityName              = Mountain View
                organizationName          = Google Inc
                commonName                = www.google.com
            X509v3 extensions:
                X509v3 Extended Key Usage: 
                    TLS Web Server Authentication, TLS Web Client Authentication
                X509v3 Subject Alternative Name: 
                    DNS:www.google.com
                Authority Information Access: 
                    CA Issuers - URI:http://pki.google.com/GIAG2.crt
                    OCSP - URI:http://clients1.google.com/ocsp
    
                X509v3 Subject Key Identifier: 
                    0D:EE:E4:01:CC:60:E3:BC:A4:67:6B:5D:75:83:D8:8F:3E:D6:97:55
                X509v3 Basic Constraints: critical
                    CA:FALSE
                X509v3 Authority Key Identifier: 
                    keyid:4A:DD:06:16:1B:BC:F6:68:B5:76:F5:81:B6:BB:62:1A:BA:5A:81:2F
    
                X509v3 Certificate Policies: 
                    Policy: 1.3.6.1.4.1.11129.2.5.1
    
                X509v3 CRL Distribution Points: 
    
                    Full Name:
                      URI:http://pki.google.com/GIAG2.crl
    
    Certificate is to be certified until Jun 12 00:00:00 2014 GMT (365 days)
    
    Write out database with 1 new entries
    Data Base Updated
    
    Original certificate for: /C=US/ST=California/L=Mountain View/O=Google Inc/CN=www.google.com
     certificate: www.google.com.crt
    
    Fake certificate request for: /C=US/ST=California/L=Mountain View/O=Google Inc/CN=www.google.com
     CSR file: fake-www.google.com.csr
     signed with private key: fake-www.google.com.key
    
    Fake certificate for: /C=US/ST=California/L=Mountain View/O=Google Inc/CN=www.google.com
     certificate: fake-www.google.com.crt
     private key: fake-www.google.com.key
     signed by: fakeCA-www.google.com.crt
    
    Fake CA certificate for: /C=US/O=Google Inc/CN=Google Internet Authority G2
     certificate: fakeCA-www.google.com.crt
     private key: fakeCA-www.google.com.key
     signed by: self-signed
    
    # openssl verify -CAfile fakeCA-www.google.com.crt fake-www.google.com.crt
    fake-www.google.com.crt: OK


x509v3ext2req.pl
----------------

copies the X.509v3 extensions from a DER-encoded certificate
into a DER-encoded certificate request (CSR)

Dependencies:
* apt-get install libmath-bigint-perl libdata-walk-perl
* Encoding/BER.pm and Encoding/BER/DER.pm

Usage:

    x509v3ext2req.pl <file.crt> <file.csr>

    
ssl_mitm.py
-----------

Usage:

    ssl_mitm.py <[bindaddr:]port> <certificate.pem> <key.pem> <target[:port]>

Example:

    ./ssl_mitm.py localhost:4443 fake-www.google.com.crt fake-www.google.com.key www.google.com:443
    Listening for connections on localhost:4443 ...
    GET / HTTP/1.1
    Host: www.google.com
    
    
    HTTP/1.1 302 Found
    Cache-Control: private
    Content-Type: text/html; charset=UTF-8
    Location: https://www.google.de/?gfe_rd=cr&ei=9ikKU56iO8qK8QeoroHgDg
    Content-Length: 259
    Date: Sun, 23 Feb 2014 17:03:50 GMT
    Server: GFE/2.0
    Alternate-Protocol: 443:quic
    
    <HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
    <TITLE>302 Moved</TITLE></HEAD><BODY>
    <H1>302 Moved</H1>
    The document has moved
    <A HREF="https://www.google.de/?gfe_rd=cr&amp;ei=9ikKU56iO8qK8QeoroHgDg">here</A>.
    </BODY></HTML>


replace_apk_bks_cert.bash
-------------------------

script to replace certificate in BKS keystore inside of an APK
(e.g. for changing pinned SSL certificates) and re-sign the modified APK

Dependencies:
* apt-get install libbcprov-java

Usage:

    replace_apk_bks_cert.bash [--list|--info|--replace|--sign|--help] <file.apk> ...
    
    -l|--list <file.apk>
        search BKS keystores and list their aliases
    
    -i|--info <file.apk> <path> <alias>
        show certificate details of certificate in BKS keystore
    
    -r|--repl <file.apk> <path> <alias> <fake.crt> [<keystore-password> [<fakecrt.apk>]]
        replace certificate in BKS keystore with fake.crt
    
    -s|--sign <file.apk> [<file.crt> <file.pk8> [<signed.apk>]]
        sign (modified) APK with private key

