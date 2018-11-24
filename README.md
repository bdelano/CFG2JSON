# CFG2JSON
converts rancid configuration files to JSON format

## Purpose
I am currently working on pushing configuration up to various DCIM tools and needed to get all my device configs in a standardised format.

## Usage
To use this script simply clone this repository to whatever server stores your rancid configuration files. From there you just need to understand the path to your configs. Typically its `{basepath}/{site}/{hostname}` and this is what the script expects as variables. If this doesn't meet your needs feel free to hack up Scape.pm to whatever you need.

Please look at the example.pl file above for inspiration

## Dependencies
* Perl (tested on 5.14)
* FindBin https://metacpan.org/pod/FindBin
* NetAddr::IP https://metacpan.org/pod/NetAddr::IP

## Output Format
```
{
  "model": "S4048-ON",
  "sitename": "us-east-1a",
  "devicerole": "adevicerole",
  "interfaces": {
    "TenGigabitEthernet 1/3": {
      "formfactor": "SFP+10GBASE-LR",
      "description": "test description",
      "ipaddress": [],
      "qualified": "Yes",
      "serial": "aserial1"
    },
    "fortyGigE 1/50": {
      "description": "another interface description",
      "formfactor": "QSFP40GBASE-SR4",
      "serial": "aserial2",
      "qualified": "Yes",
      "ipaddress": []
    },
    "Vlan 4007": {
      "description": "testdescription",
      "formfactor": "virtual",
      "vrf": "aVRF",
      "ipaddress": [
        {
          "bits": "28",
          "version": "4",
          "ip": "10.10.10.74",
          "type": "interface"
        },
        {
          "bits": "28",
          "version": "4",
          "ip": "10.10.10.73",
          "type": "vrrp"
        }
      ],
      "vlan": "4007"
    }
  },
  "serial": "devserial",
  "lags": [],
  "version": "9.14(0.0)",
  "mgmtip": "1.1.1.1",
  "hostname": "devhostname",
  "vendor": "force10"
}
```
