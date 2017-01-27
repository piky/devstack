# draas-keystone-dns
Description of DNS Failover Integration
Prerequisites:
•	At least two nodes with Openstack deployed on each
•	Account of NO-IP with at least one hostname provided by this (NO-IP  is an open source DNS service providers, 
                                                                for more info visit http://www.noip.com/)

Installation:
Fork this project, place the primary-draas folder into primary node’s drive and secondary-draas folder into secondary node’s drive. 
Open the primary-draas and then open failover.conf file. Now enable the DNS-based service (which is already enabled by default) and 
the rest services are disabled by default. After this, put all the other things accordingly. Finally just run the Draas.py file by 
typing ‘python Draas.py’. Same process would be applied on the secondary node. Note: first you need to run Draas.py on secondary 
site and then on primary site.
