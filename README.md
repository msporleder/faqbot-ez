= the very short irc bot for faq items or whatever

== INSTALL
* cat schema.txt | sqlite3 mydb.sqlite
* ./faqbot.pl "#channel" botname ./mydb.sqlite

== OPERATE
* !addfaq foo hi there!
* !faq foo
 > botname: hi there
* !delfaq foo
