package CFG2JSON::Juniper;
use strict;
use Data::Dumper;
my $riint;
my $gbics;
my $errors;

sub new{
  my $class = shift;
  my $args = { @_ };
  my $config=$args->{config};
  $riint=sortris($config); #build hash of vrf interfaces
  my $dev=getinfo($config);
  $gbics=buildGbicHash($config,$dev->{model});
  #print Dumper $gbics;
  my $interfaces=getinterfaces($config);
  my $nats=getnats($config);
  $dev->{interfaces}=$interfaces;
  $dev->{nats}=$nats;
  my $self = bless {device=>$dev}, $class;
}

sub getinfo{
  my @config=split("\n",$_[0]);
  my $obj={};
  for(@config){
    if($_=~m/# Chassis\s+([\w]+)\s+([\w]+)/i){
      if($obj->{serial}){
        $obj->{serial}=$obj->{serial}.','.$1
      }else{
        $obj->{serial}=$1;
      }
      $obj->{model}=$2;
    }
    $obj->{version}=$1 if $_=~/.*O\/S\s+Version\s(.*)\sby builder.*/i;
  }
  return $obj;
}

sub getinterfaces {
  my $c = shift;
  $c=~s/\n/<nl>/g;
  my @cfglines;
	my @cfglines=split(/<nl>/,$c);
	my @infolines = grep(/set interfaces/,@cfglines);
  #print @infolines;
	my %int_hold;
	my %intcount_hash=();
  my $ints;
	#populate hashes and count different interfaces;
  shift @infolines;
	for(@infolines){
		my $l=$_;
    #print $l."\n";
		if($l=~/.*interfaces\s([\w\-\/]+)\s(unit\s([\d]+)\s)?.*/i){
			my ($bi,$si)=($1,$2);
      $si='unit 0' if !$si;
			my $wc="$bi $si";
			$wc=~s/\s$//ig;
			$wc=~s/\sunit\s/\./i;
			my $ic=$intcount_hash{$bi};
			if($int_hold{$wc}){
				$int_hold{$wc}=$int_hold{$wc} . '<nl>' . $l;
			}else{
				$int_hold{$wc}=$l;
      	if($ic){
      	$ic++;
      	$intcount_hash{$bi}=$ic;
      	}else{
      	$intcount_hash{$bi}=1;
      	}
			}
		}elsif($l=~/.*interfaces\s(.*)/){
      push(@{$errors},'NOMATCH:'.$1);
		}
	}
	for(keys %int_hold){
		my $interface=$_;
		my $rawcfg=$int_hold{$interface};
    if($interface=~/\./i){
			my $ti=$interface;
			$ti=~s/\.0$//ig;
      my %al_hash=();
      for(grep(/$ti /,@cfglines)){
	      if($_=~/set interfaces $ti .*/i){
	      }elsif($al_hash{$_}){
	      }else{
	      	$al_hash{$_}='1';
	      	$rawcfg.='<nl>' . $_;
	      }
      }
      for(grep(/$ti$/,@cfglines)){
        if($_=~/set interfaces $ti .*/i){
        }elsif($al_hash{$_}){
        }else{
        	$al_hash{$_}='1';
        	$rawcfg.='<nl>' . $_;
        }
      }
			my ($bi,$unit)=split(/\./,$ti);
			if($unit){
				for(grep(/$bi unit $unit/,@cfglines)){
					if($_=~/set interfaces $bi unit $unit.*/i){
					}elsif($al_hash{$_}){
					}else{
						$al_hash{$_}='1';
						$rawcfg.='<nl>' . $_;
					}
				}
			}
			if($interface ne $ti){
				for(grep(/$interface/,@cfglines)){
					if($_=~/set interfaces $ti.*/i){
					}elsif($al_hash{$_}){
					}else{
						$al_hash{$_}='1';
						$rawcfg.='<nl>' . $_;
					}
				}
			}
		}

		$rawcfg=~s/^<nl>//i;
		$rawcfg=~s/<nl><nl>/<nl>/ig;
		$rawcfg=~s/[^a-zA-Z0-9\s:_\-()<>{}\/\.]*//g;
		my $vlanlist = '';
		my $vlc=0;
		my $intsec=0;
    my $v6intsec=0;
		my %ipc_hash;
    $ints->{$interface}{vrf}=$riint->{$interface} if $riint->{$interface};
    $ints->{$interface}{mtu}='1500';
		for(split(/<nl>/,$rawcfg)){
			my $intdet=$_;
      $ints->{$interface}{description}=$1 if $intdet=~/.*description\s(.*)$/ig;
      $ints->{$interface}{mtu}=$1 if $intdet=~/.*mtu\s([\d]+)/ig;
      $ints->{$interface}{vlan}=$1 if $intdet=~/.*vlan-id\s([\d]+)/ig;
			if($intdet=~/127\.0\.0\.1/){
			}elsif($intdet =~ m/.*inet(6)? address\s([\w\.:]+)\/([\d]+)(.*)/ig){
        my ($version,$ip,$bits,$info)=($1,$2,$3,$4);
        $version='4' if !$version;
        push(@{$ints->{$interface}{ipaddress}},{ip=>$1,bits=>$bits,type=>'vrrp',version=>$version}) if $info=~/virtual-address\s(.*)/;
        push(@{$ints->{$interface}{ipaddress}},{ip=>$ip,bits=>$bits,type=>'interface',version=>$version}) if !$ipc_hash{$ip};
        $ipc_hash{$ip}='hold';
      }elsif($intdet=~/set interfaces (.*) [\w-]+ther-options\sredundant-parent\s(.*)/){
        my $pcinterface=$1.'.0';
        my $pcid=$2.'.0';
        if($interface=~/reth[\d]+/){
          $ints->{$interface}{formfactor}='LAG';
          push(@{$ints->{$interface}{children}},$pcinterface);
        }else{
          $ints->{$pcinterface}{parent}=$pcid;
        }
      }elsif($intdet =~ m/set interfaces (.*)\s[\w-]+ther-options 802.3ad.*(ae[\d]+)/ig){
				my $pcinterface = $1 . '.0';
				my $pcid=$2.'.0';
				if($interface=~/ae[\d]+/i){
          $ints->{$interface}{formfactor}='LAG';
          push(@{$ints->{$interface}{children}},$pcinterface);
				}else{
          $ints->{$pcinterface}{parent}=$pcid;
        }
      }
		}
	}
  #determine interface type:
  for(keys %int_hold){
    my $interface=$_;
    if(!$ints->{$interface}{formfactor}){
      if($interface=~/.*\.([1-9][\d]+)/i){
        $ints->{$interface}{formfactor}='virtual';
      }elsif($interface=~m/^(reth|ae|lo|st)/i){
        $ints->{$interface}{formfactor}='virtual';
      }else{
        my $bi=$interface;
        $bi=~s/(xe|et)-//i;
        if($gbics->{$bi}){
          $ints->{$interface}{formfactor}=$gbics->{$bi}{formfactor};
          $ints->{$interface}{serial}=$gbics->{$bi}{serial};
        }else{
          $ints->{$interface}{formfactor}='physical';
        }
      }
    }
  }
	return $ints;
}

sub getnats{
	my $c = shift;
  $c=~s/\n/<nl>/g;
  my @nat_arr;
	my %gaddr_hash;
	for(split('<nl>',$c)){
		if($_=~/set security address-book global address (.*)\s([\d\.\/]+)/i){
			$gaddr_hash{$1}=$2;
		}
	}
	my %loc_hash;
	my %rem_hash;
	my %raw_hash;
	for(split('<nl>',$c)){
		if($_=~/set security nat static rule-set (.*) rule (.*) match destination-address (.*)/){
			my $rs=$1;
			my $r=$2;
			my $key=$rs.'-!'.$r;
			$loc_hash{$key}=$3;
			$raw_hash{$key}=$raw_hash{$key}.$_.'<nl>';
		}elsif($_=~/set security nat static rule-set (.*) rule (.*) then static-nat prefix(-name)? (.*)/){
			my $rs=$1;
			my $r=$2;
			my $remip=$4;
			my $key=$rs.'-!'.$r;
			if(!$rem_hash{$key}=~/[\d\.\/]+/){
				$rem_hash{$key}=$remip;
			}
			$raw_hash{$key}=$raw_hash{$key}.$_.'<nl>';
		}
	}
	my $i=1;
	for(keys %loc_hash){
    my $natobj;
		my $loc=$loc_hash{$_};
		my $rem=$rem_hash{$_};
		my $raw=$raw_hash{$_};
		my ($ruleset,$rule)=split('-!',$_);
		if($gaddr_hash{$rem}){
			$rem=$gaddr_hash{$rem};
		}
		my $description="$ruleset $rule $loc to $rem";
		my $int='nat'.$i;
		$i++;
    $natobj->{local}=$loc;
    $natobj->{remote}=$rem;
    $natobj->{description}=$raw;
    push(@nat_arr,$natobj)
	}
  return \@nat_arr;
}

sub sortris {
  my $c = shift;
  $c=~s/\n/<nl>/g;
  my $riret;
	my @cfglines=split(/<nl>/,$c);
	my @infolines = grep(/set routing-instance.*interface.*/,@cfglines);
	my $infoline;
  foreach $infoline(@infolines){
  	$infoline =~ s/\s\s//ig;
		if($infoline =~ m/set\srouting-instances\s([\w\-\_]+)\sinterface\s([\w\-\/\.]+)/ig){
	    my $ri = $1;
	    my $interface = $2;
	    $riret->{$interface} = $ri;          #print "NOMATCHRI: $infoline \n";
		}
	}
  return $riret;
}

sub buildGbicHash{
  my ($c,$model)=@_;
  my %fpcstart_hash;
  $fpcstart_hash{'SRX5400_0'}='0';
  $fpcstart_hash{'SRX5400_1'}='3';
  $fpcstart_hash{'SRX1500_0'}='0';
  $fpcstart_hash{'SRX1500_1'}='7';
  $c=~s/\n/<nl>/g;
  my $inv;
  for(split(/show chassis/,$c)){
    if($_=~/hardware detail/){
      my ($node,$fpc,$mic,$pic,$xcvr,$info);
      for(split(/<nl>/,$_)){
        my $l=$_;
        if(lc($l)=~/\s+node([\d]+):.*/){
          $node=$1;
        }elsif(lc($l)=~/\s+fpc\s([\d]+)\s+.*/){
          $fpc=$1;
        }elsif(lc($l)=~/\s+mic\s([\d]+)\s+.*/){
          $mic=$1;
        }elsif(lc($l)=~/\s+pic\s([\d]+)\s+.*/){
          $pic=$1;
        }elsif(lc($l)=~/\s+xcvr\s([\d]+)\s+(.*)/){
          $xcvr=$1;
          my @info=split(/\s+/,$2);
          my $modnum=$fpc+($fpcstart_hash{$model.'_'.$node});
          my $int=$modnum.'/';
          $int.=$mic.'/' if $mic;
          $int.=$pic.'/'.$xcvr.'.0';
          $inv->{$int}{serial}=$info[-2];
          $inv->{$int}{formfactor}=$info[-1];
          $inv->{$int}{partnumber}=$info[-3]
        }
      }
    }
  }
  return $inv;
}

1
