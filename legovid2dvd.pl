#!/usr/bin/perl -w
#
# %{NAME}.pl - LEGO® video downloader and DVD authoring tool.
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
use File::Compare;                        # Compare files or filehandles
use File::LibMagic;                       # Determine MIME types of data or
                                          # files using libmagic
use File::Path;                           # Create or remove directory trees
use Getopt::Long;                         # Getopt::Long - Extended processing
                                          # of command line options
use IO::Select;                           # OO interface to the select system
                                          # call
use IPC::Open3;                           # open a process for reading, writing,
                                          # and error handling using open3()
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
binmode STDOUT, ":utf8";    # Out/Err/Input UTF-8 using the :utf8
binmode STDERR, ":utf8";    # out/err/input layer.  This ensures that the
binmode STDIN,  ":utf8";    # out/err/input is completelyUTF-8, and removes any
                            # debug warnings.

$ENV{PATH} = "/usr/bin:/bin";

my $sitemap = "http://www.lego.com/en-us/videos/sitemap?xml=1";

my $headers = "";
my $body    = "";

my $cn = "Cannot";

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
else {
    $| = 1;
}

if ($optverbose) {
    $DBG = 2;
}
if ($optdebug) {
    $DBG = 3;
}

################################################################################
# Main function
################################################################################
if ( $DBG > 0 ) {
    print "Loading...";
}
if ( $DBG > 2 ) { print "Initializing WWW::Curl::Easy...\n"; }
my $browser = WWW::Curl::Easy->new;    # an alias for WWW::Curl::Easy::init

if ($optcurlverbose) {
    $curloptverbose = 1;
}
if ( $DBG > 2 ) { print "Setting CURLOPT_VERBOSE to $curloptverbose...\n"; }
$browser->setopt( CURLOPT_VERBOSE, $curloptverbose );

if ( $DBG > 2 ) {
    print "CURLVERSION_NOW is: " . $browser->version(CURLVERSION_NOW) . "\n";
}

# Configure browser and get sitemap
if ( $DBG > 2 ) { print "Setting CURLOPT_URL to $sitemap...\n"; }
my $code = $browser->setopt( CURLOPT_URL, $sitemap );
if ( $DBG > 2 ) { print "Setting CURLOPT_WRITEHEADER variable...\n"; }
$code = $browser->setopt( CURLOPT_WRITEHEADER, \$headers );
if ( $DBG > 2 ) { print "Setting CURLOPT_FILE variable...\n"; }
$code = $browser->setopt( CURLOPT_FILE, \$body );
if ( $DBG > 2 ) { print "Performing GET...\n"; }
$code = $browser->perform();
my $err = $browser->errbuf;    # report any error message

if ($code) {
    die "\nCannot get "
      . $sitemap . " -- "
      . $code . " "
      . $browser->strerror($code) . " "
      . $err . "\n";
}

unless ( $browser->getinfo(CURLINFO_CONTENT_TYPE) =~ m/^application\/xml/ ) {
    die "\nDid not receive XML, got -- "
      . $browser->getinfo(CURLINFO_CONTENT_TYPE) . "\n";
}
else {
    if ( $DBG > 1 ) {
        print "Got videos from " . $sitemap . "\n";
    }
}

my $info = $browser->getinfo(CURLINFO_SIZE_DOWNLOAD);
if ( $DBG > 2 ) { print "Got CURLINFO_SIZE_DOWNLOAD as $info.\n"; }

# Parse sitemap data
if ( $DBG > 2 ) { print "Initializing XML::XPath...\n"; }
my $xp = XML::XPath->new($body);

my %gallery;

if ( $DBG > 2 ) { print "Finding URLs within URL Set...\n"; }
my $urlnodes = $xp->find('/urlset/url');
if ( $DBG > 2 ) { print "Getting node list...\n"; }
foreach my $url ( $urlnodes->get_nodelist ) {
    $vidcounter++;
    $totalvideos = $vidcounter;
    if ( $DBG > 1 ) {
        print "\rLoading...$totalvideos ";
    }
    if ( $DBG > 0 ) {
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

        my $vt    = $video_title->string_value;
        my $vglt  = $video_gallery_loc_title->string_value;
        my $urlsv = $url->string_value;
        my $lnsv  = $locnode->string_value;
        my $vtl   = $video_thumbnail_loc->string_value;
        my $vde   = $video_description->string_value;
        my $vcl   = $video_content_loc->string_value;
        my $vdu   = $video_duration->string_value;
        my $vpd   = $video_publication_date->string_value;
        my $ved   = $video_expiration_date->string_value;
        my $vvc   = $video_view_count->string_value;
        my $vff   = $video_family_friendly->string_value;
        my $vgl   = $video_gallery_loc->string_value;

        if ( $DBG > 1 ) {
            printf( "[ %.30s ] %-.45s\r", $vglt, $vt );
        }

        if ( $DBG > 2 ) {
            print "$vidcounter\t\t" . $urlsv . "\n";
            print "$vidcounter\tloc\t" . $lnsv . "\n";
            print "$vidcounter\t\tvideo:thumbnail_loc\t" . $vtl . "\n";
            print "$vidcounter\t\tvideo:title\t" . $vt . "\n";
            print "$vidcounter\t\tvideo:description\t" . $vde . "\n";
            print "$vidcounter\t\tvideo:content_loc\t" . $vcl . "\n";
            print "$vidcounter\t\tvideo:duration\t" . $vdu . "\n";
            print "$vidcounter\t\tvideo:publication_date\t" . $vpd . "\n";
            print "$vidcounter\t\tvideo:expiration_date\t" . $ved . "\n";
            print "$vidcounter\t\tvideo:view_count\t" . $vvc . "\n";
            print "$vidcounter\t\tvideo:family_friendly\t" . $vff . "\n";
            print "$vidcounter\t\tvideo:gallery_loc\t" . $vgl . "\n";
            print "$vidcounter\t\tvideo:gallery_loc/\@title\t" . $vglt . "\n";
        }

        my $vgpath = $vgl;
        my @revvgpath = reverse( split( /\//, $vgpath ) );
        $gallery{ $revvgpath[0] } = $vglt;
        unless ($optlist) {
            if ( $revvgpath[0] =~ m/^$optgallery$/i ) {
                if ( $DBG > 0 ) {
                    print "!";
                }
                my ( $scheme, $auth, $path, $query, $frag ) =
                  uri_split($locnode);
                my $dirname = $optdownload . $path;
                unless ( -d "$dirname" ) {
                    unless ( mkpath($dirname) ) {
                        die "$cn create content directory $dirname: $!\n";
                    }
                }
                my $try = 0;
                my $chk = 1;
                while ( $try lt $optattempts ) {
                    my $tryname = $dirname . "/" . $try;
                    my $chkname = $dirname . "/" . $chk;
                    unless ( -d "$tryname" ) {
                        unless ( mkpath($tryname) ) {
                            die "$cn create content directory $tryname: $!\n";
                        }
                    }

                    xml2txt( $tryname, $chkname, "loc.txt", $lnsv );

                    xml2txt( $tryname, $chkname, "thumbnail_loc.txt", $vtl );
                    if ($vtl) {
                        wget( $tryname, $chkname, basename($vtl), $vtl );
                    }
                    else {
                        if ( $DBG > 0 ) {
                            warn "No URI found for $tryname thumbnail_loc!\n";
                        }
                    }

                    xml2txt( $tryname, $chkname, "title.txt", $vt );

                    xml2txt( $tryname, $chkname, "description.txt", $vde );

                    xml2txt( $tryname, $chkname, "content_loc.txt", $vcl );
                    if ($vcl) {
                        wget( $tryname, $chkname, basename($vcl), $vcl );
                    }
                    else {
                        if ( $DBG > 0 ) {
                            warn "No URI found for $tryname content_loc!\n";
                        }
                    }

                    xml2txt( $tryname, $chkname, "duration.txt", $vdu );

                    xml2txt( $tryname, $chkname, "publication_date.txt", $vpd );

                    xml2txt( $tryname, $chkname, "expiration_date.txt", $ved );

                    xml2txt( $tryname, $chkname, "gallery_loc.txt", $vgl );

                    xml2txt( $tryname, $chkname, "gallery_title.txt", $vglt );

                    $try++;
                    $chk++;
                    if ( $chk eq $optattempts ) {
                        $chk = 0;
                    }

                    convert( $tryname, $chkname, basename($vcl), "mpg" );
                    convert( $tryname, $chkname, basename($vcl), "ac3" );
                    convert( $tryname, $chkname, basename($vcl), "m2v" );
                    convert( $tryname, $chkname, basename($vcl), "wav" );
                    convert( $tryname, $chkname, basename($vcl), "pcm" );
                    convert( $tryname, $chkname, basename($vcl), "mpa" );
                    convert( $tryname, $chkname, basename($vcl), "mplex.mpg" );
                }
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

# Dump XML data into text files
sub xml2txt {
    my ( $tryname, $chkname, $filename, $filedata ) = @_;
    if ( !-f "$tryname/$filename" ) {
        unless ( open( TXTFILE, ">$tryname/$filename" ) ) {
            die "$cn create text file $filename in $tryname: $!\n";
        }
        binmode TXTFILE, ":utf8";
        print TXTFILE $filedata . "\n";
        close(TXTFILE);
    }
    check( $tryname, $chkname, $filename );
}

# Get the base file name based on a full path
sub basename {
    my $fulluri  = $_[0];
    my @fullpath = split( /\//, $fulluri );
    my @revpath  = reverse(@fullpath);
    return $revpath[0];
}

# Dump binary data into local files
sub wget {
    my ( $tryname, $chkname, $filename, $dluri ) = @_;
    if ( !-f "$tryname/$filename" ) {
        my $localfile = "$tryname/$filename";
        my $fileb;
        my $retry = 0;
        while ( $retry < $optattempts ) {
            $retry++;
            if ( $DBG > 2 ) { print "Setting CURLOPT_URL to $dluri...\n"; }
            $browser->setopt( CURLOPT_URL, $dluri );
            unless ( open( $fileb, ">", $localfile ) ) {
                die "$cn open $localfile for writing: $!\n";
            }
            binmode($fileb);
            if ( $DBG > 2 ) { print "Setting CURLOPT_WRITEDATA variable...\n"; }
            $browser->setopt( CURLOPT_WRITEDATA, $fileb );
            if ( $DBG > 0 ) {
                print "+";
                if ( $DBG > 0 ) {
                    print "Getting $dluri and saving content at $localfile...";
                }
            }
            if ( $DBG > 2 ) { print "Performing GET...\n"; }
            $code = $browser->perform();
            if ( $DBG > 0 ) { print "Reporing any error messages:\n"; }
            $err = $browser->errbuf;    # report any error message

            if ($code) {
                warn "\nCannot get "
                  . $dluri . " -- "
                  . $code . " "
                  . $browser->strerror($code) . " "
                  . $err . "\n";
            }

            my $ct = "application\/xml";
            if ( $dluri =~ m/\.jpg$/ ) {
                $ct = "image\/jpeg";
            }
            elsif ( $dluri =~ m/\.mp4$/ ) {
                $ct = "video\/mp4";
            }
            else {
                die "Cannot guess content-type based on $dluri\n";
            }

            unless ( $browser->getinfo(CURLINFO_CONTENT_TYPE) =~ m/^$ct/ ) {
                die "\nDid not receive $ct, got -- "
                  . $browser->getinfo(CURLINFO_CONTENT_TYPE) . "\n";
            }
            else {
                if ( $DBG > 1 ) {
                    print "Got videos from " . $dluri . "\n";
                }
            }

            my $info = $browser->getinfo(CURLINFO_SIZE_DOWNLOAD);
            if ( $DBG > 2 ) { print "Got CURLINFO_SIZE_DOWNLOAD as $info.\n"; }

            if ( $retry > $optattempts ) {
                die "$cn get $dluri -- $code "
                  . $browser->strerror($code) . " "
                  . $browser->errbuf . "\n"
                  unless ( $code == 0 );
            }
            else {
                warn "$cn get $dluri -- $code "
                  . $browser->strerror($code) . " "
                  . $browser->errbuf . "\n"
                  unless ( $code == 0 );
            }
            close($fileb);
            if ( $DBG > 0 ) {
                print "done.\n";
            }
        }
    }
    check( $tryname, $chkname, $filename );
}

sub convert {
    my ( $tryname, $chkname, $filename, $task ) = @_;
    my $tryf = "$tryname/$filename";
    my $chkf = "$chkname/$filename";
    my $tfcf = "$tryf and $chkf";
    if ( !-f "$tryf" ) {
        die "$cn find file $tryf: $!\n";
    }
    my $cmd;
    if ( $task =~ m/^mpg$/ ) {
        my $nullaudio = "";
        $cmd =
            "ffprobe -v info -select_streams a \""
          . $tryf
          . "\" 2>&1 | grep '^    Stream #' | grep ': Audio: '";
        warn("Checking for audio stream in $tryf with: \"$cmd\"");
        my $rc = system($cmd);
        if ($rc) {
            warn(
                "$tryf does not have an audio track, setting it to have one..."
            );
            $nullaudio =
" -f lavfi -i aevalsrc=0 -shortest -c:v copy -c:a aac -strict experimental ";
        }
        $cmd =
            " ffmpeg -y -i \""
          . $tryf . "\" "
          . $nullaudio
          . " -target ntsc-dvd -q:a 0 -q:v 0 \""
          . $tryf
          . ".$task" . "\"";
    }
    elsif ( $task =~ m/^ac3$/ ) {
        $cmd =
            " ffmpeg -y -i \""
          . $tryf . ".mpg"
          . "\" -acodec copy -vn \""
          . $tryf
          . ".$task" . "\"";
    }
    elsif ( $task =~ m/^m2v$/ ) {
        $cmd =
            " ffmpeg -y -i \""
          . $tryf . ".mpg"
          . "\" -vcodec copy -an \""
          . $tryf
          . ".$task" . "\"";
    }
    elsif ( $task =~ m/^wav$/ ) {
        $cmd =
            " mplayer -noautosub -nolirc -benchmark "
          . "-vc null -vo null "
          . "-ao pcm:waveheader:fast:file=\""
          . $tryf
          . ".$task" . "\" \""
          . $tryf . ".ac3" . "\"";
    }
    elsif ( $task =~ m/^pcm$/ ) {
        $cmd =
            " cp -a \""
          . $tryf . ".wav" . "\" \""
          . $tryf
          . ".$task" . "\""
          . " && normalize --no-progress -n \""
          . $tryf
          . ".$task"
          . "\"  2>&1 | "
          . "grep ' has zero power, ignoring...' ; "
          . "if [ \$? -eq 0 ]; "
          . "then echo \"skipping file "
          . $tryf
          . ".$task" . "\"; "
          . "else echo \"normalizing file "
          . $tryf
          . ".$task"
          . "\" && "
          . "normalize -m \""
          . $tryf
          . ".$task" . "\" ; " . "fi";
    }
    elsif ( $task =~ m/^mpa$/ ) {
        $cmd =
            " ffmpeg -y -i \""
          . $tryf . ".pcm"
          . "\" -f ac3 -vn \""
          . $tryf
          . ".$task" . "\"";
    }
    elsif ( $task =~ m/^mplex\.mpg$/ ) {
        $cmd =
            " mplex -f 8 -o \""
          . $tryf
          . ".$task\" \""
          . $tryf . ".m2v" . "\" \""
          . $tryf . ".mpa" . "\"";
    }
    elsif ( $task =~ m/^dvda$/ ) {
        $cmd =
            "cd \""
          . $tryname
          . "\" && "
          . "if [ -d dvd ]; then /bin/rm -r dvd; fi && "
          . "mkdir dvd && "
          . "dvdauthor -x \"../../meta/$tryf.xml\" -o dvd";
    }
    else {
        die "Task \"$task\" is unkown!";
    }

    runcmd($cmd);

    check( $tryname, $chkname, $filename . ".$task" );
}

# Check for differences in files, if none, make hard links
sub check {
    my ( $tryname, $chkname, $filename ) = @_;
    my $tryf = "$tryname/$filename";
    my $chkf = "$chkname/$filename";
    my $tfcf = "$tryf and $chkf";
    if ( !-f "$tryf" ) {
        die "$cn find file $tryf: $!\n";
    }

    my @stattry = stat("$tryf");
    if ( $stattry[3] != $optattempts ) {
        if ( !-f "$chkf" ) {
            if ( $DBG > 0 ) {
                warn "$cn find file $chkf: $!\n";
            }
        }
        else {
            my @statchk = stat("$chkf");
            if ( $statchk[3] != $optattempts ) {
                my $ft             = File::LibMagic->new();
                my $type_from_file = $ft->describe_filename("$tryf");

                my $ct = "application\/xml";
                if ( $tryf =~ m/\.ac3$/ ) {
                    $ct = "ATSC A\/52 aka AC-3 aka Dolby Digital stream";
                }
                elsif ( $tryf =~ m/\.jpg$/ ) {
                    $ct = "JPEG image data, JFIF standard ";
                }
                elsif ( $tryf =~ m/\.m2v$/ ) {
                    $ct = "MPEG sequence, v2, MP\@ML progressive";
                }
                elsif ( $tryf =~ m/\.mp4$/ ) {
                    $ct = "ISO Media, MPEG v4 system, ";
                }
                elsif ( $tryf =~ m/\.mpa$/ ) {
                    $ct = "ATSC A\/52 aka AC-3 aka Dolby Digital stream";
                }
                elsif ( $tryf =~ m/\.mpg$/ ) {
                    $ct = "MPEG sequence, v2, program multiplex";
                }
                elsif ( $tryf =~ m/\.pcm$/ ) {
                    $ct = "RIFF \\(little-endian\\) data, WAVE audio";
                }
                elsif ( $tryf =~ m/\.txt$/ ) {
                    $ct = " text";
                }
                elsif ( $tryf =~ m/\.wav$/ ) {
                    $ct = "RIFF \\(little-endian\\) data, WAVE audio";
                }
                else {
                    die "Cannot guess file-type based on $tryf\n";
                }

                unless ( $type_from_file =~ m/$ct/ ) {
                    die
"File type of $tryf expected to be \"$ct\", but was found to be \"$type_from_file\"!";
                }

                unless ( compare( "$tryf", "$chkf" ) ) {
                    if ( $DBG > 0 ) {
                        print "=";
                        if ( $DBG > 0 ) {
                            print "Files $tfcf match.\n";
                        }
                    }
                    unless ( unlink("$chkf") ) {
                        die "$cn remove $chkf: $!\n";
                    }
                    unless ( link( "$tryf", "$chkf" ) ) {
                        die "$cn link $tryf to $chkf: $!\n";
                    }
                }
                else {
                    if ( $DBG > 0 ) {
                        warn "Files $tfcf do NOT match.\n";
                    }
                    unless ( unlink("$tryf") ) {
                        die "$cn remove $tryf: $!\n";
                    }
                    unless ( unlink("$chkf") ) {
                        die "$cn remove $chkf: $!\n";
                    }
                }
            }
            else {
                if ( $DBG > 0 ) {
                    print "=";
                    if ( $DBG > 0 ) {
                        print "Files $tfcf have all symbolic links.\n";
                    }
                }
            }
        }
    }
    else {
        if ( $DBG > 0 ) {
            print "=";
            if ( $DBG > 0 ) {
                print "File $tryf has all symbolic links.\n";
            }
        }
    }
}

sub runcmd {
    my ($cmd) = @_;

    if ( $DBG > 0 ) {
        print "Running command: $cmd\n";
    }

    my ( $wtr, $rdr, $err );
    use Symbol 'gensym';
    $err = gensym;

    my $pid = open3( $wtr, $rdr, $err, $cmd );
    my $select = new IO::Select;
    $select->add( $rdr, $err );

    while ( my @ready = $select->can_read ) {
        foreach my $fh (@ready) {
            my $data;
            my $length = sysread $fh, $data, 4096;

            if ( !defined $length || $length == 0 ) {
                unless ($length) {
                    warn "Error from child: $!\n";
                }
                $select->remove($fh);
            }
            else {
                if ( $fh == $rdr ) {
                    if ( $DBG > 0 ) {
                        print "$data\n";
                    }
                }
                elsif ( $fh == $err ) {
                    if ( $DBG > 0 ) {
                        print "$data\n";
                    }
                }
                else {
                    return undef;
                }
            }
        }
    }

    waitpid( $pid, 0 );
    my $child_exit_status = $? >> 8;
    if ($child_exit_status) {
        die "Command \"$cmd\" exited with code $child_exit_status: $!";
    }
    return 0;
}

if ( $DBG > 0 ) {
    print "done.\n";
}
