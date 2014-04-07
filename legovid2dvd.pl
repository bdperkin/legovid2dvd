#!/usr/bin/perl -w
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
use strict;                               # Restrict unsafe constructs
use warnings;                             # Control optional warnings
use File::Path;                           # Create or remove directory trees
use Getopt::Long;                         # Getopt::Long - Extended processing
                                          # of command line options
use URI::Split qw(uri_split uri_join);    # URI::Split - Parse and compose URI
                                          # strings
use WWW::Curl::Easy;                      # WWW::Curl - Perl extension interface
                                          # for libcurl
use XML::XPath;                           # XML::XPath - a set of modules for
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
my $optattempts = 3;
my $optcurlverbose;
my $optdebug;
my $optdownload = ".";
my $optgallery  = ".*";
my $optlist;
my $optquiet;
my $optverbose;

GetOptions(
    "a=i"        => \$optattempts,
    "attempts=i" => \$optattempts,
    "C"          => \$optcurlverbose,
    "curlvrbs"   => \$optcurlverbose,
    "d"          => \$optdebug,
    "debug"      => \$optdebug,
    "D=s"        => \$optdownload,
    "download=s" => \$optdownload,
    "g=s"        => \$optgallery,
    "gallery=s"  => \$optgallery,
    "l"          => \$optlist,
    "list"       => \$optlist,
    "q"          => \$optquiet,
    "quiet"      => \$optquiet,
    "t=s"        => \$optgallery,
    "theme=s"    => \$optgallery,
    "v"          => \$optverbose,
    "verbose"    => \$optverbose,
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
    print "Loading...";
}
my $browser = WWW::Curl::Easy->new;    # an alias for WWW::Curl::Easy::init
if ($optcurlverbose) {
    $curloptverbose = 1;
}
$browser->setopt( CURLOPT_VERBOSE, $curloptverbose );

if ( $DBG > 1 ) {
    print $browser->version(CURLVERSION_NOW);
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

my %gallery;

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
            print "$vidcounter\t\tvideo:thumbnail_loc\t"
              . $video_thumbnail_loc->string_value . "\n";
            print "$vidcounter\t\tvideo:title\t"
              . $video_title->string_value . "\n";
            print "$vidcounter\t\tvideo:description\t"
              . $video_description->string_value . "\n";
            print "$vidcounter\t\tvideo:content_loc\t"
              . $video_content_loc->string_value . "\n";
            print "$vidcounter\t\tvideo:duration\t"
              . $video_duration->string_value . "\n";
            print "$vidcounter\t\tvideo:publication_date\t"
              . $video_publication_date->string_value . "\n";
            print "$vidcounter\t\tvideo:expiration_date\t"
              . $video_expiration_date->string_value . "\n";
            print "$vidcounter\t\tvideo:view_count\t"
              . $video_view_count->string_value . "\n";
            print "$vidcounter\t\tvideo:family_friendly\t"
              . $video_family_friendly->string_value . "\n";
            print "$vidcounter\t\tvideo:gallery_loc\t"
              . $video_gallery_loc->string_value . "\n";
            print "$vidcounter\t\tvideo:gallery_loc/\@title\t"
              . $video_gallery_loc_title->string_value . "\n";
        }

        my $vgpath = $video_gallery_loc->string_value;
        my @revvgpath = reverse( split( /\//, $vgpath ) );
        $gallery{ $revvgpath[0] } = $video_gallery_loc_title->string_value;
        if ( $revvgpath[0] =~ m/^$optgallery$/i ) {
            if ( $DBG > 1 ) {
                print "!";
            }
            my ( $scheme, $auth, $path, $query, $frag ) = uri_split($locnode);
            my $dirname = $optdownload . $path;
            unless ( -d "$dirname" ) {
                unless ( mkpath($dirname) ) {
                    die "Cannot create content directory $dirname: $!\n";
                }
            }
            my $try = 0;
            while ( $try lt $optattempts ) {
                my $tryname = $dirname . "/" . $try;
                unless ( -d "$tryname" ) {
                    unless ( mkpath($tryname) ) {
                        die "Cannot create content directory $tryname: $!\n";
                    }
                }

                unless ( open( TXTFILE, ">$tryname/loc.txt" ) ) {
                    die "Cannot create text file: $!\n";
                }
                print TXTFILE $locnode->string_value . "\n";
                close(TXTFILE);

                unless ( open( TXTFILE, ">$tryname/thumbnail_loc.txt" ) ) {
                    die "Cannot create text file: $!\n";
                }
                print TXTFILE $video_thumbnail_loc->string_value . "\n";
                close(TXTFILE);

                unless ( open( TXTFILE, ">$tryname/title.txt" ) ) {
                    die "Cannot create text file: $!\n";
                }
                binmode TXTFILE, ":utf8";
                print TXTFILE $video_title->string_value . "\n";
                close(TXTFILE);

                unless ( open( TXTFILE, ">$tryname/description.txt" ) ) {
                    die "Cannot create text file: $!\n";
                }
                binmode TXTFILE, ":utf8";
                print TXTFILE $video_description->string_value . "\n";
                close(TXTFILE);

                unless ( open( TXTFILE, ">$tryname/content_loc.txt" ) ) {
                    die "Cannot create text file: $!\n";
                }
                print TXTFILE $video_content_loc->string_value . "\n";
                close(TXTFILE);

                unless ( open( TXTFILE, ">$tryname/duration.txt" ) ) {
                    die "Cannot create text file: $!\n";
                }
                print TXTFILE $video_duration->string_value . "\n";
                close(TXTFILE);

                unless ( open( TXTFILE, ">$tryname/publication_date.txt" ) ) {
                    die "Cannot create text file: $!\n";
                }
                print TXTFILE $video_publication_date->string_value . "\n";
                close(TXTFILE);

                unless ( open( TXTFILE, ">$tryname/expiration_date.txt" ) ) {
                    die "Cannot create text file: $!\n";
                }
                print TXTFILE $video_expiration_date->string_value . "\n";
                close(TXTFILE);

                unless ( open( TXTFILE, ">$tryname/gallery_loc.txt" ) ) {
                    die "Cannot create text file: $!\n";
                }
                print TXTFILE $video_gallery_loc->string_value . "\n";
                close(TXTFILE);

                unless ( open( TXTFILE, ">$tryname/gallery_title.txt" ) ) {
                    die "Cannot create text file: $!\n";
                }
                binmode TXTFILE, ":utf8";
                print TXTFILE $video_gallery_loc_title->string_value . "\n";
                close(TXTFILE);

                $try++;

            }
        }
    }
}

$browser->cleanup();    # optional

if ($optlist) {
    if ( $DBG > 0 ) {
        print "\n";
    }
    foreach my $title ( keys %gallery ) {
        printf( "\t* %-20s%s\n", $title, $gallery{$title} );
    }
    exit;
}

# cURL callback
sub chunk {
    my ( $data, $pointer ) = @_;
    ${$pointer} .= $data;
    return length($data);
}
if ( $DBG > 0 ) {
    print "done.\n";
}
