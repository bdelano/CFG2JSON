package Cisco;
use strict;
use NetAddr::IP;
use Data::Dumper;

sub new{
  my ($class,$args)=@_;
  my $config=$args->{config};
  my $dev=getinfo($config);
  my $interfaces=getinterfaces($config);
  #my $interfaces={};
  $dev->{interfaces}=$interfaces;
  my $self = bless {device=>$dev}, $class;
}

sub getinfo{
  my @config=split("\n",$_[0]);
  my $obj={};
  for(@config){
    $obj->{serial}=$1 if $_=~/!Serial Number:\s+(.*)/i;
    $obj->{model}=$1 if $_=~/!Model number\s+:\s+(.*)/i;
    $obj->{version}=$1 if $_=~/!BOOTLDR: Version \s+(.*)/i;
  }
  return $obj;
}

sub getinterfaces{
  my $c = shift;
  my $ints;
  $c =~ s/\n/<nl>/g;
  $c =~ s/\n/<nl>/ig;
  $c =~ s/\s+!//ig;
  $c =~ s/([\w])!/$1/ig;
  my @ints_arr=split("!",$c);
  shift @ints_arr;
  for(@ints_arr){
    my $int=$_;
    if(lc($int)=~/<nl>interface\s+([fskpmvlgibrtortchanel\d\-\/\.]+[\d])<nl>(.*)/ig){
      my $i=$1;
      my $rc=$2;
      $rc=~s/!<nl>router$//i;
      for(split/<nl>/,$rc){
        my $l=$_;
        $ints->{$i}{description}=$1 if $l=~/\s+description\s([!\"\'():,\@.&\w\s\/\-]+).*$/i;
        $ints->{$i}{vrf}=$1 if $l=~/\s+vrf forwarding (.*)/i;
        if($l=~/\s+ip\saddress\s([.\d]+)\s([\d\.]+).*$/i){
          my $ipaddress=_getCIDR($1,$2);
          $ints->{$i}{ipaddress}=$ipaddress;
        }
      }
    }
  }
  return $ints
}

sub _getCIDR{
  my ($ip,$mask)=@_;
  my $ninet = new NetAddr::IP "$ip $mask";
  my $bits=$ninet->masklen;
  my $ipbits=$ip.'/'.$bits;
  return $ipbits;
}

1
