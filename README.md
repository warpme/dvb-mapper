dvb-mapper
==========

Small tool allowing to map DVB devs with known and persistent names + waiting till all tuners are avaliable.

It is possible that Your MythTV setup has many different DVB cards and some of them have multiple tuners.
If different DVB cards have the same A/V bridge/decoder (i.e. universal cx23885 or SAA716x A/V bridge) - relaying on PCI ID & udev 
might be tricky as system will see the same PCI Vendor/Device attributes for all cards with given bridge/decoder.
Realying on other udev attributes in udev might be tricky as sometimes Manufacturer attributes are not always set or reported correctly.

In such case only solution is to use PCI Subsystem_Vendor/Subsystem_ID attributes.
Solving this issue usually exposes another problem: udev reports exactly the same output for different tuners on the same
card so Your DVB adapters from many cards can be non-monotically named between cards.  

Proposed solution "Example for twin tuner cards with no difference in udevadm info output" on http://www.mythtv.org/wiki/Device_Filenames_and_udev
have issue with initialization races as each sub-device on DVB adapter (frontend, mux, dvr) are served by kernel in 
concurrent way (different device drivers) so it is possible to receive adapterX mux with frontend from adapterY.

dvb-mapper is small tool able to deal with all above cases. 
