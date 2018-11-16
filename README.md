# CFG2JSON
converts rancid configuration files to JSON format

## Purpose
I am currently working on pushing configuration up to various DCIM tools and needed to get all my device configs in a standardized format.

## Usage
To use this script simple clone this to whatever server stores your rancid configuration files. From there you just need to understand the path to your configs. Typically its `{basepath}/{site}/{hostname}` and this is what the script expects as variables. If this doesn't meet your needs feel free to hack up Scape.pm to whatever you need.

Please look at the example.pl file above for inspiration

## Dependencies
* Perl (tested on 5.14)
* FindBin https://metacpan.org/pod/FindBin
* NetAddr::IP https://metacpan.org/pod/NetAddr::IP
