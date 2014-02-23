#!/bin/bash
# replace_apk_bks_cert.bash
# script to replace certificate in BKS keystore inside of an APK
# (e.g. for changing pinned SSL certificates) and re-sign the modified APK

TMP="$(mktemp)"
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

usage() {
    cat <<EOF
Usage: $(basename "$0") [--list|--info|--replace|--sign|--help] <file.apk> ...

-l|--list <file.apk>
    search BKS keystores and list their aliases

-i|--info <file.apk> <path> <alias>
    show certificate details of certificate in BKS keystore

-r|--repl <file.apk> <path> <alias> <fake.crt> [<keystore-password> [<fakecrt.apk>]]
    replace certificate in BKS keystore with fake.crt

-s|--sign <file.apk> [<file.crt> <file.pk8> [<signed.apk>]]
    sign (modified) APK with private key

EOF
    exit 1
}

list() {
    APK="$1"
    echo "$APK"
    bks_files="$(unzip -l "$APK" | grep -oe "[^ ]*.bks$")"
    for file in $bks_files
    do
        unzip -qc "$APK" "$file" > "$TMP" 2>/dev/null || continue
        BKS_certs="$(LC_ALL=C keytool \
            -list -v \
            -keystore "$TMP" \
            -storetype BKS \
            -provider org.bouncycastle.jce.provider.BouncyCastleProvider \
            -providerpath /usr/share/maven-repo/org/bouncycastle/bcprov/debian/bcprov-debian.jar \
            -storepass "")" || continue
        echo " +-- $file"
        aliases="$(grep "^Alias name:" <<<"$BKS_certs" | cut -d\  -f3-)"
        for alias in $aliases
        do
            echo " |    +-- $alias"
        done
    done
}

info() {
    APK="$1"
    file="$2"
    alias="$3"
    unzip -qc "$APK" "$file" > "$TMP" 2>/dev/null || continue
    LC_ALL=C keytool \
        -list -v \
        -alias "$alias" \
        -keystore "$TMP" \
        -storetype BKS \
        -provider org.bouncycastle.jce.provider.BouncyCastleProvider \
        -providerpath /usr/share/maven-repo/org/bouncycastle/bcprov/debian/bcprov-debian.jar \
        -storepass ""
}

replace() {
    APK="$1"
    file="$2"
    alias="$3"
    crt="$4"
    password="$5"
    [ -z "$password" ] && password="password"
    newAPK="$6"
    [ -z "$newAPK" ] && newAPK="$(dirname "$APK")/$(basename "$APK" .apk).fakecrt.apk"
    unzip -qc "$APK" "$file" > "$TMP" 2>/dev/null || continue
    LC_ALL=C keytool \
        -delete \
        -alias "$alias" \
        -keystore "$TMP" \
        -storetype BKS \
        -provider org.bouncycastle.jce.provider.BouncyCastleProvider \
        -providerpath /usr/share/maven-repo/org/bouncycastle/bcprov/debian/bcprov-debian.jar \
        -storepass "$password" || return 1
    LC_ALL=C keytool \
        -import \
        -trustcacerts \
        -alias "$alias" \
        -file <(openssl x509 -in "$crt") \
        -keystore "$TMP" \
        -storetype BKS \
        -provider org.bouncycastle.jce.provider.BouncyCastleProvider \
        -providerpath /usr/share/maven-repo/org/bouncycastle/bcprov/debian/bcprov-debian.jar \
        -storepass "$password" || return 1

    # replace keystore in zip file
    mkdir "$TMP.zip"
    cp "$APK" "$TMP.zip/apk.zip"
    mkdir -p "$TMP.zip/$(dirname "$file")"
    ls -lR "$TMP.zip"
    mv "$TMP" "$TMP.zip/$file"
    cd "$TMP.zip"
    zip -u "apk.zip" "$file"
    cd - &>/dev/null
    mv "$TMP.zip/apk.zip" "$newAPK"
    rm -rf "$TMP.zip"

    cat <<EOF

$newAPK created.

You can sign it with:
    $0 --sign $newAPK [<cert.crt> <key.pk8> [<signed.apk>]]

EOF
}

sign() {
    APK="$1"
    crt="$2"
    key="$3"
    newAPK="$4"
    [ -z "$crt" ] && crt="$(dirname "$APK")/$(basename "$APK" .apk).crt"
    [ -z "$key" ] && key="$(dirname "$APK")/$(basename "$APK" .apk).pk8"
    [ -z "$newAPK" ] && newAPK="$(dirname "$APK")/$(basename "$APK" .apk).signed.apk"

    [ ! -e signapk.jar ] && wget http://pof.eslack.org/archives/files/signapk.jar
    if [ ! -e "$crt" -o ! -e "$key" ]; then
        openssl genrsa -out key.pem 1024
        openssl req -new -key key.pem -out request.pem
        openssl x509 -req -days 9999 -in request.pem -signkey key.pem -out "$crt"
        rm request.pem
        openssl pkcs8 -topk8 -outform DER -in key.pem -inform PEM -out "$key" -nocrypt
        rm key.pem
    fi
    java -jar signapk.jar "$crt" "$key" "$APK" "$newAPK"
    cat <<EOF

$newAPK created.

EOF
}

case "$1" in
    -l|-list|--list|list)
        shift
        list "$@"
        ;;
    -i|-info|--info|info)
        shift
        info "$@"
        ;;
    -r|-repl|-replace|--repl|--replace|repl|replace)
        shift
        replace "$@"
        ;;
    -s|-sign|--sign|sign)
        shift
        sign "$@"
        ;;
    -h|-help|--help|help)
        usage
        ;;
    *)
        if [ -e "$1" ]; then
            case "$#" in
            1|2) list "$@";;
            3) info "$@";;
            *) replace "$@";;
            esac
        else
            usage
        fi
        ;;
esac


