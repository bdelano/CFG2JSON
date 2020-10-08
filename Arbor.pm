package CFG2JSON::Arbor;
use strict;
use NetAddr::IP;
use Data::Dumper;
my $gbics;

sub new{
  $gbics=();
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
    $obj->{model}=$1 if $_=~/# System Board Model: (.*)/i;
    $obj->{version}=$1 if $_=~/# Version: Peakflow SP (.*)/i;
    $obj->{serial}=$1 if $_=~/# Chassis Serial Number: (.*)/i;
    $obj->{processor}=$1 if $_=~/# Processor: (.*)/i;
    if($_=~/# (Slot [\d]+): (.*?): (.*)/i){
      my $slot=lc($1);
      my $key=lc($2);
      my $val=lc($3);
      $key=~s/serial number/serial/;
      $key=~s/model/part_id/;
      $slot=~s/\s+//;
      if($key=~/firmware|type/){
        $obj->{slots}{$slot}{description}=$obj->{slots}{$slot}{description}." $val";
      }else{
        $obj->{slots}{$slot}{$key}=$val;
      }
      $obj->{slots}{$slot}{name}=$slot;
      #$obj->{slots}{$slot}{manufacturer}='arbor';
    }elsif($_=~/# Memory Device: ([\d]+.*)\s(DIM.*)/i){
      $obj->{dimms}{$2}{description}=$1;
      $obj->{dimms}{$2}{name}=$2;
      #$obj->{memory}{$2}{manufacturer}='arbor';
    }
  }
  $obj->{model}=$obj->{slots}{slot1}{model} if $obj->{slots} && $obj->{model} eq 'Not Specified';
  return $obj;
}

sub getinterfaces{
  my ($intchunk,$ints);
  for(split("\n",$_[0])){
    $intchunk.=$1."<nl>" if $_=~/^#INT:(.*)/i;
  }
  $intchunk=~s/\s+(eth|tms|mgt)/<interface>$1/g;
  my @i_arr=split(/<interface>/,$intchunk);
  shift @i_arr;
  for(@i_arr){
    my @intinfo=split("<nl>",$_);
    my $intbase=shift @intinfo;
    #print "intbase:$intbase \n";
    my ($int,$inttype,$status,$mtu)=($1,$3,$4,$5) if $intbase=~/((eth|tms|mgt)[\d\.]+)\s(.*), Interface is (.*), mtu ([\d]+)/i;
    $inttype=~s/\s+//g;
    $ints->{$int}{mtu}=$mtu;
    $ints->{$int}{status}=$status;
    if($int=~/.*\..*/){
      $ints->{$int}{formfactor}='virtual';
    }else{
      $ints->{$int}{formfactor}=getFF($inttype);
    }
    for(@intinfo){
      $ints->{$int}{localmac}=lc($1) if $_=~/.*Hardware: ([\w\:]+)/;
      if($_=~/Inet: ([\d\.]+) netmask ([\d\.]+) .*/){
        my ($ip,$bits)=_getCIDR($1,$2);
        push(@{$ints->{$int}{ipaddress}},{ip=>$ip,bits=>$bits,type=>'interface',version=>'4'})  if $ip ne '0.0.0.0';
      }elsif($_=~/Inet6: (.*) prefixlen ([\d]+)/){
        push(@{$ints->{$int}{ipaddress}},{ip=>$1,bits=>$2,type=>'interface',version=>'6'});
      }
    }
  }
  return $ints;
}
sub getFF{
  my $ff->{TenGigabitEthernet}='SFP+10G-SR';
  $ff->{TenGigabitFiber}='SFP+10G-SR';
  $ff->{GigabitFiber}='SFP1000BASE-SX';
  $ff->{GigabitEthernet}='10/100/1000BASETX';
  return $ff->{$_[0]};
}

sub _getCIDR{
  my ($ip,$mask)=@_;
  my $ninet = new NetAddr::IP "$ip $mask";
  my $bits=$ninet->masklen;
  return ($ip,$bits);
}

1
