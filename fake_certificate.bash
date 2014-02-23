#!/bin/bash
crt="$1"
if [ -z "$crt" ]; then
    cat <<EOF
Usage: $(basename "$0") <orig.crt|host[:port[:servername]]> [<fake.key> [fakeca.key>]]

Options:
port (default: 443)
servername (default: same as host)
    use "-" as servername if you want to fetch the certificate without a servername

EOF
    exit 1
fi
if [ ! -e "$crt" ]; then
    IFS=: read host port servername <<<"$crt"
    [ -z "$port" ] && port=443
    crt="$host.crt"
    [ -z "$servername" ] && servername="$host"
    if [ "$servername" = "-" ]; then
        echo QUIT | openssl s_client -connect "$host:$port" 2>/dev/null | sed -n '/BEGIN/,/END/p' > "$crt"
    else
        echo QUIT | openssl s_client -connect "$host:$port" -servername "$servername" 2>/dev/null | sed -n '/BEGIN/,/END/p' > "$crt"
    fi
fi
crtname="$(basename "$crt" .crt)"
key="$2"
[ -z "$key" ] && key="fake-$crtname.key"
cakey="$3"
[ -z "$cakey" ] && cakey="fakeCA-$crtname.key"
csr="fake-$crtname.csr"


if [ ! -e "$key" ]; then
    openssl genrsa -out "$key"
fi
openssl x509 -in "$crt" -outform DER -out "$crt.der"
openssl x509 -x509toreq -in "$crt" -signkey "$key" -out "$csr"
openssl req -in "$csr" -outform DER -out "$csr.der"
./x509v3ext2req.pl "$crt.der" "$csr.der"
openssl req -inform DER -in "$csr.der" -rekey -key "$key" -out "$csr"
rm -f "$crt.der" "$csr.der"
openssl req -in "$csr" -text -noout

rm -rf tmpCA
mkdir -p tmpCA/newcerts
touch tmpCA/index.txt
while IFS== read var value
do
    export $var="$value"
done < <(openssl x509 -in "$crt" -dates -serial -issuer -subject -noout)
notBefore=$(date +"%Y%m%d%H%M%SZ" --utc --date="$notBefore")
notAfter=$(date +"%Y%m%d%H%M%SZ" --utc --date="$notAfter")
echo $serial > tmpCA/serial

# create fake ca cert
if [ ! -e "$cakey" ]; then
    openssl genrsa -out "$cakey"
fi
AKI="$(openssl x509 -in "$crt" -text -noout | grep -A1 "X509v3 Authority Key Identifier:" | sed -n 's/^\s*keyid://p' | tr -d ':')"
version=3
[ -z "$AKI" ] && version=1 && AKI=hash
[ $version = 3 ] && ca_params="-extensions v3_ca"
cat <<EOF > tmpext.cnf
[ req ]
distinguished_name	= req_distinguished_name

[ req_distinguished_name ]

[ v3_ca ]
subjectKeyIdentifier=$AKI
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = CA:true

EOF
cat <<"EOF" > tmpCA/ca.cnf
[ ca ]
default_ca      = CA_default            # The default ca section

[ CA_default ]

dir            = ./tmpCA               # top dir
database       = $dir/index.txt        # index file.
new_certs_dir  = $dir/newcerts         # new certs dir

certificate    = $dir/ca.crt           # The CA cert
serial         = $dir/serial           # serial no file
private_key    = $dir/ca.key           # CA private key
RANDFILE       = $ENV::HOME/.rnd       # random number file

default_days   = 365                   # how long to certify for
default_crl_days= 30                   # how long before next CRL
default_md     = default               # md to use

policy         = policy_any            # default policy

name_opt       = ca_default            # Subject name display option
cert_opt       = ca_default            # Certificate display option
copy_extensions = copyall              # Copy all extensions from request

[ policy_any ]
commonName             = optional

[ v3_ca ]

EOF
openssl req -x509 -new -nodes -key "$cakey" -batch -config tmpext.cnf -subj "${issuer/ }" -out tmpCA/ca.crt
cp tmpCA/ca.crt "fakeCA-$crt"
cp "$cakey" tmpCA/ca.key
rm tmpext.cnf

# create fake ca cert
openssl ca -config tmpCA/ca.cnf -in "$csr" -out "fake-$crt" -startdate "$notBefore" -enddate "$notAfter" -batch -preserveDN $ca_params

# cleanup
rm -r tmpCA

cat <<EOF

Original certificate for:$subject
 certificate: $crt

Fake certificate request for:$subject
 CSR file: $csr
 signed with private key: $key

Fake certificate for:$subject
 certificate: fake-$crt
 private key: $key
 signed by: fakeCA-$crt

Fake CA certificate for:$issuer
 certificate: fakeCA-$crt
 private key: $cakey
 signed by: self-signed

# openssl verify -CAfile fakeCA-$crt fake-$crt
EOF
openssl verify -CAfile "fakeCA-$crt" "fake-$crt"

