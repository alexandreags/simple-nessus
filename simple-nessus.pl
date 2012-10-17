#!/usr/bin/perl

# Simple Nessus - .nessus files simplified
#
# (c) 2012 Giovanni Cattani
# gcattani.github.com/simple-nessus
#
# Released under The MIT License

use strict;
use warnings;

use Getopt::Long;
use XML::Simple;

########## SIMPLE NESSUS

##### Defaults
# Must-have
my $sev_in = "L";
my $output = "O";
my $v1 = '';
my $v2 = '';

# Optional
my $show_ports = 0;


##### Options
my $nessusfile = $ARGV[0];

GetOptions (
			"severity=s" => \$sev_in,
			"output=s"   => \$output,
			"v1"         => \$v1,
			"v2"         => \$v2,
			"ports"		 =>	\$show_ports,
			help         => sub { helper(); }
) or die &helper();

# Checks for correct $output parameters
if ($output eq "T") {
	open TXT, ">>", "simple-output.txt";
	
} elsif ($output eq "M") {
	open MD, ">>", "simple-output.md";
	
} elsif ($output eq "C") {
	open CSV, ">>", "simple-output.csv";
	
	# Checks for $show_ports
	if ($show_ports){
		print CSV "host;vulnerability;port\n";
	} else {
		print CSV "host;vulnerability\n";
	}
	
} elsif (!($output eq "O")) {
	die &helper();
}

my $severity = &sev_calc($sev_in);

########### V1

if($v1){
##### Process the .nessus file
	my $nessus = XMLin($nessusfile,
		ForceArray 	=> [ "ReportHost", "ReportItem", "tag" ],
		KeyAttr 	=> { tag => "PluginName" },
		ContentKey 	=> "-content",
	);

##### Main Loop
	my $report_name = $nessus->{Report}{"ReportName"};
	&print_name($output, $report_name);

	my $report_host = $nessus->{Report}{ReportHost};
	
	foreach my $host ( @$report_host ) {
	
		&print_host($output, $host->{HostName});
		
		my $report_item = $host->{ReportItem};
	
		foreach my $item ( @$report_item ){
			if ( $item->{severity} >= $severity ) {
				&print_vuln($output, $host->{HostName}, $item->{pluginName}, $item->{port});
			}
		}
		
	} # End of Main Loop V1
}

########### End of V1


########### V2

if ($v2){
##### Process .nessus file
	my $nessus = XMLin($nessusfile,
		ForceArray 	=> [ "ReportHost", "tag" ],
		KeyAttr 	=> { tag => "name" },
		ContentKey 	=> "-content",
	);

##### Main Loop
	my $report_host = $nessus->{Report}{ReportHost};

	foreach my $host ( @$report_host ) {
	
    	my $properties = $host->{HostProperties}->{tag};

		&print_host($output, $properties->{"host-ip"});
	
		my $report_item = $host->{ReportItem};
	
		foreach my $item ( @$report_item ){
			if ( $item->{severity} >= $severity ) {
				&print_vuln($output, $properties->{"host-ip"}, $item->{pluginName}, $item->{port});
			}
		}
		
	} # End of Main Loop V2
}

########### End of V2





########## SUBROUTINES

##### Check for requested output and changes report name print style
# print_name(output, ReportName)
sub print_name(){
	my $print_check = $_[0]; # $output
	my $repo_name = $_[1];
	
	if ($print_check eq "O"){
		print "[#] ", $repo_name, "\n";
		
	} elsif ($print_check eq "T") {
		print TXT "[#] ", $repo_name, "\n";
		
	} elsif ($print_check eq "M") {
		print MD "# ", $repo_name, "\n";
		
	} elsif (!($print_check eq "C")) {
		die helper();	# This should never happen
	}
	# Not Affected: C
}

##### Checks for requested output and changes host name print style
# print_host(output, HostName);
sub print_host(){
	my $print_check = $_[0]; # $output
	my $host_name = $_[1];
	
	if ($print_check eq "O"){
		print "\n[*] ", $host_name, "\n";
		
	} elsif ($print_check eq "T") {
		print TXT "\n[*] ", $host_name, "\n";
		
	} elsif ($print_check eq "M") {
		print MD "\n### ", $host_name, "\n";
		
	} elsif (!($print_check eq "C")) {
		die helper();	# This should never happen
	}
	# Not Affected: C
}

##### Checks for requested output and changes vunerabilities print style
# print_vuln(output, host-ip, vulnerability, port);
sub print_vuln(){
	my $print_check = $_[0]; # $output
	my $host_ip = $_[1];
	my $host_vuln = $_[2];
	my $host_port = $_[3];
		
	if ($print_check eq "O") {
				
		if ($show_ports) {
			print "[",check_port($host_port),"]"," $host_vuln\n";
		} else {
			print "$host_vuln\n";
		}
		
	} elsif ($print_check eq "T") {
		
		if ($show_ports) {
			print TXT "[",check_port($host_port),"]"," $host_vuln\n";
		} else {
			print TXT "$host_vuln\n";
		}		
		
	} elsif ($print_check eq "M") {
		
		if ($show_ports) {
			print MD "* ", "$host_vuln\t[",check_port($host_port),"]\n";
		} else {
			print MD "* ", "$host_vuln  \n";
		}
		
	} elsif($print_check eq "C") {
		
		if ($show_ports) {
			print CSV "$host_ip;$host_vuln;",check_port($host_port),"\n";
		} else {
			print CSV "$host_ip;$host_vuln\n";
		}
		
	} else {
		die helper();	# This should never happen
	}

}

##### Converts severity in integers for easier usage
# sev_calc(severity)
sub sev_calc(){
	my $sev_str = $_[0];
		
	if ($sev_str eq "L") {
		return 1;
		
	} elsif ($sev_str eq "M") {
		return 2;
		
	} elsif ($sev_str eq "H") {
		return 3;
		
	} else {
		die helper();	# This should never happen
	}
}

##### Check ports syntax and converts them if needed
# check_port(port)
sub check_port(){
	my $in_port = $_[0];
	
	if ($v2) {
		return $in_port;
		
	} elsif ($v1) {
		# v1 -> www (80/tcp)
		$in_port =~ /www \((.+?)\/tcp\)/;
		
		return $1;
		
	} else {
		die helper();	# This should never happen
	}
	
}

##### Prints usage information
sub helper(){
	print "\nSimple Nessus 0.9\nUsage: ./simple-nessus.pl {DOT-NESSUS-FILE} {VERSION} [SEVERITY] [OUTPUT] [OPTIONAL]\n\nVERSION:\n  -v1  .nessus v1 file\n  -v2  .nessus v2 file\n\nSEVERITY:\n  -s L: Low, medium, high and critical\t(default)\n  -s M: Medium, high and critical\n  -s H: High and critical\n\nOUTPUT:\n  -o O: STDOUT\t(default)\n  -o T: .txt\n  -o C: .csv\t[host-ip,vulnerability]\n  -o M: .md\n\nOPTIONAL:\n  -ports: Show host port for each vulnerability\n\n";
	exit;
}