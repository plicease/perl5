

BEGIN {
    chdir 't' if -d 't';
    push @INC ,'../lib';
    require Config; import Config;
    unless ($Config{'useithreads'}) {
        print "1..0 # Skip: might still hang\n";
        exit 0;
    }
}


use threads;
use threads::queue;

$q = new threads::shared::queue;

print "1..26\n";

my $test : share = 1;

sub reader {
    my $tid = threads->self->tid;
    my $i = 0;
    while (1) {
	$i++;
#	print "reader (tid $tid): waiting for element $i...\n";
	my $el = $q->dequeue;
 	print "ok $test\n"; $test++;
#	print "reader (tid $tid): dequeued element $i: value $el\n";
	select(undef, undef, undef, rand(1));
	if ($el == -1) {
	    # end marker
#	    print "reader (tid $tid) returning\n";
	    return;
	}
    }
}

my $nthreads = 5;
my @threads;

for (my $i = 0; $i < $nthreads; $i++) {
    push @threads, threads->new(\&reader, $i);
}

for (my $i = 1; $i <= 20; $i++) {
    my $el = int(rand(100));
    select(undef, undef, undef, rand(1));
#    print "writer: enqueuing value $el\n";
    $q->enqueue($el);
}

$q->enqueue((-1) x $nthreads); # one end marker for each thread

for(@threads) {
#	print "waiting for join\n";
	$_->join();
}
print "ok $test\n";


