#!/usr/bin/perl -Tw
#
# legovid2dvd.pl - LEGO® video downloader and DVD authoring tool.
# Copyright (C) 2014-2014  Brandon Perkins <bperkins@redhat.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
# USA.
#

################################################################################
# Import some semantics into the current package from the named modules
################################################################################
use strict;             # Restrict unsafe constructs
use warnings;           # Control optional warnings
use Getopt::Long;       # Getopt::Long - Extended processing
                        # of command line options
use WWW::Curl::Easy;    # WWW::Curl - Perl extension interface
                        # for libcurl
use XML::XPath;         # XML::XPath - a set of modules for
                        # parsing and evaluating XPath
                        # statements

################################################################################
# Declare constants
################################################################################
binmode STDOUT, ":utf8";    # Output UTF-8 using the :utf8 output layer.
                            # This ensures that the output is completely
                            # UTF-8, and removes any debug warnings.

$ENV{PATH} = "/usr/bin:/bin";    # Keep taint happy

my $sitemap = "http://www.lego.com/en-us/videos/sitemap?xml=1";

my $headers = "";
my $body    = "";

################################################################################
# Specify module configuration options to be enabled
################################################################################
# Allow single-character options to be bundled. To distinguish bundles from long
# option names, long options must be introduced with '--' and bundles with '-'.
# Do not allow '+' to start options.
Getopt::Long::Configure(qw(bundling no_getopt_compat));

################################################################################
# Initialize variables
################################################################################
my $DBG            = 1;  # Set debug output level:
                         #   0 -- quiet
                         #   1 -- normal
                         #   2 -- verbose
                         #   3 -- debug
my $curloptverbose = 0;  # Set the parameter to 1 to get the library to display
                         # a lot of verbose information about its operations.
                         # Very useful for libcurl and/or protocol debugging and
                         # understanding. The verbose information will be sent
                         # to stderr, or the stream set with CURLOPT_STDERR. The
                         # default value for this parameter is 0.
my $vidcounter     = 0;  # Counter for videos
my $totalvideos    = 0;  # Total number of videos

################################################################################
# Parse command line options.  This function adheres to the POSIX syntax for CLI
# options, with GNU extensions.
################################################################################
# Initialize GetOptions variables
my $optcurlverbose;
my $optdebug;
my $optquiet;
my $optverbose;

GetOptions(
    "C"        => \$optcurlverbose,
    "curlvrbs" => \$optcurlverbose,
    "d"        => \$optdebug,
    "debug"    => \$optdebug,
    "q"        => \$optquiet,
    "quiet"    => \$optquiet,
    "v"        => \$optverbose,
    "verbose"  => \$optverbose,
);

################################################################################
# Set output level
################################################################################
# If multiple outputs are specified, the most verbose will be used.
if ($optquiet) {
    $DBG = 0;
}
if ($optverbose) {
    $DBG = 2;
    $|   = 1;
}
if ($optdebug) {
    $DBG = 3;
    $|   = 1;
}

################################################################################
# Main function
################################################################################
if ( $DBG > 0 ) {
    print "Loading...\n";
}
my $browser = WWW::Curl::Easy->new;    # an alias for WWW::Curl::Easy::init
if ($optcurlverbose) {
    $curloptverbose = 1;
}
$browser->setopt( CURLOPT_VERBOSE, $curloptverbose );
my $curlversion = $browser->version(CURLVERSION_NOW);
chomp $curlversion;
my @curlversions = split( /\s/, $curlversion );
my %libversions;
foreach my $curlver (@curlversions) {
    my ( $lib, $ver ) = split( /\//, $curlver );
    my ( $major, $minor, $patch ) = split( /\./, $ver );
    $libversions{$lib}              = $ver;
    $libversions{ $lib . '-major' } = $major;
    $libversions{ $lib . '-minor' } = $minor;
    $libversions{ $lib . '-patch' } = $patch;
}

# Configure browser and get sitemap
my $code = $browser->setopt( CURLOPT_URL, $sitemap );
$code = $browser->setopt( CURLOPT_WRITEFUNCTION, \&chunk );
$code = $browser->setopt( CURLOPT_WRITEHEADER,   \$headers );
$code = $browser->setopt( CURLOPT_FILE,          \$body );
$code = $browser->perform();
my $err  = $browser->errbuf;                          # report any error message
my $info = $browser->getinfo(CURLINFO_SIZE_DOWNLOAD);

# Parse sitemap data
my $xp = XML::XPath->new($body);

my $urlnodes = $xp->find('/urlset/url');
foreach my $url ( $urlnodes->get_nodelist ) {
    $vidcounter++;
    $totalvideos = $vidcounter;
    if ( $DBG > 1 ) {
        print ".";
    }
    my $locnode  = $url->find('loc');
    my $vidnodes = $url->find('video:video');
    foreach my $video ( $vidnodes->get_nodelist ) {
        my $video_thumbnail_loc     = $video->find('video:thumbnail_loc');
        my $video_title             = $video->find('video:title');
        my $video_description       = $video->find('video:description');
        my $video_content_loc       = $video->find('video:content_loc');
        my $video_duration          = $video->find('video:duration');
        my $video_publication_date  = $video->find('video:publication_date');
        my $video_expiration_date   = $video->find('video:expiration_date');
        my $video_view_count        = $video->find('video:view_count');
        my $video_family_friendly   = $video->find('video:family_friendly');
        my $video_gallery_loc       = $video->find('video:gallery_loc');
        my $video_gallery_loc_title = $video->find('video:gallery_loc/@title');

        if ( $DBG > 2 ) {
            print $vidcounter . "\t" . $url->string_value . "\n";
            print "$vidcounter\tloc\t" . $locnode->string_value . "\n";
            print "$vidcounter\tvideo:thumbnail_loc\t"
              . $video_thumbnail_loc->string_value . "\n";
            print "$vidcounter\tvideo:title\t"
              . $video_title->string_value . "\n";
            print "$vidcounter\tvideo:description\t"
              . $video_description->string_value . "\n";
            print "$vidcounter\tvideo:content_loc\t"
              . $video_content_loc->string_value . "\n";
            print "$vidcounter\tvideo:duration\t"
              . $video_duration->string_value . "\n";
            print "$vidcounter\tvideo:publication_date\t"
              . $video_publication_date->string_value . "\n";
            print "$vidcounter\tvideo:expiration_date\t"
              . $video_expiration_date->string_value . "\n";
            print "$vidcounter\tvideo:view_count\t"
              . $video_view_count->string_value . "\n";
            print "$vidcounter\tvideo:family_friendly\t"
              . $video_family_friendly->string_value . "\n";
            print "$vidcounter\tvideo:gallery_loc\t"
              . $video_gallery_loc->string_value . "\n";
            print "$vidcounter\tvideo:gallery_loc/\@title\t"
              . $video_gallery_loc_title->string_value . "\n";
        }
    }
}
if ( $DBG > 1 ) {
    print "\n";
}

$browser->cleanup();    # optional

# cURL callback
sub chunk {
    my ( $data, $pointer ) = @_;
    ${$pointer} .= $data;
    return length($data);
}
