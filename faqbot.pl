#!/usr/bin/env perl
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
		handle_msg(@_);
	}
);

$con->reg_cb (
	privatemsg => sub {
		my $msg = shift;
		my ($user) = $msg->{'__oe_cbs'}[1][1]{'prefix'} =~ m#(^.+)\!#;
		handle_msg($msg, $user);
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

sub doc_ls {
	my $reply = $dbh->selectall_arrayref("SELECT item FROM docs");
	return $reply;
}

sub connect_to {
	$con->connect("irc.freenode.net", 6667, { nick => "$username", user => "${username}+faqbot-ez", real => "github.com/msporleder/faqbot-ez" } );
	$con->send_srv (PRIVMSG => 'mspo', "Hi there!, I am $username, a faqbot-ez");
	$con->send_srv (JOIN => $chan);
}

sub handle_msg {
	#print Dumper \$msg->{'__oe_cbs'}[1][0]; #channel
	#print Dumper \$msg->{'__oe_cbs'}[1][1]{'params'}[-1]; #msg
	my $msg = shift;
	my $channel = shift;
	my $short_m = substr($msg->{'__oe_cbs'}[1][1]{'params'}[-1], 0, 500);
	my $getpat = "^\!faq";
	my $addpat = "^\!addfaq";
	my $delpat = "^\!delfaq";
	my $lspat = "^\!lsfaq";
	#look for stuff
	if ( $short_m =~ /$getpat/ ) {
		my ($faq) = $short_m =~ m#$getpat (.+)#;
		if ($faq =~ m#^[a-zA-Z0-9_]+#) {
			print "looking up $faq for $channel\n";
			my $reply = doc_lookup($faq);
			$reply ? $con->send_srv ( PRIVMSG => "$channel", $reply ) : 1;
		}
		return;
	}
	if ( $short_m =~ /$addpat/ ) {
		my ($faq, $txt) = $short_m =~ m#$addpat (.+?)\s+(.+)#;
		if ($faq =~ m#^[a-zA-Z0-9_]+#) {
			print "adding $faq, $txt\n";
			my $numr = $dbh->do('INSERT INTO "docs" VALUES (?, ?)', undef, ($faq, $txt));
			if ($numr > 0) {
				$con->send_srv ( PRIVMSG => "$channel", "added $faq" );
			} else {
				$con->send_src ( PRIVMSG => "$channel", "err: $dbh->errstr" );
			}
		}
		return;
	}
	if ( $short_m =~ /$delpat/ ) {
		my ($faq) = $short_m =~ m#$delpat (.+)#;
		if ($faq =~ m#^[a-zA-Z0-9_]+#) {
			print "deleting $faq\n";
			my $numr = $dbh->do('DELETE FROM "docs" WHERE item=?', undef, ($faq)) or print $dbh->errstr;
			if ($numr > 0) {
				$con->send_srv ( PRIVMSG => "$channel", "deleted $faq" );
			} else {
				$con->send_src ( PRIVMSG => "$channel", "err: $dbh->errstr" );
			}
		}
		return;
	}
	if ( $short_m =~ /$lspat/ ) {
		my $faqs = doc_ls();
		my @f;
		foreach my $x (@{$faqs}) {
			push(@f, $x->[0]);
		}
		my $list = join(",", @f);
		if ($faqs) {
			$con->send_srv ( PRIVMSG => "$channel", $list );
		}
		return;
	}
}
