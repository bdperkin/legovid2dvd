#! /usr/bin/perl -wT

use strict;
use warnings;
use WWW::Curl::Easy;

my $sitemap = "http://www.lego.com/en-us/videos/sitemap?xml=1";

my $headers = "";
my $body    = "";

sub chunk {
    my ( $data, $pointer ) = @_;
    ${$pointer} .= $data;
    return length($data);
}

my $curl = WWW::Curl::Easy::new();    # an alias for WWW::Curl::Easy::init
my $code = $curl->setopt( CURLOPT_URL, $sitemap );
$code = $curl->setopt( CURLOPT_WRITEFUNCTION, \&chunk );
$code = $curl->setopt( CURLOPT_WRITEHEADER,   \$headers );
$code = $curl->setopt( CURLOPT_FILE,          \$body );
$code = $curl->perform();
my $err  = $curl->errbuf;                            # report any error message
my $info = $curl->getinfo(CURLINFO_SIZE_DOWNLOAD);

#print $body;

$curl->cleanup();                                    # optional
