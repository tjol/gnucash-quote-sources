Extra Finance::Quote modules for use with gnucash
=================================================

To be found here:

 * `BitstampEUR.pm`: a *“bitstampeur”* method that gets the latest Bitcoin prices
   in euro (€) from Bitstamp. This **only accepts** the symbols `BTC` and `BTCEUR`.
   These two are equivalent.

 * `MStarnl.pm`: a modified version of `MStaruk.pm` which fetches data from the
   Dutch edition of Morningstar rather than the British one.

 * `Comdirect.pm`: a copy of [Lars Eggert][eggert]'s [module][eggert-code] to
   fetch data from the German Comdirect bank, as linked to in the
   [GnuCash documentation][gcdoc-a1].

These have to be installed at a strategic location in the Perl package tree
on you machine; for me, this appears to be `/usr/share/perl5/Finance/Quote/`.
The modules also have to be listed in `.../Finance/Quote.pm` to be found by
GnuCash. Thanks to Stephan Paukner for [explaining how to add quote sources][paukner]
on his blog.


[eggert]: https://eggert.org/
[eggert-code]: https://eggert.org/software/Comdirect.pm
[gcdoc-a1]: https://www.gnucash.org/docs/v2.6/C/gnucash-help/apas01.html
[paukner]: http://stephan.paukner.cc/syslog/archives/401-How-to-add-new-quote-sources-to-GnuCash.html

