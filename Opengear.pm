package CFG2JSON::Opengear;
use strict;
use NetAddr::IP;
use Data::Dumper;
my $gbics;

sub new{
  my $class = shift;
  my $args = { @_ };
  my $config=$args->{config};
  my $dev=getinfo($config);
  #print Dumper $gbics;
  my $interfaces=getinterfaces($config);
  #my $interfaces={};
  $dev->{interfaces}=$interfaces;
  my $self = bless {device=>$dev}, $class;
}

sub getinfo{
  my @config=split("\n",$_[0]);
  my $obj={};
  for(@config){
    $obj->{model}=$1 if $_=~/config.system.model\s+(.*)/i;
    $obj->{version}=$1 if $_=~/.*Version\s+([\w\.]+).*/i;
  }
  return $obj;
}

sub getinterfaces{
  my @config=split("\n",$_[0]);
  my $ints;
  for(@config){
    $ints->{$1}{$2}=$3 if $_=~/config\.ports\.(port[\d]+)\.([\w]+)\s(.*)/i;
  }
  return $ints;

}

1
