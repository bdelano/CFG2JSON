package CFG2JSON::Cisco;
use strict;
use NetAddr::IP;
use Data::Dumper;
my $gbics;

sub new{
  my $class = shift;
  my $args = { @_ };
  my $config=$args->{config};
  my $dev=getinfo($config);
  $gbics=buildGbicHash($config);
  print Dumper $gbics;
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
  $c =~ s/\s+!//ig;
  $c =~ s/([\w])!/$1/ig;
  my @ints_arr=split("!",$c);
  shift @ints_arr;
  for(@ints_arr){
    my $int=$_;
    if(lc($int)=~/<nl>interface\s+([fskpmvlgibrtortchanel\d\-\/\.]+[\d])<nl>(.*)/ig){
      my $i=$1;
      my $rc=$2;
      $ints->{$i}{mtu}='1500';
      $rc=~s/!<nl>router$//i;
      for(split/<nl>/,$rc){
        my $l=$_;
        $ints->{$i}{description}=$1 if $l=~/\s+description\s([!\"\'():,\@.&\w\s\/\-]+).*$/i;
        $ints->{$i}{vrf}=$1 if $l=~/\s+vrf forwarding (.*)/i;
        $ints->{$i}{mtu}=$1 if $l=~/\s+mtu\s([\d]+)/i;
        if($i=~/vlan.*/){
          $ints->{$i}{formfactor}='virtual';
        }elsif($gbics->{$i}){
          $ints->{$i}{formfactor}=$gbics->{$i}{formfactor};
          $ints->{$i}{serial}=$gbics->{$i}{serial};
        }elsif($i=~/gigabitethernet/){
          $ints->{$i}{formfactor}='10/100/1000BaseTX';
        }elsif($i=~/fast/){
          $ints->{$i}{formfactor}='100BASE-TX';
        }else{
          $ints->{$i}{formfactor}='physical';
        }
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

sub buildGbicHash{
  my $c=shift;
  $c =~ s/\n/<nl>/g;
  $c =~ s/<nl>!PID:/PID:/g;
  $c =~ s/<nl>!VID:/VID:/g;
  $c =~ s/<nl>!SN:/SN:/g;
  my $gb;
  for(split(/<nl>/,$c)){
    #if($_=~/!NAME: \"(.*)\"(\s+)?DESCR:\s\"(.*)\"(\s)?PID:\s(.*)VID:\s(.*)SN:\s(.*)/){
    if($_=~/!NAME: \"(.*)\",(\s+)?DESCR:\s\"(.*)\"(\s)?PID:\s(.*)VID:\s(.*)SN:\s(.*)/){
      my $int=lc($1);
      my $descr=$3;
      my $pid=$5;
      my $vid=$6;
      my $sn=$7;
      $gb->{$int}{formfactor}=$descr;
      $gb->{$int}{serial}=$sn;
    }
  }
  return $gb;
}

1
