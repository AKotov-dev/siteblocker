**SiteBlocker** - маленький блокировщик сайтов и другого контента по времени

Dependencies: iptables ipset bind-utils (host)

SiteBlocker is a GUI for automatically building the rules of the iptables packet filter, which will turn an old computer with two network cards into a router. It can block sites from the blacklist, VPN, Torrent, messengers, etc. (The mode is "Web - surfing only"). Additionally, there is a dictionary filtering method.

It can be useful for parents to protect their children from unwanted content. Works on a schedule.

Available in *.tar.gz (source+bin on Lazarus, requires iptables, ipset, bind-utils packages), RPM (MgaRemix/Mageia-7/8), and DEB (Linux Mint-19.3). The SiteBlocker interface is intuitive and doesn't need any additional comments (see the screenshot).

Important: Since v1.7, the code has also been optimized for Debian. Testing was performed on Mageia Linux-7/8 and Linux Mint-19.3

Note: In Mageia Linux, it is advisable to remove the msec and shorewall-core packages. You do not need to force the system to change the security settings. In Linux Mint (Debian), it is advisable to remove the ufw (Uncomplicated Firewall) package.

Made and tested in Mageia Linux-8.
