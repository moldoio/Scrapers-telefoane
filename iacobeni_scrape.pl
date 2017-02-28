use strict;
use warnings;

use Data::Dumper;
use LWP::UserAgent;

use constant {
	#WEB_PAGE => 'http://www.abonati.me/SUCEAVA-j36/UDESTI-l3000',
	SLEEP => 1000
};

my $ua = LWP::UserAgent->new;
$ua->agent('Mozilla/5.0');
$ua->timeout(10);

my $page = shift;
my $today = $^T;
my $new_page = $page;
$new_page =~ s/[^a-z0-9]/_/ig;
open( OUT, '>', "result_page_${new_page}_$today.csv");
my @headers = ( 'Nume', 'Telefoane', 'WWW', 'Email', 'sat', 'localitate', 'judet', 'cod_postal' );
print OUT $_ . ';' foreach @headers;
print OUT "\n";
OUT->autoflush(1);

#my $content = &get_content($page);


my $errors = {};
my $names_got = 0;


    print "Getting page $page\n";
    my $content = get_content(  $page );
    
    $content =~ s/(<br>|<\/tr>)/$1\n/ig;
    
    my $names_links = aduna_linkuri($content);    
    
    get_details($names_links);
    
    $page++;


close OUT;

sub aduna_linkuri {
    my $content = shift;
    
    my @links = ( $content =~ m!<a href='(http://www.carte-telefoane.info[^']+)'.+?</a>!ig );

    #print Dumper(\@links);
    
    return \@links;
}

sub get_details {
    my $links = shift;

    foreach my $link ( @$links ) {
        my $content = '';
        eval { $content = get_content($link,1); };
        
        if ( $@ ) {
            print $link . " could not be parsed \n";
            $errors->{person_link_error}++;
            next;
        }
        
        unless ( $content ) {
            print $link . " has no content \n";
            $errors->{person_link_error}++;
            next;
        }
        
        my $result; 
	eval {
		$result = parse_person_page($content);
	};
	if ($@) {
		print "$link nu s-a putut parsa\n";
		$errors->{cannot_parse}++;
		exit if $errors->{cannot_parse} > 10;
		next;
	}        
	print "Got $result->{Nume} \n";
	$result->{WWW} = $link;
	$result->{Telefoane} = " " . $result->{Telefoane} . " ";
	$result->{sat} = cleanup_tags($result->{sat});
        print OUT ($result->{$_} || '') . ';' foreach @headers;
        print OUT "\n";
        $names_got++;
        print $names_got . " names extracted \n" if ($names_got % 100) == 0;
    };
}

sub get_content {
    my $url = shift;
    my $sleep_more = shift;
    
    my $tries = 0;
    
    while ( $tries < 3 ) {
        $tries++;
        sleep( int(rand(10)) + 5 );
	sleep ( int(rand(100)) + 10 ) if $sleep_more;
        
        my $response = $ua->get($url);
        my $content = '';
        
        if ( $response->is_success ) {
            return $response->decoded_content();
        } else {
            $tries++;
            print "WARNING: could not get a response, status line: $response->status_line \n";
        }
    }
    
    die "could not access page: $url  \n";
}

sub parse_person_page {
    my $content = shift;
    
    my $result = {};

    
    # Scrape the Nume
    my $nume = get_tag_containing('h2','Adres.\s',$content);
    $result->{Nume} = $nume;
    $result->{Nume} =~ s/^Adres.\s//i;
    
    # Scrape the location
    if ( $content =~ /\Q$nume\E<\/h2>(.+?)Cod po.tal:\s*(\d+)/ ) {
        $result->{cod_postal} = $2;
        my $adresa = $1;
        ( $result->{sat}, $result->{localitate}, $result->{judet} ) = ( $adresa =~ /^(.+?), Loc\.\s*<a.+?>(.+?)<\/a>,\s+Jud\.\s+<a.+?>(.+?)<\/a>/ );
    }
    my $tel_tbl = get_tag_containing('table','<tr>\s*<th>Telefoane', $content);
    
#     $tel_tbl =~ s/^<table.+?>/\[/ig;
#     $tel_tbl =~ s/<\?table>$/\]/ig;
    
    $tel_tbl =~ s/<tr>/\[/ig;
    $tel_tbl =~ s/<\/tr>/\],/ig;
    
    $tel_tbl =~ s/<t[hd]>/'/ig;
    $tel_tbl =~ s/<\/t[hd]>/',/ig;
    
    $tel_tbl =~ s/<br>//ig;
    $tel_tbl =~ s/&nbsp;//ig;

    eval " \$tel_tbl = [ $tel_tbl ] ";

    for ( my $i = 0; $i < scalar(@{$tel_tbl->[0]}); $i++ ) {
        $result->{$tel_tbl->[0]->[$i]} = $tel_tbl->[1]->[$i];
    }

    return $result;
}

sub get_tag_containing {
    my ( $tag, $contains, $content ) = @_;
    
    if ( $content =~ /<$tag.*?>([^($tag)]*?$contains.*?)<\/$tag>/is ) {
        return $1;
    }
    
    return '';
}

sub cleanup_tags {
  my $text = shift;
  
    $text =~ s/<[^>]+>//g;
    return $text;
}







