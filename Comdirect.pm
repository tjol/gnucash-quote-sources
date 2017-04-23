# Finance::Quote Perl module to retrieve prices from Comdirect Bank
# Copyright (C) 2010-2015 Lars Eggert <lars@eggert.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

package Finance::Quote::Comdirect;

use warnings;
use strict;
use open IO => ':utf8';
use open ':std';

use LWP::Protocol::https;
use HTML::TokeParser::Simple;
use Data::Dumper;

use vars qw($VERSION);
$VERSION = '1.17';
#my $URL = "http://isht.comdirect.de/html/detail/main.html?";
my $URL = "http://www.comdirect.de/inf/search/all.html?";

my $debug = 1;

sub methods { return (comdirect => \&comdirect); }
sub labels  { return (comdirect => [qw/name date price last method/]); }

open my $log, q{>>},'/tmp/comdirect.log';

# Convert number separators to US values and strip other characters
sub conv {
	$_ = shift;
	s/\.//g;
	s/,/\./g;
	s/[^0-9,.]//g;
	return $_ ? sprintf "%.2f", $_ : "";
}

sub comdirect {
	my ($quoter, @symbols) = @_;
	my $ua = $quoter->user_agent();
	$ua->ssl_opts('verify_hostname' => 0); # works
	my %info;

	foreach my $s (@symbols) {
		# *OLD_STDOUT = *STDOUT;
		# *OLD_STDERR = *STDERR;
		# *STDERR = $log;
		# *STDOUT = $log;

		my $search = $s;
	    again:
		$info{$s, "url"} = $URL . "SEARCH_VALUE=" . $search;
		print $log $info{$s, "url"} . "\n" if $debug > 2;
		my $response = $ua->get($info{$s, "url"});
		$info{$s, "success"} = 0;

		if (not $response->is_success) {
			print $log $response->status_line ."\n" if $debug > 2;
			$info{$s, "errormsg"} = "HTTP failure";
			next;
		}

		foreach my $which (qw(p td)) {
			my $tp = HTML::TokeParser::Simple->new(
				string => $response->content
			);
			# fix utf8 issue for gnucash@online.de?
			$tp->utf8_mode(1);

			# get stock title
			my $tag = $tp->get_tag("span");
			if (defined $tag->get_attr("title")) {
				$info{$s, "name"} = $tag->get_attr("title");
			}

			my $p = "";
			while ($tag = $tp->get_tag($which)) {
				my $t = $tp->get_trimmed_text("/$which");
				print $log "$p --- $t\n" if $debug > 2;

				if ($p =~ "Symbol|ISIN") {
					# fix for gnucash@online.de
					$info{$s, "symbol"} = $t ne "--" ? $t : $search;
				}

				$info{$s, "open"} = conv($t)
					if $p =~ /Er.ffnung/;
				$info{$s, "close"} = conv($t)
					if $p eq "Schluss Vortag";
				$info{$s, "year_high"} = conv($t)
					if $p eq "52W Hoch";
				$info{$s, "year_low"} = conv($t)
					if $p eq "52W Tief";

				$info{$s, "high"} = conv($t) if $p eq "Hoch";
				$info{$s, "low"} = conv($t) if $p eq "Tief";
				$info{$s, "bid"} = conv($t) if $p eq "Geld";
				$info{$s, "ask"} = conv($t) if $p eq "Brief";

				$info{$s, "exchange"} = $1
					if $t =~ /B.rse: (.*)/;
				$info{$s, "p_change"} = conv($t)
					if $p eq "Diff. Vortag";

	# Volume is in millions sometimes, and sometimes not
	#			$info{$s, "volume"} = conv($t)
	#				if $p =~ /Tages-Vol\./;

				# currency is sometimes missing from this field
				if ($p =~ /Uhr$/ and not defined $info{$s, "currency"}) {
					$info{$s, "currency"} = substr($t, -3);
				}

				# set currency from Währung if it's invalid
                                if ($p =~ /W.hrung/ and
                                    $info{$s, "currency"} !~ /[A-Z]{3}/) {
				        $info{$s, "currency"} = substr(uc $t, -3);
				        $info{$s, "currency"} = "EUR" if
				                $info{$s, "currency"} !~ /[A-Z]{3}/;
				}

				if ($p eq "Zeit" and $t ne "--"
				    and not defined $info{$s, "time"}) {
					# hope date format doesn't change again
					$t =~ /(.+)\s+(.+)/;
					my ($date, $time) = ($1, $2);
					print $log "$date -- $time" if $debug > 1;
					$quoter->store_date(\%info, $s,
							    {eurodate => $date}
					);
					if ($time eq "--") {
					    $info{$s, "time"} = "00:00";
					} else {
					    $info{$s, "time"} = $time;
					}
				}

				if ($p =~ /Aktuell$|R.cknahmepreis$/) {
					print $log "XXX $p --- $t\n" if $debug > 2;
					$info{$s, "last"} =
						$info{$s, "price"} = conv($t);
				}

				$p = $t;
			}

			if ($info{$s, "low"} and $info{$s, "high"}) {
				$info{$s, "day_range"} =
					$info{$s, "low"} . " - " .
					$info{$s, "high"};
			}

			if ($info{$s, "year_low"} and $info{$s, "year_high"}) {
				$info{$s, "year_range"} =
					$info{$s, "year_low"} . " - " .
					$info{$s, "year_high"};
			}

			# set price from bid and ask if undefined
			$info{$s, "price"} = $info{$s, "ask"}
				if not $info{$s, "price"} and
				   not $info{$s, "last"} and
				   not $info{$s, "nav"};
		}

		# sometime during fall 2010, comdirect stopped supporting
		# "symbol.exchange" searches, so retry a price search if the
		# exchange indicated in the symbol doesn't return anything
		if (not $info{$s, "price"} and not $info{$s, "last"} and
		    not $info{$s, "nav"} and $search =~ /\./) {
		    	$search =~ s/([^\.]+)\..*/$1/;
		    	goto again;
		}

		$info{$s, "method"} = "comdirect";
		$info{$s, "success"} = 1 unless not defined $info{$s, "price"};

		# *STDOUT = *OLD_STDOUT;
		# *STDERR = *OLD_STDERR;

		print $log $info{$s, "price"} . "\n" if $debug > 2;
		print $log Dumper \%info if $debug;
	}

	return wantarray ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::Comdirect - Obtain fonds quotes from Comdirect Bank.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new("Comdirect");

    %info = Finance::Quote->fetch("comdirect", "DE0008474511");

=head1 DESCRIPTION

This module obtains fund prices from Comdirect Bank, http://www.comdirect.de/.
The Comdirect website supports retrieval by name, WKN or ISIN.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Comdirect:
name, date, price, last, method.

=head1 SEE ALSO

Comdirect Bank, http://www.comdirect.de/

Finance::Quote;

=cut
