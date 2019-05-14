package CFG2JSON::Juniper;
use strict;
use Data::Dumper;
use NetAddr::IP;
my $ints;
my $riint;
my $gbics;
my $nats;
my $errors;
my $pools; #holds net pool information
my $addrbook; #holds global address book for prefix names

sub new{
  my $class = shift;
  my $args = { @_ };
  my $config=$args->{config};
  sortris($config); #build hash of vrf interfaces
  my $dev=getinfo($config);
  buildGbicHash($config,$dev->{model});
  #print Dumper $gbics;
  getinterfaces($config);
  #my $interfaces={};
  getnats($config);
  $dev->{interfaces}=$ints;
  $dev->{nats}=$nats if $nats;
  my $self = bless {device=>$dev}, $class;
}

sub getinfo{
  my @config=split("\n",$_[0]);
  my $obj={};
  for(@config){
    my $l=$_;
    push(@{$obj->{syslog}},$1) if $l=~/set system syslog host (.*) any warning/i;
    push(@{$obj->{snmp}},$1) if $l=~/set snmp trap-group .* targets ([\d\.]+)/i;
    push(@{$obj->{tacacs}},$1) if $l=~/set system tacplus-server ([\d\.]+) source-address/i;
    $obj->{taaccounting}=$1 if $_=~/set system accounting destination (.*)/i;
    if($l=~m/# Chassis\s+([\w]+)\s+([\w]+)/i){
      if($obj->{serial}){
        $obj->{serial}=$obj->{serial}.','.$1
      }else{
        $obj->{serial}=$1;
      }
      $obj->{model}=$2;
    }
    $obj->{version}=$1 if $l=~/.*O\/S\s+Version\s(.*)\sby builder.*/i;
    $obj->{version}=$1 if $l=~/# Junos: (.*)/;
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
		my $rc=$int_hold{$interface};
    if($interface=~/\./i){
			my $ti=$interface;
			$ti=~s/\.0$//ig;
      my %al_hash=();
      for(grep(/$ti /,@cfglines)){
	      if($_=~/set interfaces $ti .*/i){
	      }elsif($al_hash{$_}){
	      }else{
	      	$al_hash{$_}='1';
	      	$rc.='<nl>' . $_;
	      }
      }
      for(grep(/$ti$/,@cfglines)){
        if($_=~/set interfaces $ti .*/i){
        }elsif($al_hash{$_}){
        }else{
        	$al_hash{$_}='1';
        	$rc.='<nl>' . $_;
        }
      }
			my ($bi,$unit)=split(/\./,$ti);
			if($unit){
				for(grep(/$bi unit $unit/,@cfglines)){
					if($_=~/set interfaces $bi unit $unit.*/i){
					}elsif($al_hash{$_}){
					}else{
						$al_hash{$_}='1';
						$rc.='<nl>' . $_;
					}
				}
			}
			if($interface ne $ti){
				for(grep(/$interface/,@cfglines)){
					if($_=~/set interfaces $ti.*/i){
					}elsif($al_hash{$_}){
					}else{
						$al_hash{$_}='1';
						$rc.='<nl>' . $_;
					}
				}
			}
		}

		$rc=~s/^<nl>//i;
		$rc=~s/<nl><nl>/<nl>/ig;
		$rc=~s/[^a-zA-Z0-9\s:_\-()<>{}\/\.]*//g;
		my $vlc=0;
		my $intsec=0;
    my $v6intsec=0;
		my %ipc_hash;
    $ints->{$interface}{vrf}=$riint->{$interface} if $riint->{$interface};
    $ints->{$interface}{mtu}='1500';
    $ints->{$interface}{rawconfig}=$rc;
		for(split(/<nl>/,$rc)){
			my $intdet=$_;
      $ints->{$interface}{description}=$1 if $intdet=~/.*description\s(.*)$/ig;
      $ints->{$interface}{mtu}=$1 if $intdet=~/.*mtu\s([\d]+)/ig;
      if($intdet=~/.*vlan-id\s([\d]+)/ig){
        push(@{$ints->{$interface}{vlans}},$1);
        $ints->{$interface}{mode}='sub';
      }
      if ($intdet =~ m/.*vlan members\s(.*)/ig){
        push(@{$ints->{$interface}{vlans}},$1);
        $ints->{$interface}{mode}='tagged';
      }
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
  $ints->{console}{formfactor}='NONE';
}

sub findlocint{
  my $ip=shift;
  my $nip=new NetAddr::IP $ip;
  for(keys %{$ints}){
    my $i=$_;
    if($ints->{$i}{ipaddress}){
      for(@{$ints->{$i}{ipaddress}}){
        my $ipinfo=$_;
        my $n=new NetAddr::IP $ipinfo->{ip}.'/'.$ipinfo->{bits};
        if($n->contains($nip)){
          return {'int'=>$i,'bits'=>$ipinfo->{bits},'ip'=>$ipinfo->{ip}};
        }
      }
    }
  }
  return '';
}

sub listfromto{
  my $str=$_[0];
  my $retl;
  if($str=~/ to /){
    my ($s,$e)=split(" to ",$str);
    if($s eq $e){
      push(@{$retl},getIPinfo($s));
    }else{
      my ($sb,$slo,$sbits)=($1,$2,$3) if $s=~/([\.\d]+)\.([\d]+)(\/[\d]+)/;
      my ($eb,$elo,$ebits)=($1,$2,$3) if $e=~/([\.\d]+)\.([\d]+)(\/[\d]+)/;
      if ($sb eq $eb){
        for($slo...$elo){
          push(@{$retl},getIPinfo($sb.'.'.$_.$sbits));
        }
      }
    }
  }else{
    push(@{$retl},getIPinfo($str))
  }
  return $retl;
}

sub getnats{
  my $c = shift;
  $c=~s/\n/<nl>/g;
  for(split('<nl>',$c)){
    if($_=~/set security address-book global address (.*)\s([\d\.\/]+)/i){
			$addrbook->{$1}=$2;
		}elsif($_=~/set security nat source pool (.*) address (.*)/){
      my $ips=listfromto($2);
      $pools->{$1}=$ips;
    }
  }

  for(split('<nl>',$c)){
    if($_=~/set security nat (source|static) rule-set (.*) rule (.*) (match|then) (.*)/){
      my ($ss,$set,$rule,$action,$end)=($1,$2,$3,$4,$5);
      if($action eq 'match'){
        if($end=~m/destination-address (.*)/){
          my $info=getIPinfo($1);
          push(@{$nats->{$set}{$rule}{match}{destination}},$info);
        }elsif($end=~m/source-address (.*)/){
          my $info=getIPinfo($1);
          push(@{$nats->{$set}{$rule}{match}{source}},$info);
        }
      }elsif($action eq 'then'){
        if($end=~/static-nat prefix(-name)? (.*)/){
          my $info=getIPinfo($2);
          $nats->{$set}{$rule}{type}='static';
          $nats->{$set}{$rule}{then}{static}=$info if $info->{address};
        }elsif($end=~/source-nat pool (.*)/){
          $nats->{$set}{$rule}{type}='pool';
          $nats->{$set}{$rule}{then}{pool}{name}=$1;
          $nats->{$set}{$rule}{then}{pool}{addresses}=$pools->{$1};
        }else{
          $nats->{$set}{$rule}{type}='nocat';
          $nats->{$set}{$rule}{then}=$end;
        }
      }
    }
  }
}

sub getIPinfo{
  my $addr=shift;
  my $name;
  if($addrbook->{$addr}){
    $name=$addr;
    $addr=$addrbook->{$addr};
  }
  my $obj->{address}=$addr;
  $obj->{name}=$name if $name;
  if($addr=~/^([\d\.]+)\/([\d]+)$/){
    $obj->{version}='v4';
    my ($ip,$bits)=($1,$2);
    $obj->{ip}=$ip;
    $obj->{bits}=$bits;
    my $locint;
    $locint=findlocint($addr) if $bits > 24;
    $obj->{locint}=findlocint($addr) if $locint;
  }elsif($addr=~m/^([\w:])+\/([\d]+)/){
    $obj->{version}='v6';
    my ($ip,$bits)=($1,$2);
    $obj->{ip}=$ip;
    $obj->{bits}=$bits;
    my $locint;
    $locint=findlocint($addr) if $bits > 92;
    $obj->{locint}=findlocint($addr) if $locint;
  }else{
    $obj->{address}='';
  }
  return $obj;
}

sub sortris {
  my $c = shift;
  $c=~s/\n/<nl>/g;
	my @cfglines=split(/<nl>/,$c);
	my @infolines = grep(/set routing-instance.*interface.*/,@cfglines);
	my $infoline;
  foreach $infoline(@infolines){
  	$infoline =~ s/\s\s//ig;
		if($infoline =~ m/set\srouting-instances\s([\w\-\_]+)\sinterface\s([\w\-\/\.]+)/ig){
	    my $ri = $1;
	    my $interface = $2;
	    $riint->{$interface} = $ri;          #print "NOMATCHRI: $infoline \n";
		}
	}
}

sub buildGbicHash{
  my ($c,$model)=@_;
  my %fpcstart_hash;
  $fpcstart_hash{'SRX5400_0'}='0';
  $fpcstart_hash{'SRX5400_1'}='3';
  $fpcstart_hash{'SRX1500_0'}='0';
  $fpcstart_hash{'SRX1500_1'}='7';
  $c=~s/\n/<nl>/g;
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
          $gbics->{$int}{serial}=$info[-2];
          $gbics->{$int}{formfactor}=$info[-1];
          $gbics->{$int}{partnumber}=$info[-3]
        }
      }
    }
  }
}

1
