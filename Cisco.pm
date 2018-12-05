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
    if($int=~/<nl>interface\s+([fskpmvlgibrtortchanel\d\-\/\.]+[\d])<nl>(.*)/ig){
      my $i=$1;
      my $rc=$2;
      $ints->{$i}{mtu}='1500';
      $rc=~s/!<nl>router$//i;
      if($i=~/^(vlan|port).*/i){
        $ints->{$i}{formfactor}='virtual';
      }elsif($gbics->{lc($i)}){
        $ints->{$i}{formfactor}=$gbics->{lc($i)}{formfactor};
        $ints->{$i}{serial}=$gbics->{lc($i)}{serial};
      }elsif($i=~/gigabitethernet/i){
        $ints->{$i}{formfactor}='10/100/1000BaseTX';
      }elsif($i=~/fast/i){
        $ints->{$i}{formfactor}='100BASE-TX';
      }else{
        $ints->{$i}{formfactor}='physical';
      }
      for(split/<nl>/,$rc){
        my $l=$_;
        push(@{$ints->{$i}{ipaddress}},{ip=>$1,type=>'vrrp',version=>'4'}) if $l=~/vrrp\s[\d]+\sip\s([\d]+\..*)/;
        push(@{$ints->{$i}{ipaddress}},{ip=>$1,type=>'vrrp',version=>'6'}) if $l=~/vrrp\s[\d]+\sip\s([\w]+:.*)/;
        if($l =~ m/\s+switchport\saccess\svlan\s([\d]+.*)$/){
          push(@{$ints->{$i}{vlans}},$1) if $l =~ m/\s+switchport\saccess\svlan\s([\d]+.*)$/;
          $ints->{$i}{mode}='access';
        }
        if($l =~ /\sswitchport\strunk\sallowed\svlan\s(add\s)?([-,\d.*]+)$/){
          $ints->{$i}=addGroups($ints->{$i},$2);
          $ints->{$i}{mode}='tagged';
        }
        $ints->{$i}{description}=$1 if $l=~/\s+description\s([!\"\'():,\@.&\w\s\/\-]+).*$/i;
        $ints->{$i}{vrf}=$1 if $l=~/\s+vrf forwarding (.*)/i;
        $ints->{$i}{mtu}=$1 if $l=~/\s+mtu\s([\d]+)/i;
        if($l=~/\s+ip(v6)?\saddress\s([:.\w]+)\s([\d\.]+).*$/i){
          my $version=$1;
          $version=~s/v//;
          $version='4' if !$version;
          my ($ip,$bits)=_getCIDR($2,$3);
          push(@{$ints->{$i}{ipaddress}},{ip=>$ip,bits=>$bits,type=>'interface',version=>$version});
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
  return ($ip,$bits);
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

sub addGroups{
  my ($int,$info)=@_;
  my @p_arr;
  for(split(/,/,$info)){
    my $pn=$_;
    if($pn=~/([\d]+\/)?([\d]+)-([\d]+\/)?([\d]+)/){
      my $i1s=$1;
      my $i1p=$2;
      my $i2s=$3;
      my $i2p=$4;
      for($i1p...$i2p){
        my $p=$i1s.'/'.$_;
        $p=$_ if !$i1s;
        push(@{$int->{vlans}},$_)
      }
    }else{
      push(@{$int->{vlans}},$pn)
    }
  }
  return $int;
}

1
