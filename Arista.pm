package CFG2JSON::Arista;
use strict;
use Data::Dumper;
my $gbics;

sub new{
  my $class = shift;
  my $args = { @_ };
  my $config=$args->{config};
  $gbics=buildGBICHash($config);
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
    $obj->{serial}=$1 if $_=~/!Serial number:\s+(.*)/i;
    $obj->{model}=$1 if $_=~/!Model: Arista\s+(.*)/i;
    $obj->{version}=$1 if $_=~/!Software image version:\s+(.*)/i;
  }
  return $obj;
}

sub buildGBICHash{
  my $c = shift;
  $c =~ s/\n/<nl>/g;
  my $ret;
  for(split(/!System has/,$c)){
    if($_=~/.*transceiver slots/){
      for(split(/<nl>/,$_)){
        if($_=~/!\s+([\d\/]+.*)/){
          my @list=split(/\s+/,$1);
          if($list[1] eq 'Not'){
            $ret->{$list[0]}{vendor}='notpresent';
            $ret->{$list[0]}{model}='notpresent';
            $ret->{$list[0]}{serial}='notpresent';
          }else{
            $ret->{$list[0]}{vendor}=$list[1];
            $ret->{$list[0]}{model}=$list[-3];
            $ret->{$list[0]}{serial}=$list[-2];
          }
        }
      }
    }
  }
  return $ret;
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
    if($int=~/<nl>interface\s+([fskpmvlgibrtortchanel\d\-\/\.]+[\d])\s?<nl>\s?(.*)/ig){
      my $i=$1;
      if($i=~/(vlan|loop)/){
        $ints->{$i}{formfactor}='virtual';
      }elsif($i=~/port-/){
        $ints->{$i}{formfactor}='lag';
      }elsif($i=~/.*\.[\d]+$/){
        $ints->{$i}{formfactor}='virtual';
      }else{
        my $bi=$i;
        $bi=~s/ethernet//;
        $bi=~s/\/1$//;
        #print "i:$i bi:$bi\n";
        if($gbics->{$bi}{model}){
          $ints->{$i}{formfactor}=$gbics->{$bi}{model};
          $ints->{$i}{serial}=$gbics->{$bi}{serial};
        }elsif($i=~/management/){
          $ints->{$i}{formfactor}='1000BaseTX';
        }else{
          $ints->{$i}{formfactor}='physical';
        }

      }
      $ints->{$i}{mtu}='1500';
      my $rc=$2;
      $rc=~s/!<nl>router$//i;
      for(split/<nl>/,$rc){
        my $l=$_;
        $ints->{$i}{description}=$1 if $l=~/\s+description\s([!\"\'():,\@.&\w\s\/\-]+).*$/i;
        push(@{$ints->{$i}{ipaddress}},{ip=>$1,bits=>$2,type=>'interface',version=>'4'}) if $l=~/\s+ip\saddress\s([\d]+\..*)\/([\d]+)$/;
        $ints->{$i}{vrf}=$1 if $l=~/\s+vrf forwarding (.*)/i;
        $ints->{$i}{mtu}=$1 if $l=~/\s+mtu\s([\d]+)/i;
        if($l=~/\s+channel-group\s([\d]+)\smode active/){
          $ints->{$i}{parent}='port-channel'.$1;
          push(@{$ints->{'port-channel'.$1}{children}},$i);
        }
      }
    }
  }
  return $ints;
}

1
