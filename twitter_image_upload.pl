#!/usr/bin/env perl

# Code to tweet pictures of completed prints 

use feature qw{ say } ;
use strict ;
use warnings ;
use utf8 ;
use Carp ;
use Data::Dumper ;
use Encode 'decode' ;
use Getopt::Long ;
use IO::Interactive qw{ interactive } ;
use Net::Twitter ;
use YAML qw{ DumpFile LoadFile } ;
use Time::Piece ;

use open ':std', ':encoding(UTF-8)' ;
binmode STDOUT, ':utf8' ;

# 201404 DAJ    Need new workflow.
#               message will always be "A print was completed at HH:MM:SS am|pm"
#               Will always contain image named YYYY-MM-DD_HH-MM-SS.jpg (or JPEG as necessary)    

my $config = config() ;
sleep 15; # give the printbed some time to lower
update_with_media( $config ) ;
exit ;

# ========= ========= ========= ========= ========= ========= =========
sub update_with_media{
    my $config = shift ;
    my $suffix = ( split m{\.}, $config->{ file } )[ -1 ] ;
    if ( $suffix =~ m{(?:gif|jpe?g|png)}i  || 1 ) {
        my $twit = Net::Twitter->new(
            traits          => [ qw/API::RESTv1_1/ ],
            consumer_key    => $config->{ consumer_key },
            consumer_secret => $config->{ consumer_secret },
            ssl             => 1,
            ) ;
        if ( $config->{ access_token } && $config->{ access_token_secret } ) {
            $twit->access_token( $config->{ access_token } ) ;
            $twit->access_token_secret( $config->{ access_token_secret } ) ;
            }
        unless ( $twit->authorized ) {
            croak( "Not Authorized" ) ;
            }

        #unless ( $twit->authorized ) {
        #
        #    # You have no auth token
        #    # go to the auth website.
        #    # they'll ask you if you wanna do this, then give you a PIN
        #    # input it here and it'll register you.
        #    # then save your token vals.
        #
        #    say "Authorize this app at ", $twit->get_authorization_url,
        #        ' and enter the PIN#' ;
        #    my $pin = <STDIN> ;    # wait for input
        #    chomp $pin ;
        #    my ( $access_token, $access_token_secret, $user_id, $screen_name ) =
        #        $twit->request_access_token( verifier => $pin ) ;
        #    save_tokens( $user_id , $access_token, $access_token_secret ) ;
        #    }

        my $media ;
        push @$media, $config->{ file } ;
        push @$media, 'icon.' . $suffix ;
        if ( $twit->update_with_media( $config->{ status } , $media ) ) {
            say {interactive} 'OK' ;
            }
        }
    }

# ========= ========= ========= ========= ========= ========= =========
sub take_pic {
    my $file = shift ;
    print "taking a pic into  " . $file . "\n";
    qx{"c:\\Program Files\\WebCamImageSave\\WebCamImageSave.exe" /capture /imagequality 100 /filename $file } ;
    print "done taking pic\n";
    return 1;
    }

# ========= ========= ========= ========= ========= ========= =========
sub config {

    ## HARDCODING TOKENS. BAD.
    my $config_file = 'C:\\Documents and Settings\\Printer\\My Documents\\Code\\twitter_ltl.cnf' ;
    my $data        = LoadFile( $config_file ) ;
    my $config ;

    my $t = localtime ;
    my $ymd = $t->ymd ;
    my $hms = $t->hms ;

    $config->{ user } = 'ltl_solidoodle' ; # NEED TO PULL THIS INTO CONFIG
    $config->{ status } = qq{Print is done at $ymd $hms} ;
    $config->{ file } = "c:\\temp\\lastprint.jpg";
    
    take_pic( $config->{ file } ); # || $config->{ help } = 1 ;

    GetOptions(
        'file=s' => \$config->{ file },
        'user=s' => \$config->{ user },
        'status=s' => \$config->{ status },
        'help'   => \$config->{ help },
        ) ;

    say { interactive } Dumper $config ; 
    for my $k ( qw{ consumer_key consumer_secret } ) {
        $config->{ $k } = $data->{ $k } ;
        }

    my $tokens = $data->{ tokens }->{ $config->{ user } } ;
    for my $k ( qw{ access_token access_token_secret } ) {
        $config->{ $k } = $tokens->{ $k } ;
        }
    return $config ;
    }

#========= ========= ========= ========= ========= ========= =========
sub scrub {
    my $status = shift ;
    my @status = split /\s/, $status ;
    @status = map {
        my $s = $_ ;
        if ( $s =~ m{^https?://}i ) {
            $s = makeashorterlink( $s ) ;
            }
        $s ;
        } @status ;
    $status = join ' ', @status ;
    return $status ;
    }

#========= ========= ========= ========= ========= ========= =========
sub restore_tokens {
    my ( $user ) = @_ ;
    my ( $access_token, $access_token_secret ) ;
    if ( $config->{ tokens }{ $user } ) {
        $access_token = $config->{ tokens }{ $user }{ access_token } ;
        $access_token_secret =
            $config->{ tokens }{ $user }{ access_token_secret } ;
        }
    return $access_token, $access_token_secret ;
    }

#========= ========= ========= ========= ========= ========= =========
sub save_tokens {
    my ( $user, $access_token, $access_token_secret ) = @_ ;
    $config->{ tokens }{ $user }{ access_token }        = $access_token ;
    $config->{ tokens }{ $user }{ access_token_secret } = $access_token_secret ;
    #DumpFile( $config_file, $config ) ;
    return 1 ;
    }