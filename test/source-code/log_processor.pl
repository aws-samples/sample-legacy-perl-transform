#!/usr/bin/perl
#
# log_processor.pl - sample legacy Perl program for AWS Transform custom demo.
#
# Parses a structured access log, extracts fields with a regex, and reports
# a count of processed records (or dumps them in dry-run mode). Deliberately
# written in a legacy Perl 5 style (bareword filehandle, Getopt::Long,
# Data::Dumper) to exercise a realistic modernization.
#
# This file is original sample content authored for this AWS sample and is
# distributed under the MIT-0 license (see LICENSE).

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

my %CONFIG = (
    db_name  => 'enterprise_metrics',
    log_file => '/var/log/app_traffic.log',
    max_rows => 5000,
);

my ($input_file, $verbose, $dry_run);
GetOptions(
    'file=s'  => \$input_file,
    'verbose' => \$verbose,
    'dry-run' => \$dry_run,
) or die("Error in command line arguments\n");

$input_file ||= $CONFIG{log_file};

print "--- Initializing Log Processor ---\n" if $verbose;

my $processed_count = 0;
my @parsed_records;

open(LOGDATA, "<", $input_file) or die "Cannot open log file $input_file: $!";
while (my $line = <LOGDATA>) {
    chomp($line);

    # [2026-10-08 10:15:30] 192.168.1.45 GET /api/v1/users - 200
    if ($line =~ /^\[([\d\-\s\:]+)\]\s+([\d\.]+)\s+(\w+)\s+(\S+)\s+\-\s+(\d+)$/x) {
        my ($timestamp, $ip, $method, $endpoint, $status) = ($1, $2, $3, $4, $5);
        my $record = {
            ts     => $timestamp,
            ip     => $ip,
            action => $method,
            path   => $endpoint,
            code   => int($status)
        };
        push(@parsed_records, $record);
        $processed_count++;
        last if $processed_count >= $CONFIG{max_rows};
    }
}
close(LOGDATA);

if ($dry_run) {
    print "DRY RUN: Schema layout would match:\n";
    print Dumper(\@parsed_records);
} else {
    print "Successfully processed $processed_count records from $input_file.\n";
}

exit(0);
