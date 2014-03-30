#! /usr/bin/perl -wT

use strict;
use warnings;
use WWW::Curl::Easy;
use XML::XPath;
use XML::XPath::XMLParser;

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

my $xp = XML::XPath->new($body);

my $nodeset = $xp->find('/urlset/url/loc');          # find all locations

foreach my $node ( $nodeset->get_nodelist ) {
    print "FOUND\n\n", XML::XPath::XMLParser::as_string($node), "\n\n";
}

$curl->cleanup();                                    # optional
