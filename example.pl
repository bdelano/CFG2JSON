#!/usr/bin/perl
use FindBin;
use lib $FindBin::Bin;
use strict;
use Scrape;
my $s=Scrape->new({
filepath=>'/home/rancid/var/rancid', # root to your rancid directory
sitename=>'sites', #usually rancid configs are grouped into sites
hostname=>'mydevice' #rancid hostname of the device
});

#print $s;
#print $s->{device};
print $s->json('device');
