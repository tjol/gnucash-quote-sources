#!/usr/bin/perl -w


package Finance::Quote::BitstampEUR;

require 5.005;

use strict;
use JSON qw( decode_json );
use POSIX qw(strftime);


my $btceur_url = "https://www.bitstamp.net/api/v2/ticker/btceur/";

sub methods { return (bitstampeur => \&bitstampeur); }
sub labels  { return (bitstampeur => [qw/name date time last price nav high low volume bid ask method success/]); }

sub bitstampeur {
    my $quoter = shift;
    my @symbols = @_;

    return unless @symbols;

    my $ua = $quoter->user_agent();
    my %info;
    my $reply;

    foreach my $s (@symbols) {
        # Only BTC and BTCEUR are valid symbols. (and they're equivalent)
        if ($s !~ /BTC(EUR)?/) {
            $info{ $s, "success" } = 0;
            next;
        }

        $reply = $ua->get( $btceur_url);
        my $code    = $reply->code;
        my $desc    = HTTP::Status::status_message($code);
        my $headers = $reply->headers_as_string;
        my $body    = $reply->content;

        if ( $code != 200 ) {
            $info{ $s, "success" } = 0;
            next;
        }

        my $json_data = JSON::decode_json $body;

        my @date = localtime($json_data->{"timestamp"});

        $info{ $s, "symbol" } = "BTCEUR";
        $info{ $s, "name" } = $s;
        $info{ $s, "date" } = strftime("%D", @date);
        $info{ $s, "time" } = strftime("%R", @date);
        $info{ $s, "last" } = $json_data->{"last"};
        $info{ $s, "price" } = $json_data->{"last"};
        $info{ $s, "nav" } = $json_data->{"last"};
        $info{ $s, "high" } = $json_data->{"high"};
        $info{ $s, "low" } = $json_data->{"low"};
        $info{ $s, "volume" } = $json_data->{"volume"};
        $info{ $s, "bid" } = $json_data->{"bid"};
        $info{ $s, "ask" } = $json_data->{"ask"};
        $info{ $s, "currency" } = "EUR";
        $info{ $s, "method" } = "bitstampeur";
        $info{ $s, "success" } = 1;

    }

    return wantarray ? %info : \%info;

}

