#!/usr/pkg/bin/perl
use AnyEvent;
use AnyEvent::IRC::Client;
use AnyEvent::IRC::Util qw/parse_irc_msg/;

use Data::Dumper;
use DBI;
use DBIx::Connector;

my $chan = $ARGV[0];
my $username = $ARGV[1];
my $dbfile = $ARGV[2];

my $dbh = DBIx::Connector->connect("dbi:SQLite:dbname=$dbfile","","");
my $cnd = AnyEvent->condvar;
my $con = AnyEvent::IRC::Client->new;
my $timer;

connect_to();

$con->reg_cb (
	publicmsg => sub {
		my ($msg, $channel) = @_;
		#print Dumper \$msg->{'__oe_cbs'}[1][0]; #channel
		#print Dumper \$msg->{'__oe_cbs'}[1][1]{'params'}[-1]; #msg
		my $short_m = substr($msg->{'__oe_cbs'}[1][1]{'params'}[-1], 0, 500);
		print "short_m: $short_m\n";

		my $getpat = "^\!faq";
		my $addpat = "^\!addfaq";
		my $delpat = "^\!delfaq";
		#look for stuff
		if ( $short_m =~ /$getpat/ ) {
			my ($faq) = $short_m =~ m#$getpat (.+)#;
			if ($faq =~ m#^[a-zA-Z0-9_]+#) {
				print "looking up $faq\n";
				my $reply = doc_lookup($faq);
				$reply ? $con->send_srv ( PRIVMSG => $chan, $reply ) : 1;
			}
		}
		if ( $short_m =~ /$addpat/ ) {
			my ($faq, $txt) = $short_m =~ m#$addpat (.+?)\s+(.+)#;
			if ($faq =~ m#^[a-zA-Z0-9_]+#) {
				print "adding $faq, $txt\n";
				$dbh->do('INSERT INTO "docs" VALUES (?, ?)', undef, ($faq, $txt)) or print $dbh->errstr;
			}
		}
		if ( $short_m =~ /$delpat/ ) {
			my ($faq) = $short_m =~ m#$delpat (.+)#;
			if ($faq =~ m#^[a-zA-Z0-9_]+#) {
				print "deleting $faq\n";
				$dbh->do('DELETE FROM "docs" WHERE item=?', undef, ($faq)) or print $dbh->errstr;
			}
		}
	}
);

$con->reg_cb ( privatemsg => sub {
		my ($msg, $channel) = @_;
		#print Dumper \$msg;
		#print Dumper \$channel;
	}
);

$con->reg_cb (
	disconnect => sub {
		connect_to();
	}
);

$cnd->wait;

$con->disconnect;


sub doc_lookup {
	my $docs_term = shift;
	my ($reply) = $dbh->selectrow_array("SELECT reply FROM docs WHERE item=\"$docs_term\"");
	return $reply;
}

sub connect_to {
	$con->connect("irc.freenode.net", 6667, { nick => "$username", user => "${username}+faqbot-ez", real => "github.com/msporleder/faqbot-ez" } );
	$con->send_srv (PRIVMSG => 'mspo', "Hi there!, I am $username, a faqbot-ez");
	$con->send_srv (JOIN => $chan);
}
