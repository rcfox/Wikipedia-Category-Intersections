#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use HTML::Parser;
use LWP::UserAgent;
use CGI;

my $state = 0;
my $last_url = '';
my @parse;
my %items;
my $current_category;
my $ua = new LWP::UserAgent;

my $cgi = new CGI;
print $cgi->header;

for($cgi->param)
{
	$current_category = $_;
	@parse = ();
	push @parse, $ua->get("http://en.wikipedia.org/wiki/Category:$current_category")->content;
	my $p = HTML::Parser->new( api_version => 3,
	                           start_h => [\&start, "tagname, attr"],
	                           end_h => [\&end, "tagname, attr, skipped_text"],
	                           marked_sections => 1,
	                         );
	for(@parse)
	{
		$state = 0;
		$p->parse($_);
	}
	$p->eof;

	#print Dumper($items{$current_category});
}

print<<HEADER;
<html>
<head></head>
<body>
HEADER

my @keys = keys %items;
for(my $i = 0; $i < @keys; ++$i)
{
	my $a = $keys[$i];
	for(my $j = $i+1; $j < @keys; ++$j)
	{
		my $b = $keys[$j];
		if ($a ne $b)
		{
			print "<h1>$a -- $b</h1>\n";
			my @intersect = grep { $items{$b}{$_} } keys %{$items{$a}};
			print "<ul>\n";
			for(@intersect)
			{
				print "<li><a href=\"".$items{$b}{$_}."\">$_</a></li>\n";
			}
			print "</ul>\n";
		}
	}
}
print<<FOOTER;
</body>
</html>
FOOTER

sub start
{
	my ($tag, $attr) = @_;
	++$state if($state == 0 && $tag eq 'a' && $attr->{id} && $attr->{id} eq 'Pages_in_category');
	++$state if($state == 1 && $tag eq 'ul');
	$state = 0 if($attr->{class} && $attr->{class} eq 'printfooter');
	if($state == 0 && $tag eq 'a')
	{
		$last_url = $attr->{href};
		$state = 40;
	}
	if($state == 2 && $tag eq 'a')
	{
		my $item = $attr->{title};
		my $url = $attr->{href};
		$items{$current_category}{$item} = "http://en.wikipedia.org$url";
	}
}

sub end
{
	my ($tag, $attr, $skipped_text) = @_;
	if($state == 40)
	{
		if($skipped_text =~ /next \d+/)
		{
			push @parse, $ua->get("http://en.wikipedia.org$last_url")->content;
		}
		$state = 0;
	}
}
