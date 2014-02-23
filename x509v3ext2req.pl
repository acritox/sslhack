#!/usr/bin/perl
# x509v3ext2req
# copies the X.509v3 extensions from a DER-encoded certificate
# into a DER-encoded certificate request (CSR)

use Data::Walk;
use Encoding::BER::DER;

my ($file_crt, $file_req) = @ARGV;

if (not defined $file_crt) {
    die "Usage: $0 <file.crt> <file.csr>";
}

my $data_crt, $data_req, $extensions, $req_ext;
{
    open my $file, "<", $file_crt;
    binmode $file;
    local $/;
    $data_crt = <$file>;
    close $file;
    open my $file, "<", $file_req;
    binmode $file;
    local $/;
    $data_req = <$file>;
    close $file;
}

sub process {
    glob $extensions;
    if (ref($_) eq 'HASH' && $_->{type}[2] eq 'extensions') {
        $extensions = $_;
    }
    if (ref($_) eq 'HASH' && $_->{type}[2] eq 'req_ext') {
        $req_ext = $_;
    }
}

my $enc = Encoding::BER::DER->new(debug => 0);
$enc->add_implicit_tag('context', 'primitive', 'req_ext', 0, 'content_end');
$enc->add_implicit_tag('context', 'primitive', 'extensions', 3, 'content_end');
my $crt = $enc->decode( $data_crt );
walk \&process, $crt;

my $req = $enc->decode( $data_req );
walk \&process, $req;
$req_ext->{value} = [
                       {
                         'identval' => 48,
                         'tagnum' => 16,
                         'value' => [
                                      {
                                        'identval' => 6,
                                        'tagnum' => 6,
                                        'value' => '1.2.840.113549.1.9.14',
                                        'type' => [
                                                    'universal',
                                                    'primitive',
                                                    'oid'
                                                  ]
                                      },
                                      {
                                        'identval' => 49,
                                        'tagnum' => 17,
                                        'value' => $extensions->{value},
                                        'type' => [
                                                    'universal',
                                                    'constructed',
                                                    'set'
                                                  ]
                                      }
                                    ],
                         'type' => [
                                     'universal',
                                     'constructed',
                                     'sequence'
                                   ]
                       }
                     ];

open(OUTPUT, ">", $file_req);
binmode(OUTPUT);
print OUTPUT $enc->encode( $req );
close OUTPUT;

