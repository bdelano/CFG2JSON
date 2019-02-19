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
  my $sn=pop @config;
  $obj->{serial}=$sn if $sn=~/^[\d]+$/;
  return $obj;
}

sub getinterfaces{
  my @config=split("\n",$_[0]);
  my ($holdints,$ints);
  for(@config){
    if($_=~/config\.ports\.(port[\d]+)\.([\w]+)\s(.*)/i){
      my ($int,$key,$value)=($1,$2,$3);
      $int=~s/port/p/;
      $holdints->{$int}{$key}=$value
    }
  }
  #print Dumper $holdints;
  for(keys %{$holdints}){
    my $label=$holdints->{$_}{label};
    $label=~s/-new ceres//i;
    my $i=$_.':'.$label;
    $ints->{$i}{formfactor}='NONE';
    $ints->{$i}{label}=$label;
  }
  return $ints;

}

1
